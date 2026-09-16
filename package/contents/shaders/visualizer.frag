// Shared prelude: viz_common.glsl (assembled by build_shaders.py).
// Legacy styles retain their established geometry and calibrated glow.
// ── Style 0: mirrored smooth wave ───────────────────────────────────────────
// WaveCanvas joins samples with cubic beziers whose control points share the
// segment's mid x: x(t) = x0 + step * (1.5t - 1.5t² + t³) and the height
// follows smoothstep(t) between the two samples.
float waveHeight(float x, float step, int n)
{
    float fi = clamp(floor(x / step), 0.0, float(n - 2));
    int i = int(fi);
    float u = clamp(x / step - fi, 0.0, 1.0);
    float t = u;
    for (int k = 0; k < 4; k++) {
        float f = t * (1.5 + t * (t - 1.5)) - u;
        float df = 1.5 + t * (3.0 * t - 3.0);
        t = clamp(t - f / df, 0.0, 1.0);
    }
    return mix(level(i), level(i + 1), t * t * (3.0 - 2.0 * t));
}

// Distance to the upper curve, measured against a fine polyline of each nearby
// bezier segment so steep flanks get true perpendicular distances.
float waveDistance(vec2 p, float step, int n, float mid, float amp)
{
    float reach = glowReach();
    float d = 1.0e5;
    int j = int(clamp(floor(p.x / step), 0.0, float(n - 2)));
    for (int s = -3; s <= 3; s++) {
        int i = j + s;
        if (i < 0 || i > n - 2)
            continue;
        float x0 = float(i) * step;
        if (p.x < x0 - reach || p.x > x0 + step + reach)
            continue;
        float a = level(i);
        float b = level(i + 1);
        vec2 prev = vec2(x0, mid - a * amp);
        for (int k = 1; k <= 6; k++) {
            float t = float(k) / 6.0;
            vec2 cur = vec2(x0 + step * t * (1.5 + t * (t - 1.5)), mid - mix(a, b, t * t * (3.0 - 2.0 * t)) * amp);
            d = min(d, sdSegment(p, prev, cur));
            prev = cur;
        }
    }
    return d;
}

// Upper half; the lower half is drawn by mirroring p around the centre line.
vec4 waveHalf(vec2 p, float W, float H, int n, out float glow)
{
    float mid = H * 0.5;
    float amp = H * 0.42;
    float step = W / float(n - 1);
    float h = mid - p.y;
    float ch = waveHeight(p.x, step, n) * amp;
    float hw = lineWidth * 0.5;
    float d = waveDistance(p, step, n, mid, amp);
    vec4 color = paint(waveColor.a, cover(d - hw));
    glow = waveColor.a * kernelSpan(-hw - d, hw - d);
    if (fillAmount > 0.5) {
        float edge = h < ch ? -d : d;
        float gradient = mix(0.38, 0.02, clamp(h / amp, 0.0, 1.0));
        color = over(tint(unpremultiply(color0), gradient * (cover(edge) * cover(-h))), color);
        glow += mix(0.38, 0.02, clamp(clamp(h, 0.0, ch) / amp, 0.0, 1.0)) * kernelSpan(-h, ch - h);
    }
    return color;
}

vec4 styleWave(vec2 p, float W, float H, int n, out float glow)
{
    float glowUpper;
    float glowLower;
    vec4 upper = waveHalf(p, W, H, n, glowUpper);
    vec4 lower = waveHalf(vec2(p.x, H - p.y), W, H, n, glowLower);
    glow = glowUpper + glowLower;
    return over(lower, upper);
}

// ── Style 1: bars from the bottom ───────────────────────────────────────────
// WaveCanvas closes each bar's path back to its start at the top of the cap,
// so the left edge runs diagonally from the bottom-left corner to the cap top,
// leaving a sliver of the cap's left half: a "fin".
float sdFin(vec2 p, float x0, float y0, float r, float H)
{
    vec2 c = vec2(x0 + r, y0 + r);
    float disc = length(p - c) - r;
    float body = min(disc, sdBox(p, vec2(x0, y0 + r), vec2(x0 + 2.0 * r, H + r)));
    float diagonal = dot(p - vec2(x0, H), normalize(vec2(y0 - H, -r)));
    float sliver = max(disc, dot(p - vec2(x0 + r, y0), vec2(0.70710678)));
    return min(max(body, diagonal), sliver);
}

