#include <metal_stdlib>
using namespace metal;

// Grain is stationary: it gives the flat drawings a printed-ink texture without flicker.
[[ stitchable ]] half4 sketchPaper(float2 position, half4 color) {
    float grain = fract(sin(dot(floor(position * 1.8), float2(12.9898, 78.233))) * 43758.5453);
    float ink = 1.0 - smoothstep(0.90, 1.0, float(max(color.r, max(color.g, color.b))));
    color.rgb *= half(1.0 - grain * 0.045 * ink);
    return color;
}

// A brush follows the same diagonal as the illustrations. The endpoint is fully visible.
[[ stitchable ]] half4 brushReveal(float2 position, half4 color, float2 size, float progress) {
    if (progress >= 0.999) return color;
    float2 uv = position / max(size, float2(1.0));
    float edge = (uv.x + uv.y * 0.55) / 1.55;
    edge += sin(uv.y * 175.0) * 0.008 + sin(uv.y * 439.0) * 0.004;
    float coverage = 1.0 - smoothstep(progress * 1.12 - 0.05, progress * 1.12 + 0.015, edge);
    return color * half(coverage);
}

// Limited to rising air, never to text or controls. Maximum displacement is < 1 point.
[[ stitchable ]] float2 kitchenHeat(float2 position, float2 size, float time, float strength) {
    float2 uv = position / max(size, float2(1.0));
    float region = smoothstep(0.12, 0.35, uv.x) * (1.0 - smoothstep(0.65, 0.88, uv.x));
    region *= smoothstep(0.05, 0.24, uv.y) * (1.0 - smoothstep(0.38, 0.62, uv.y));
    return position + float2(sin(uv.y * 43.0 - time * 2.5) * region * strength * 0.7, 0.0);
}
