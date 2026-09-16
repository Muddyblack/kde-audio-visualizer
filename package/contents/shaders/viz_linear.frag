// Shared prelude: viz_common.glsl. HTML drawWave styles 6–10 and 12.

vec4 peakBars(vec2 p, float W, float H, int n, out float glow)
{
    float slot = W / float(n);
    float bw = max(1.5, slot * 0.58);
    int j = int(floor(p.x / slot));
    float body = 1e5;
    float cap = 1e5;
    float alpha = fillAmount > 0.5 ? 0.75 : 1.0;
    glow = 0.0;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n) continue;
        float bh = max(min(lineWidth, 2.0), level(i) * H * 0.86);
        float x = float(i) * slot + (slot - bw) * 0.5;
        vec2 lo = vec2(x, H - bh);
        vec2 hi = vec2(x + bw, H);
        body = min(body, sdRoundBox(p, lo, hi, bw * 0.5));
        glow += htmlBoxGlow(p, lo, hi) * alpha;
        float y = H - peak(i) * H * 0.86 - 4.0;
        cap = min(cap, sdRoundBox(p, vec2(x, y), vec2(x + bw, y + 2.0), 1.0));
    }
    return over(paint(0.9, cover(cap)), paint(alpha, cover(body)));
}

vec4 ledMeter(vec2 p, float W, float H, int n)
{
    float slot = W / float(n);
    float bw = max(2.0, slot * 0.7);
    int rows = int(floor(H / 4.0));
    int row = int(floor((H - p.y) / 4.0));
    if (row < 0 || row >= rows) return vec4(0.0);
    int j = int(floor(p.x / slot));
    vec4 color = vec4(0.0);
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n) continue;
        float x = float(i) * slot + (slot - bw) * 0.5;
        float y = H - float(row + 1) * 4.0 + 1.0;
        float coverage = cover(sdBox(p, vec2(x, y), vec2(x + bw, y + 2.7)));
        bool on = row < int(floor(level(i) * float(rows) + 0.5));
        vec3 rgb = baseRgb();
        if (!on) rgb = vec3(1.0);
        else if (solidMode > 0.5 && float(row) > float(rows) * 0.78) rgb = vec3(1.0, 107.0 / 255.0, 107.0 / 255.0);
        else if (solidMode > 0.5 && float(row) > float(rows) * 0.55) rgb = vec3(1.0, 209.0 / 255.0, 102.0 / 255.0);
        color = over(tint(rgb, coverage * (on ? 1.0 : 0.06)), color);
    }
    return color;
}

// HTML smoothTrace joins midpoint endpoints with quadratic Beziers. The first
// curve starts at sample zero and the last half-segment is a straight line.
vec2 tracePoint(int i, float W, float H, int n, bool mountain, float phase, float scaleA, float side)
{
    float inset = mountain ? 0.0 : lineWidth;
    float x = inset + float(i) / float(n - 1) * (W - 2.0 * inset);
    float a = level(i);
    float y = mountain ? H - lineWidth - a * (H - 2.0 * lineWidth) * 0.95
        : H * 0.5 + side * a * (H * 0.5 - lineWidth) * scaleA
          * (0.75 + 0.25 * sin(timeSeconds * 2.0 + float(i) * 0.3 + phase));
    return vec2(x, y);
}

void traceControls(int i, float W, float H, int n, bool mountain, float phase, float scaleA, float side,
                   out vec2 a, out vec2 b, out vec2 c)
{
    b = tracePoint(i, W, H, n, mountain, phase, scaleA, side);
    a = i == 1 ? tracePoint(0, W, H, n, mountain, phase, scaleA, side)
        : (tracePoint(i - 1, W, H, n, mountain, phase, scaleA, side) + b) * 0.5;
    c = (b + tracePoint(i + 1, W, H, n, mountain, phase, scaleA, side)) * 0.5;
}