vec4 styleBars(vec2 p, float W, float H, int n, out float glow)
{
    float slot = W / float(n);
    float gap = max(1.0, slot * 0.25);
    float barW = max(1.0, slot - gap);
    float r = barW * 0.5;
    float amp = H * 0.88;
    float pitch = barW + gap;
    int j = int(floor((p.x - gap * 0.5) / pitch));
    vec4 color = vec4(0.0);
    glow = 0.0;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n)
            continue;
        float bh = max(2.0, level(i) * amp);
        float x0 = float(i) * pitch + gap * 0.5;
        float y0 = H - bh;
        bool fin = bh > 2.0 * r;
        float sd = fin ? sdFin(p, x0, y0, r, H) : length(p - vec2(x0 + r, y0 + r)) - r;
        float gradient = mix(0.95, 0.35, clamp((p.y - y0) / bh, 0.0, 1.0));
        color = over(tint(unpremultiply(gradientColor((x0 + r) / W)), gradient * cover(sd)), color);
        // The fin narrows towards the top; blur the box at this pixel's width.
        float left = fin ? x0 + r * clamp((H - p.y) / bh, 0.0, 1.0) : x0;
        glow += gradient * kernelBox(p, vec2(left, y0), vec2(x0 + barW, H + 4.0 * glowSigma2));
    }
    return color;
}

// ── Style 2: bars mirrored around the centre ────────────────────────────────
vec4 styleMirrorBars(vec2 p, float W, float H, int n, out float glow)
{
    float slot = W / float(n);
    float gap = max(1.0, slot * 0.22);
    float barW = max(1.0, slot - gap);
    float r = barW * 0.5;
    float amp = H * 0.44;
    float mid = H * 0.5;
    float pitch = barW + gap;
    int j = int(floor((p.x - gap * 0.5) / pitch));
    vec4 color = vec4(0.0);
    glow = 0.0;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n)
            continue;
        float bh = max(2.0, level(i) * amp);
        float x0 = float(i) * pitch + gap * 0.5;
        float cx = x0 + r;
        float gradient = mix(0.95, 0.35, clamp(abs(p.y - mid) / bh, 0.0, 1.0));
        float sdTop;
        float sdBottom;
        float bottomEnd;
        if (bh > r) {
            // Top: box from the cap centre to the middle plus the upper half disc.
            // Each half disc reaches 1 px past its flat side, so it never shares
            // an edge with the box; coincident edges leak coverage as a seam.
            float cy = mid - bh + r;
            float cap = max(length(p - vec2(cx, cy)) - r, p.y - cy - 1.0);
            sdTop = min(sdBox(p, vec2(x0, cy), vec2(x0 + barW, mid)), cap);
            // Bottom: WaveCanvas' arc bends back up, notching the bar's end.
            float by = mid + bh - r;
            float notch = max(length(p - vec2(cx, by)) - r, p.y - by - 1.0);
            sdBottom = max(sdBox(p, vec2(x0, mid), vec2(x0 + barW, by)), -notch);
            bottomEnd = by - 0.5 * r;
        } else {
            sdTop = length(p - vec2(cx, mid - r)) - r;
            sdBottom = length(p - vec2(cx, mid + r)) - r;
            bottomEnd = mid + 2.0 * r;
        }
        color = over(tint(unpremultiply(gradientColor(cx / W)), gradient * cover(sdTop)), color);
        color = over(tint(unpremultiply(gradientColor(cx / W)), gradient * cover(sdBottom)), color);
        glow += gradient * kernelBox(p, vec2(x0, mid - bh), vec2(x0 + barW, bottomEnd));
    }
    return color;
}

// ── Style 3: stepped "tech" line with node dots ─────────────────────────────
vec4 styleTechHalf(vec2 p, float sign, float W, float H, int n, out float glow)
{
    float mid = H * 0.5;
    float amp = H * 0.42;
    float step = W / float(max(n - 1, 1));
    int j = int(floor(p.x / step));
    float line = 1.0e5;
    float dot = 1.0e5;
    for (int k = -2; k <= 2; k++) {
        int i = j + k;
        if (i < 0 || i >= n)
            continue;
        float x = float(i) * step;
        float y = mid + sign * level(i) * amp;
        dot = min(dot, length(p - vec2(x, y)));
        if (i + 1 < n) {
            float y1 = mid + sign * level(i + 1) * amp;
            float xm = x + step * 0.5;
            line = min(line, sdSegment(p, vec2(x, y), vec2(xm, y)));
            line = min(line, sdSegment(p, vec2(xm, y), vec2(xm, y1)));
            line = min(line, sdSegment(p, vec2(xm, y1), vec2(x + step, y1)));
        }
    }
    float hw = lineWidth * 0.5;
    glow = waveColor.a * (kernelSpan(-hw - line, hw - line) + kernelDisc(dot, 1.6));
    vec4 color = paint(waveColor.a, cover(line - hw));
    return over(paint(waveColor.a, cover(dot - 1.6)), color);
}

