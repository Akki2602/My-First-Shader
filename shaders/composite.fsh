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
    // DEPTH-BASED FOG
    // =========================
    float depth = texture(depthtex0, uv).r;

    float near = 0.1;
    float far = 100.0;

    float linearDepth = (2.0 * near) / (far + near - depth * (far - near));

    float fog = smoothstep(0.1, 0.6, linearDepth);

    vec3 fogColor = vec3(0.0, 0.2, 0.25);

    col = mix(col, fogColor, fog);

    // =========================
    // GLOBAL DARKNESS
    // =========================
    col *= 0.7;

// =========================
// WET SURFACE (PROPER APPROACH)
// =========================



// Treat farther pixels as ground-like
float ground = smoothstep(0.5, 1.0, depth);

// Brightness of surface
float brightness = dot(col, vec3(0.299, 0.587, 0.114));

// Wet surfaces are darker and less reflective in bright areas
float wetMask = ground * (1.0 - brightness);

// --- 1. Darken (damp absorption) ---
col *= mix(1.0, 0.65, wetMask);

// --- 2. Slight cold tint (wet look) ---
vec3 wetTint = vec3(0.0, 0.08, 0.12);
col += wetTint * wetMask * 0.4;

// --- 3. Soft specular (no screen-center bias) ---
// Use brightness contrast instead of position
float spec = pow(max(0.0, 1.0 - brightness), 3.0);

// Only in wet areas
spec *= wetMask;

// Subtle highlight color
vec3 specColor = vec3(0.6, 0.7, 0.8);

// Apply gently
col += specColor * spec * 0.1;



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