float traceY(float x, float W, float H, int n, bool mountain, float phase, float scaleA, float side)
{
    float inset = mountain ? 0.0 : lineWidth;
    float step = max(0.001, (W - 2.0 * inset) / float(n - 1));
    float f = clamp((x - inset) / step, 0.0, float(n - 1));
    if (f >= float(n) - 1.5) {
        vec2 b = tracePoint(n - 1, W, H, n, mountain, phase, scaleA, side);
        vec2 a = (tracePoint(n - 2, W, H, n, mountain, phase, scaleA, side) + b) * 0.5;
        return mix(a.y, b.y, clamp((f - float(n) + 1.5) * 2.0, 0.0, 1.0));
    }
    int i = clamp(int(floor(f + 0.5)), 1, n - 2);
    float t = i == 1 ? 2.0 - sqrt(max(0.0, 4.0 - 2.0 * f)) : f - float(i) + 0.5;
    vec2 a, b, c;
    traceControls(i, W, H, n, mountain, phase, scaleA, side, a, b, c);
    return mix(mix(a.y, b.y, t), mix(b.y, c.y, t), t);
}

float traceDistance(vec2 p, float W, float H, int n, bool mountain, float phase, float scaleA, float side)
{
    float inset = mountain ? 0.0 : lineWidth;
    float step = max(0.001, (W - 2.0 * inset) / float(n - 1));
    int j = int(floor((p.x - inset) / step + 0.5));
    float d = 1e5;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 1 || i >= n) continue;
        if (i == n - 1) {
            vec2 b = tracePoint(i, W, H, n, mountain, phase, scaleA, side);
            vec2 a = (tracePoint(i - 1, W, H, n, mountain, phase, scaleA, side) + b) * 0.5;
            d = min(d, sdSegment(p, a, b));
        } else {
            vec2 a, b, c;
            traceControls(i, W, H, n, mountain, phase, scaleA, side, a, b, c);
            vec2 prev = a;
            for (int s = 1; s <= 8; s++) {
                float t = float(s) / 8.0;
                vec2 cur = mix(mix(a, b, t), mix(b, c, t), t);
                d = min(d, sdSegment(p, prev, cur));
                prev = cur;
            }
        }
    }
    return d;
}

vec4 mountain(vec2 p, float W, float H, int n, out float glow)
{
    float d = traceDistance(p, W, H, n, true, 0.0, 1.0, -1.0);
    float y = traceY(p.x, W, H, n, true, 0.0, 1.0, -1.0);
    float alpha = mix(0.55, 0.02, clamp(p.y / H, 0.0, 1.0));
    vec3 fillRgb = unpremultiply(colorCount > 1.5 ? color1 : color0);
    vec4 fill = tint(fillRgb, alpha * cover(p.y < y ? d : -d));
    float hw = lineWidth * 0.5;
    glow = htmlLineGlow(d, hw);
    return over(paint(1.0, cover(d - hw)), fill);
}

float scopeY(float x, float W, float H, int n)
{
    float a = interpolatedLevel(x, W, n);
    return H * 0.5 + sin(x * 0.11 + timeSeconds * 9.0) * a * (H * 0.5 - lineWidth)
        * (0.65 + 0.35 * sin(x * 0.025 - timeSeconds * 3.0));
}

vec4 oscilloscope(vec2 p, float W, float H, int n, out float glow)
{
    float d = 1e5;
    int j = int(floor(p.x / 1.5));
    int last = int(floor(W / 1.5));
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= last) continue;
        float x = float(i) * 1.5;
        d = min(d, sdSegment(p, vec2(x, scopeY(x, W, H, n)), vec2(x + 1.5, scopeY(x + 1.5, W, H, n))));
    }
    float hw = lineWidth * 0.5;
    glow = htmlLineGlow(d, hw);
    return paint(1.0, cover(d - hw));
}

