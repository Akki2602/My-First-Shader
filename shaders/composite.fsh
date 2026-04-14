#version 330 compatibility

uniform sampler2D colortex0;
uniform sampler2D depthtex0;
uniform float frameTimeCounter;

in vec2 texcoord;

/* RENDERTARGETS: 0 */
layout(location = 0) out vec4 color;

// Film grain
float rand(vec2 co){
    return fract(sin(dot(co, vec2(12.9898,78.233))) * 43758.5453);
}

void main() {
    vec2 uv = texcoord;

    // =========================
    // BASE COLOR
    // =========================
    vec3 col = texture(colortex0, uv).rgb;

    // =========================
    // RE2 COLOR GRADING
    // =========================
    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    vec3 shadows = vec3(0.0, 0.25, 0.35);
    vec3 highlights = vec3(0.8, 0.6, 0.4);

    vec3 graded = mix(shadows, highlights, lum);
    col = mix(col, graded, 0.5);

    float gray = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(gray), 0.35);

    col = (col - 0.5) * 1.35 + 0.5;

    // =========================
    // DEPTH-BASED FOG (FIXED)
    // =========================
    float depth = texture(depthtex0, uv).r;

    float near = 0.1;
    float far = 100.0;

    float linearDepth = (2.0 * near) / (far + near - depth * (far - near));

    float fog = smoothstep(0.15, 1., linearDepth);

    vec3 fogColor = vec3(0.0, 0.18, 0.22);

    col = mix(col, fogColor, fog);

    // =========================
    // HEIGHT-BASED FOG
    // =========================

    // Height factor (bottom = more fog)
    float heightFog = smoothstep(0.8, 0.2, uv.y);

    // Combine with depth fog
    float finalFog = fog * 0.7 + heightFog * 0.5;

    // Clamp
    finalFog = clamp(finalFog, 0.0, 1.0);

    // Apply
    col = mix(col, fogColor, finalFog);

    // =========================
    // GLOBAL DARKNESS
    // =========================
    col *= 0.7;

    // Detect sky
float sky = step(0.999, depth);


// Very faint sun visibility
float sun = smoothstep(0.85, 1.0, lum);
col += vec3(0.8, 0.7, 0.5) * sun * sky * 0.08;

    // =========================
    // WET & DAMP SURFACES (IMPROVED)
    // =========================

    // Ground approximation
    float ground = smoothstep(0.5, 1.0, depth);

    float brightness = dot(col, vec3(0.299, 0.587, 0.114));

    // Wetness mask
    float wet = ground * (1.0 - brightness);

    // --- Darkening (absorption) ---
    col *= mix(1.0, 0.68, wet);

    // --- Cooler damp tint ---
    vec3 dampTint = vec3(0.0, 0.06, 0.1);
    col += dampTint * wet * 0.5;

    // --- Soft specular highlight ---
    float spec = pow(max(0.0, 1.0 - brightness), 2.5);
    spec *= wet;


    // =========================
    // VIGNETTE
    // =========================
    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.95, 0.3, dist);
    col *= vignette;

    // =========================
    // FILM GRAIN
    // =========================
    float noise = rand(uv + frameTimeCounter) * 0.03;
    col += noise;

    color = vec4(col, 1.0);
}