vec4 styleTech(vec2 p, float W, float H, int n, out float glow)
{
    float glowUpper;
    float glowLower;
    vec4 upper = styleTechHalf(p, -1.0, W, H, n, glowUpper);
    vec4 lower = styleTechHalf(p, 1.0, W, H, n, glowLower);
    glow = glowUpper + glowLower;
    return over(lower, upper);
}

// ── Styles 4 and 5: floating dots and rings ─────────────────────────────────
vec4 dotSoft(vec2 p, vec2 c, float radius, inout float glow)
{
    float d = length(p - c);
    // Solid core, then a radial halo from 0.3r (alpha .55) to r (alpha 0).
    vec3 rgb = unpremultiply(gradientColor(c.x / canvasSize.x));
    vec4 color = tint(rgb, 0.92 * cover(d - radius * 0.45));
    float halo = mix(0.55, 0.0, clamp((d - radius * 0.3) / (radius * 0.7), 0.0, 1.0));
    color = over(tint(rgb, halo * cover(d - radius)), color);
    glow += 0.9 * kernelDisc(d, radius * 0.62);
    return color;
}

vec4 dotRing(vec2 p, vec2 c, float radius, float strokeW, inout float glow)
{
    float d = length(p - c);
    float core = max(0.8, radius * 0.38);
    vec3 rgb = unpremultiply(gradientColor(c.x / canvasSize.x));
    vec4 color = tint(rgb, cover(d - core));
    float hw = strokeW * 0.5;
    color = over(tint(rgb, 0.75 * cover(abs(d - radius) - hw)), color);
    float ring = abs(d - radius);
    glow += kernelDisc(d, core) + 0.75 * kernelSpan(-hw - ring, hw - ring) * min(1.0, radius / (1.5 * glowSigma));
    return color;
}

vec4 styleDots(vec2 p, float W, float H, int n, bool rings, out float glow)
{
    float step = W / float(n);
    float amp = H * 0.42;
    float mid = H * 0.5;
    float maxR = rings ? max(2.0, step * 0.32) : max(2.0, step * 0.28 * (lineWidth / 2.0));
    float strokeW = max(0.8, lineWidth * 0.6);
    int j = int(floor(p.x / step));
    vec4 color = vec4(0.0);
    glow = 0.0;
    for (int k = -3; k <= 3; k++) {
        int i = j + k;
        if (i < 0 || i >= n)
            continue;
        float lv = level(i);
        float cx = float(i) * step + step * 0.5;
        float radius = max(1.5, lv * maxR);
        vec2 up = vec2(cx, mid - lv * amp);
        vec2 down = vec2(cx, mid + lv * amp);
        if (rings) {
            color = over(dotRing(p, up, radius, strokeW, glow), color);
            color = over(dotRing(p, down, radius, strokeW, glow), color);
        } else {
            color = over(dotSoft(p, up, radius, glow), color);
            color = over(dotSoft(p, down, radius, glow), color);
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
    if (type == 1 && directionDown > 0.5)
        p.y = H - p.y;
    float glow = 0.0;
    vec4 color = vec4(0.0);
    if (n >= 2 || (n >= 1 && type != 0 && type != 3)) {
        if (type == 0)
            color = styleWave(p, W, H, n, glow);
        else if (type == 1)
            color = styleBars(p, W, H, n, glow);
        else if (type == 2)
            color = styleMirrorBars(p, W, H, n, glow);
        else if (type == 3)
            color = styleTech(p, W, H, n, glow);
        else
            color = styleDots(p, W, H, n, type == 5, glow);
    }
    // MultiEffect shadow: the drawing over a wave-coloured blurred alpha.
    vec4 shadow = color0 * clamp(glow * glowAmount, 0.0, 1.0);
    fragColor = over(color, shadow) * (qt_Opacity * edgeMask());
}