vec4 ribbonLayers(vec2 p, float W, float H, int n)
{
    vec4 color = vec4(0.0);
    if (fillAmount > 0.5) {
        float top = traceY(p.x, W, H, n, false, 0.0, 1.0, -1.0);
        // The fill traverses the lower point list in reverse; its special
        // endpoint half-segments therefore occur at the opposite ends.
        float step = max(0.001, (W - 2.0 * lineWidth) / float(n - 1));
        float f = clamp((W - lineWidth - p.x) / step, 0.0, float(n - 1));
        float bottom;
        if (f >= float(n) - 1.5) {
            vec2 end = tracePoint(0, W, H, n, false, 0.0, 1.0, 1.0);
            vec2 start = (tracePoint(1, W, H, n, false, 0.0, 1.0, 1.0) + end) * 0.5;
            bottom = mix(start.y, end.y, clamp((f - float(n) + 1.5) * 2.0, 0.0, 1.0));
        } else {
            int i = clamp(int(floor(f + 0.5)), 1, n - 2);
            float t = i == 1 ? 2.0 - sqrt(max(0.0, 4.0 - 2.0 * f)) : f - float(i) + 0.5;
            vec2 b = tracePoint(n - 1 - i, W, H, n, false, 0.0, 1.0, 1.0);
            vec2 a = i == 1 ? tracePoint(n - 1, W, H, n, false, 0.0, 1.0, 1.0)
                : (tracePoint(n - i, W, H, n, false, 0.0, 1.0, 1.0) + b) * 0.5;
            vec2 c = (b + tracePoint(n - 2 - i, W, H, n, false, 0.0, 1.0, 1.0)) * 0.5;
            bottom = mix(mix(a.y, b.y, t), mix(b.y, c.y, t), t);
        }
        color = paint(0.32, cover(sdBox(p, vec2(lineWidth, top), vec2(W - lineWidth, bottom))));
    }
    for (int l = 0; l < 3; l++) {
        float phase = float(l) * 1.3;
        float scaleA = l == 0 ? 1.0 : (l == 1 ? 0.7 : 0.45);
        float alpha = l == 0 ? 1.0 : (l == 1 ? 0.55 : 0.3);
        float hw = lineWidth * 0.5;
        float upper = traceDistance(p, W, H, n, false, phase, scaleA, -1.0);
        float lower = traceDistance(p, W, H, n, false, phase, scaleA, 1.0);
        vec4 up = over(paint(alpha, cover(upper - hw)), htmlShadow(alpha * htmlLineGlow(upper, hw)));
        vec4 down = over(paint(alpha, cover(lower - hw)), htmlShadow(alpha * htmlLineGlow(lower, hw)));
        color = over(down, over(up, color));
    }
    return color;
}

vec4 pixelMatrix(vec2 p, float W, float H, int n)
{
    float slot = W / float(n);
    float cell = max(2.0, min(slot, 5.0) * 0.72);
    int rows = max(3, int(floor(H / 5.0)));
    float pitch = H / float(rows);
    int row = int(floor(p.y / pitch));
    int j = int(floor(p.x / slot));
    vec4 color = vec4(0.0);
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n) continue;
        float x = float(i) * slot + (slot - cell) * 0.5;
        for (int r = -1; r <= 1; r++) {
            int rr = row + r;
            if (rr < 0 || rr >= rows) continue;
            float y = float(rr) * pitch + (pitch - cell) * 0.5;
            bool on = abs(float(rr) - float(rows - 1) * 0.5) <= level(i) * float(rows) * 0.5;
            color = over(paint(on ? 1.0 : 0.07, cover(sdBox(p, vec2(x, y), vec2(x + cell, y + cell)))), color);
        }
    }
    return color;
}

void main()
{
    float W = canvasSize.x;
    float H = canvasSize.y;
    vec2 p = qt_TexCoord0 * canvasSize;
    int n = int(barCount + 0.5);
    int type = int(style + 0.5);
    vec4 color = vec4(0.0);
    float glow = 0.0;
    if (directionDown > 0.5 && type >= 6 && type <= 8) p.y = H - p.y;
    if (n >= 3) {
        if (type == 6) color = peakBars(p, W, H, n, glow);
        else if (type == 7) color = ledMeter(p, W, H, n);
        else if (type == 8) color = mountain(p, W, H, n, glow);
        else if (type == 9) color = oscilloscope(p, W, H, n, glow);
        else if (type == 10) color = ribbonLayers(p, W, H, n);
        else if (type == 12) color = pixelMatrix(p, W, H, n);
    }
    fragColor = over(color, htmlShadow(glow)) * (qt_Opacity * edgeMask());
}
