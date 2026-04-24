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

    float lum = dot(col, vec3(0.299, 0.587, 0.114));

    // =========================
    // COLOR GRADING
    // =========================
    vec3 shadows = vec3(0.0, 0.25, 0.35);
    vec3 highlights = vec3(0.8, 0.6, 0.4);

    vec3 graded = mix(shadows, highlights, lum);
    col = mix(col, graded, 0.5);

    float gray = dot(col, vec3(0.299, 0.587, 0.114));
    col = mix(col, vec3(gray), 0.35);

    col = (col - 0.5) * 1.35 + 0.5;

    // =========================
    // DEPTH
    // =========================
    float depth = texture(depthtex0, uv).r;

    float near = 0.1;
    float far = 100.0;

    float linearDepth = (2.0 * near) / (far + near - depth * (far - near));

    // =========================
    // FLASHLIGHT
    // =========================
    vec2 center = vec2(0.5, 0.5);
    float distFromCenter = length(uv - center);

    // tighter, more focused beam
    float cone = smoothstep(0.25, 0.0, distFromCenter);

    float depthFade = clamp(1.0 - linearDepth * 1.4, 0.0, 1.0);
    float groundBoost = smoothstep(0.25, 1.0, uv.y);

    float flicker = 0.96 + 0.04 * sin(frameTimeCounter * 10.0);

    float flashlight = cone * depthFade * groundBoost * flicker;

    vec3 flashlightColor = vec3(1.0, 0.95, 0.85);

    // strong darkness outside beam (core horror effect)
    float darknessMask = 1.0 - cone;
    col *= mix(1.0, 0.35, darknessMask);

    // apply flashlight (stronger)
    col += flashlight * flashlightColor * 1.8;

    // =========================
    // FOG
    // =========================
    float fog = smoothstep(0.1, 0.65, linearDepth);

    vec3 fogColor = vec3(0.0, 0.22, 0.18);

    // volumetric light (controlled, not overblown)
    float volumetric = cone * fog * depthFade;
    vec3 fogLit = fogColor + flashlightColor * volumetric * 0.4;

    col = mix(col, fogLit, fog);

    // height fog
    float heightFog = smoothstep(0.85, 0.2, uv.y);
    float finalFog = clamp(fog * 0.7 + heightFog * 0.4, 0.0, 1.0);

    col = mix(col, fogLit, finalFog);

    // =========================
    // GLOBAL DARKNESS
    // =========================
    col *= 0.85;

    float sky = step(0.999, depth);
    float sun = smoothstep(0.85, 1.0, lum);
    col += vec3(0.8, 0.7, 0.5) * sun * sky * 0.06;

    // =========================
    // WET SURFACES
    // =========================
    float ground = smoothstep(0.5, 1.0, depth);
    float brightness = dot(col, vec3(0.299, 0.587, 0.114));

    float wet = ground * (1.0 - brightness);

    col *= mix(1.0, 0.7, wet);

    vec3 dampTint = vec3(0.0, 0.06, 0.1);
    col += dampTint * wet * 0.4;

    // =========================
    // VIGNETTE
    // =========================
    float dist = distance(uv, vec2(0.5));
    float vignette = smoothstep(0.95, 0.3, dist);
    col *= vignette;

    // =========================
    // SPORES (IMPROVED VISIBILITY)
    // =========================
    vec3 spores = vec3(0.0);

    float density = 100.0;
    float speed = 0.01;

    for (int i = 0; i < 16; i++) {
        float fi = float(i);

        float localSpeed = speed * (0.5 + fract(fi * 0.37));

        vec2 pos = fract(vec2(
            sin(fi * 12.989 + frameTimeCounter * localSpeed),
            cos(fi * 78.233 + frameTimeCounter * localSpeed * 0.8)
        ));

        pos = fract(pos * density);

        float d = distance(uv, pos);

        float particle = smoothstep(0.012, 0.0, d);

        float visibility = smoothstep(0.65, 0.2, lum);

        spores += particle * visibility;
    }

    vec3 sporeColor = vec3(0.9, 0.85, 0.7);

    // stronger in flashlight beam
    col += spores * sporeColor * (0.05 + flashlight * 0.6);

    // =========================
    // FILM GRAIN
    // =========================
    float noise = rand(uv + frameTimeCounter) * 0.025;
    col += noise;

    color = vec4(col, 1.0);
}