// Shared prelude: viz_common.glsl. HTML drawWave styles 11 and 13.

vec4 radialBurst(vec2 p, float W, float H, int n)
{
    float c = H * 0.5;
    vec2 centre = vec2(W * 0.5, c);
    vec2 q = p - centre;
    float r0 = c * 0.42;
    float rotation = reducedMotion > 0.5 ? 0.0 : timeSeconds * 0.25;
    float angle = atan(q.y, q.x) + rotation;
    float turn = 6.28318530718;
    int j = int(floor(mod(angle, turn) / turn * float(n) + 0.5));
    float d = 1e5;
    // Only neighbouring angular bins can touch this pixel. This stays bounded
    // as the bar count grows, unlike a loop over the complete radial spectrum.
    for (int k = -3; k <= 3; k++) {
        int i = (j + k + n) % n;
        float a = float(i) / float(n) * turn - rotation;
        vec2 axis = vec2(cos(a), sin(a));
        float len = level(i) * c * 0.56 + 1.0;
        d = min(d, sdSegment(q, axis * r0, axis * (r0 + len)));
    }
    float hw = max(1.0, lineWidth * 0.8) * 0.5;
    vec4 color = over(paint(1.0, cover(d - hw)), htmlShadow(htmlLineGlow(d, hw)));
    float ring = abs(length(q) - r0 * (0.9 + 0.15 * bass * energy));
    vec4 inner = over(paint(0.35, cover(ring - hw)), htmlShadow(0.35 * htmlLineGlow(ring, hw)));
    return over(inner, color);
}

vec4 pulseOrb(vec2 p, float W, float H, int n)
{
    float c = H * 0.5;
    float cx = W * 0.5;
    float radius = c * (0.3 + 0.55 * bass * energy) + 2.0;
    float distance = length(p - vec2(cx, c));
    float f = distance / (radius * 1.6);
    float coreAlpha = opaqueOrb > 0.5 ? 1.0 : 0.95;
    float edgeAlpha = opaqueOrb > 0.5 ? 1.0 : 0.35;
    float alpha = f < 0.55 ? mix(coreAlpha, edgeAlpha, f / 0.55) : mix(edgeAlpha, 0.0, (f - 0.55) / 0.45);
    vec4 color = tint(unpremultiply(color0), clamp(alpha, 0.0, 1.0));
    for (int k = 0; k < 3; k++) {
        float phase = fract(timeSeconds * 0.6 + float(k) / 3.0);
        float ring = radius + phase * c * 1.4;
        color = over(paint((1.0 - phase) * 0.5 * energy, cover(abs(distance - ring) - 0.5)), color);
    }
    float slot = W / float(n);
    int j = int(floor(p.x / slot));
    float dots = 1e5;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n) continue;
        float x = (float(i) + 0.5) * slot;
        if (abs(x - cx) < radius * 1.8) continue;
        float a = level(i) * c * 0.8;
        dots = min(dots, min(length(p - vec2(x, c - a)), length(p - vec2(x, c + a))));
    }
    return over(paint(0.55, cover(dots - 1.0)), color);
}

void main()
{
    vec2 p = qt_TexCoord0 * canvasSize;
    int n = int(barCount + 0.5);
    vec4 color = vec4(0.0);
    if (n >= 1) {
        if (style < 12.0) color = radialBurst(p, canvasSize.x, canvasSize.y, n);
        else color = pulseOrb(p, canvasSize.x, canvasSize.y, n);
    }
    fragColor = color * (qt_Opacity * edgeMask());
}
