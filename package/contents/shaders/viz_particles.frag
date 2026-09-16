// Shared prelude: viz_common.glsl. HTML drawWave style 14.
// The audio clock owns particle simulation; both renderers consume that state.
void main()
{
    float W = canvasSize.x;
    float H = canvasSize.y;
    vec2 p = qt_TexCoord0 * canvasSize;
    int n = int(barCount + 0.5);
    vec4 color = vec4(0.0);
    if (n >= 2) {
        float slot = W / float(n);
        int j = int(floor(p.x / slot - 0.5));
        float line = 1e5;
        for (int k = -3; k <= 3; k++) {
            int i = j + k;
            if (i < 0 || i >= n - 1) continue;
            float y0 = i == 0 ? H * 0.5 : H * 0.5 - level(i) * (H * 0.5 - lineWidth) * 0.25;
            float y1 = H * 0.5 - level(i + 1) * (H * 0.5 - lineWidth) * 0.25;
            vec2 a = vec2((float(i) + 0.5) * slot, y0);
            vec2 b = vec2((float(i) + 1.5) * slot, y1);
            line = min(line, sdSegment(p, a, b));
        }
        color = over(paint(0.35, cover(line - 0.5)), htmlShadow(0.35 * htmlLineGlow(line, 0.5)));
    }
    for (int i = 0; i < 32; i++) {
        if (float(i) >= particleCount) break;
        vec4 particle = particleAt(i); // x, y, radius, remaining life
        float d = length(p - particle.xy);
        vec4 dot = over(paint(particle.w, cover(d - particle.z)), htmlShadow(particle.w * htmlDiscGlow(d, particle.z)));
        color = over(dot, color);
    }
    fragColor = color * (qt_Opacity * edgeMask());
}
