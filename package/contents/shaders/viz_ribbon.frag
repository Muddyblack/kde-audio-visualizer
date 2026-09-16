// Shared prelude: viz_common.glsl. HTML drawWave style 15 (Silk Ribbon).

// x, centre y, thickness, interpolated spectrum amplitude.
vec4 ribbonPoint(int i, int steps, float W, float H, int n)
{
    float p = clamp(float(i) / float(steps), 0.0, 1.0);
    float x = p * W;
    float c = H * 0.5;
    float envelope = pow(max(0.0, sin(p * 3.14159265359)), 0.7);
    float a = interpolatedLevel(x, W, n);
    float bend = reducedMotion > 0.5 ? 0.4 : mid;
    float y = c + sin(p * 3.14159265359 * 1.6 * ribbonCurvature + timeSeconds * 0.7)
        * c * 0.32 * bend * ribbonCurvature * energy;
    float thickness = (1.2 + (bass * 0.55 + a * 0.8) * c * 0.9 * ribbonFullness)
        * envelope * (energy * 0.92 + 0.08);
    return vec4(x, y, thickness, a);
}

vec2 filamentPoint(vec4 p, float f)
{
    float y = p.y + p.z * f / 5.0 + sin(p.x * 0.19 + timeSeconds * 4.0 + f) * high * p.w * 2.2;
    return vec2(p.x, y);
}

float silkLineGlow(float d, float hw)
{
    return gaussSpan(-hw - d, hw - d, max(0.01, 8.0 * bloom));
}

vec4 silkStroke(float distance, float halfWidth, float alpha)
{
    return paint(alpha, cover(distance - halfWidth)) + htmlShadow(alpha * silkLineGlow(distance, halfWidth));
}

// First-order signed distance to an ellipse. The smooth analytic gradient
// avoids a tessellation loop for each of the at most four attack ripples.
float ellipseDistance(vec2 p, vec2 radii)
{
    float k0 = length(p / radii);
    if (k0 < 1e-6) return -min(radii.x, radii.y);
    float k1 = length(p / (radii * radii));
    return k0 * (k0 - 1.0) / max(k1, 1e-6);
}

void main()
{
    float W = canvasSize.x;
    float H = canvasSize.y;
    vec2 p = qt_TexCoord0 * canvasSize;
    int n = int(barCount + 0.5);
    vec4 color = vec4(0.0);
    if (n >= 2) {
        int steps = max(24, int(floor(W / 4.0)));
        float step = W / float(steps);
        int j = clamp(int(floor(p.x / step)), 0, steps - 1);
        float edges = 1e5;
        vec4 filaments = vec4(1e5);
        float centre = 1e5;
        for (int k = -3; k <= 3; k++) {
            int i = j + k;
            if (i < 0 || i >= steps) continue;
            vec4 a = ribbonPoint(i, steps, W, H, n);
            vec4 b = ribbonPoint(i + 1, steps, W, H, n);
            edges = min(edges, sdSegment(p, vec2(a.x, a.y - a.z * 0.5), vec2(b.x, b.y - b.z * 0.5)));
            edges = min(edges, sdSegment(p, vec2(a.x, a.y + a.z * 0.5), vec2(b.x, b.y + b.z * 0.5)));
            filaments = min(filaments, vec4(
                sdSegment(p, filamentPoint(a, -2.0), filamentPoint(b, -2.0)),
                sdSegment(p, filamentPoint(a, -1.0), filamentPoint(b, -1.0)),
                sdSegment(p, filamentPoint(a, 1.0), filamentPoint(b, 1.0)),
                sdSegment(p, filamentPoint(a, 2.0), filamentPoint(b, 2.0))));
            centre = min(centre, sdSegment(p, filamentPoint(a, 0.0), filamentPoint(b, 0.0)));
        }
        vec4 local = mix(ribbonPoint(j, steps, W, H, n), ribbonPoint(j + 1, steps, W, H, n), clamp(p.x / step - float(j), 0.0, 1.0));
        float top = local.y - local.z * 0.5;
        float bottom = local.y + local.z * 0.5;
        bool inside = p.y >= top && p.y <= bottom;
        float sigma = max(0.01, 8.0 * bloom);
        float fillGlow = gaussSpan(top - p.y, bottom - p.y, sigma)
            * gaussSpan(-p.x, W - p.x, sigma);
        color = paint(0.28, cover(inside ? -edges : edges)) + htmlShadow(0.28 * fillGlow);
        // Canvas uses the lighter composition mode for the translucent body,
        // five filaments and their shadows, so their light adds at crossings.
        color += silkStroke(filaments.x, 0.4, 0.4);
        color += silkStroke(filaments.y, 0.4, 0.4);
        color += silkStroke(centre, 0.4, 0.95);
        color += silkStroke(filaments.z, 0.4, 0.4);
        color += silkStroke(filaments.w, 0.4, 0.4);
        for (int i = 0; i < 4; i++) {
            if (float(i) >= rippleCount) break;
            vec4 ripple = rippleAt(i);
            vec2 radii = vec2(4.0 + ripple.y * 30.0, 2.0 + ripple.y * H * 0.35);
            float d = abs(ellipseDistance(p - vec2(ripple.x, H * 0.5), radii));
            color += silkStroke(d, 0.5, (1.0 - ripple.y) * 0.6);
        }
    }
    fragColor = clamp(color, 0.0, 1.0) * (qt_Opacity * edgeMask());
}
