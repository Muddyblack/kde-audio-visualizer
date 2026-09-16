#version 440
// Shared uniforms and analytic geometry for all visualizer shader families.
// build_shaders.py concatenates this prelude before each family for qsb.

layout(location = 0) in vec2 qt_TexCoord0;
layout(location = 0) out vec4 fragColor;

layout(std140, binding = 0) uniform buf {
    mat4 qt_Matrix;
    float qt_Opacity;
    vec2 canvasSize;
    float pixelRatio;
    float style;
    float barCount;
    float lineWidth;
    float fillAmount;
    float glowAmount;
    float glowSigma;
    float glowGain;
    float glowSigma2;
    float glowGain2;
    vec4 waveColor;
    vec4 levels0;
    vec4 levels1;
    vec4 levels2;
    vec4 levels3;
    vec4 levels4;
    vec4 levels5;
    vec4 levels6;
    vec4 levels7;
    vec4 levels8;
    vec4 levels9;
    vec4 levels10;
    vec4 levels11;
    vec4 levels12;
    vec4 levels13;
    vec4 levels14;
    vec4 levels15;
    vec4 levels16;
    vec4 levels17;
    vec4 levels18;
    vec4 levels19;
    vec4 levels20;
    vec4 levels21;
    vec4 levels22;
    vec4 levels23;
    vec4 levels24;
    vec4 levels25;
    vec4 levels26;
    vec4 levels27;
    vec4 levels28;
    vec4 levels29;
    vec4 levels30;
    vec4 levels31;
    float timeSeconds;
    float bass;
    float mid;
    float high;
    float energy;
    float reducedMotion;
    float directionDown;
    float solidMode;
    float opaqueOrb;
    float colorCount;
    float bloom;
    float ribbonCurvature;
    float ribbonFullness;
    float particleCount;
    float rippleCount;
    float edgeFade;
    vec4 color0;
    vec4 color1;
    vec4 color2;
    vec4 color3;
    vec4 color4;
    vec4 color5;
#ifdef VIZ_LINEAR
    vec4 peaks0;
    vec4 peaks1;
    vec4 peaks2;
    vec4 peaks3;
    vec4 peaks4;
    vec4 peaks5;
    vec4 peaks6;
    vec4 peaks7;
    vec4 peaks8;
    vec4 peaks9;
    vec4 peaks10;
    vec4 peaks11;
    vec4 peaks12;
    vec4 peaks13;
    vec4 peaks14;
    vec4 peaks15;
    vec4 peaks16;
    vec4 peaks17;
    vec4 peaks18;
    vec4 peaks19;
    vec4 peaks20;
    vec4 peaks21;
    vec4 peaks22;
    vec4 peaks23;
    vec4 peaks24;
    vec4 peaks25;
    vec4 peaks26;
    vec4 peaks27;
    vec4 peaks28;
    vec4 peaks29;
    vec4 peaks30;
    vec4 peaks31;
#endif
#ifdef VIZ_PARTICLES
    vec4 particle0;
    vec4 particle1;
    vec4 particle2;
    vec4 particle3;
    vec4 particle4;
    vec4 particle5;
    vec4 particle6;
    vec4 particle7;
    vec4 particle8;
    vec4 particle9;
    vec4 particle10;
    vec4 particle11;
    vec4 particle12;
    vec4 particle13;
    vec4 particle14;
    vec4 particle15;
    vec4 particle16;
    vec4 particle17;
    vec4 particle18;
    vec4 particle19;
    vec4 particle20;
    vec4 particle21;
    vec4 particle22;
    vec4 particle23;
    vec4 particle24;
    vec4 particle25;
    vec4 particle26;
    vec4 particle27;
    vec4 particle28;
    vec4 particle29;
    vec4 particle30;
    vec4 particle31;
#endif
#ifdef VIZ_RIBBON
    vec4 ripple0;
    vec4 ripple1;
    vec4 ripple2;
    vec4 ripple3;
#endif
};

// ShaderEffect has no array uniforms, so levels arrive four per vec4.
vec4 block(int b)
{
    if (b < 16) {
        if (b < 8) {
            if (b < 4)
                return b < 2 ? (b < 1 ? levels0 : levels1) : (b < 3 ? levels2 : levels3);
            return b < 6 ? (b < 5 ? levels4 : levels5) : (b < 7 ? levels6 : levels7);
        }
        if (b < 12)
            return b < 10 ? (b < 9 ? levels8 : levels9) : (b < 11 ? levels10 : levels11);
        return b < 14 ? (b < 13 ? levels12 : levels13) : (b < 15 ? levels14 : levels15);
    }
    if (b < 24) {
        if (b < 20)
            return b < 18 ? (b < 17 ? levels16 : levels17) : (b < 19 ? levels18 : levels19);
        return b < 22 ? (b < 21 ? levels20 : levels21) : (b < 23 ? levels22 : levels23);
    }
    if (b < 28)
        return b < 26 ? (b < 25 ? levels24 : levels25) : (b < 27 ? levels26 : levels27);
    return b < 30 ? (b < 29 ? levels28 : levels29) : (b < 31 ? levels30 : levels31);
}

// Normalised, tapered sample i (0 outside the configured bars).
float level(int i)
{
    int n = int(barCount + 0.5);
    if (i < 0 || i >= n)
        return 0.0;
    int b = i / 4;
    int c = i - b * 4;
    vec4 v = block(b);
    return c == 0 ? v.x : (c == 1 ? v.y : (c == 2 ? v.z : v.w));
}

float erfApprox(float x)
{
    // Abramowitz & Stegun 7.1.27, error below 5e-4.
    float a = abs(x);
    float t = 1.0 + (0.278393 + (0.230389 + (0.000972 + 0.078108 * a) * a) * a) * a;
    t *= t;
    return sign(x) * (1.0 - 1.0 / (t * t));
}

// Mass of a unit 1D Gaussian inside [lo, hi].
float gaussSpan(float lo, float hi, float sigma)
{
    float k = 0.70710678 / sigma;
    return 0.5 * (erfApprox(hi * k) - erfApprox(lo * k));
}

// The glow kernel is a mix of a narrow and a wide Gaussian, fitted to
// MultiEffect { shadowBlur: 1; blurMax: 8 } as WaveCanvas configures it.
float kernelSpan(float lo, float hi)
{
    return glowGain * gaussSpan(lo, hi, glowSigma) + glowGain2 * gaussSpan(lo, hi, glowSigma2);
}

// Blurred alpha of an axis-aligned box.
float kernelBox(vec2 p, vec2 lo, vec2 hi)
{
    return glowGain * gaussSpan(lo.x - p.x, hi.x - p.x, glowSigma) * gaussSpan(lo.y - p.y, hi.y - p.y, glowSigma)
        + glowGain2 * gaussSpan(lo.x - p.x, hi.x - p.x, glowSigma2) * gaussSpan(lo.y - p.y, hi.y - p.y, glowSigma2);
}

// Blurred alpha of a small disc: exact at its centre, Gaussian falloff.
float kernelDisc(float d, float r)
{
    float s1 = glowSigma * glowSigma;
    float s2 = glowSigma2 * glowSigma2;
    float rr = r * r;
    return glowGain * (1.0 - exp(-rr / (2.0 * s1))) * exp(-d * d / (2.0 * s1 + 0.5 * rr))
        + glowGain2 * (1.0 - exp(-rr / (2.0 * s2))) * exp(-d * d / (2.0 * s2 + 0.5 * rr));
}

// Pixel coverage for a signed distance (negative inside), one device pixel wide.
float cover(float sd)
{
    return clamp(0.5 - sd * pixelRatio, 0.0, 1.0);
}

vec4 colorStop(int i)
{
    if (i < 3) return i < 1 ? color0 : (i < 2 ? color1 : color2);
    return i < 4 ? color3 : (i < 5 ? color4 : color5);
}

vec4 gradientColor(float x)
{
    float f = clamp(x, 0.0, 1.0) * max(0.0, colorCount - 1.0);
    int i = int(floor(f));
    return mix(colorStop(i), colorStop(min(i + 1, int(colorCount) - 1)), fract(f));
}

vec3 unpremultiply(vec4 color)
{
    return color.a > 0.0 ? color.rgb / color.a : vec3(0.0);
}

vec3 baseRgb()
{
    return unpremultiply(gradientColor(qt_TexCoord0.x));
}

vec4 paint(float alpha, float coverage)
{
    float a = alpha * coverage;
    return vec4(baseRgb() * a, a);
}

vec4 over(vec4 top, vec4 under)
{
    return top + under * (1.0 - top.a);
}

float sdBox(vec2 p, vec2 lo, vec2 hi)
{
    vec2 d = abs(p - (lo + hi) * 0.5) - (hi - lo) * 0.5;
    return length(max(d, 0.0)) + min(max(d.x, d.y), 0.0);
}

float sdSegment(vec2 p, vec2 a, vec2 b)
{
    vec2 pa = p - a;
    vec2 ba = b - a;
    float h = clamp(dot(pa, ba) / max(dot(ba, ba), 1e-6), 0.0, 1.0);
    return length(pa - ba * h);
}

float glowReach()
{
    return lineWidth * 0.5 + 3.0 * max(glowSigma, glowSigma2);
}


// Peak holds and shared particle state are bounded CPU-side.
#ifdef VIZ_LINEAR
vec4 peakBlock(int b)
{
    if (b < 16) {
        if (b < 8) {
            if (b < 4)
                return b < 2 ? (b < 1 ? peaks0 : peaks1) : (b < 3 ? peaks2 : peaks3);
            return b < 6 ? (b < 5 ? peaks4 : peaks5) : (b < 7 ? peaks6 : peaks7);
        }
        if (b < 12)
            return b < 10 ? (b < 9 ? peaks8 : peaks9) : (b < 11 ? peaks10 : peaks11);
        return b < 14 ? (b < 13 ? peaks12 : peaks13) : (b < 15 ? peaks14 : peaks15);
    }
    if (b < 24) {
        if (b < 20)
            return b < 18 ? (b < 17 ? peaks16 : peaks17) : (b < 19 ? peaks18 : peaks19);
        return b < 22 ? (b < 21 ? peaks20 : peaks21) : (b < 23 ? peaks22 : peaks23);
    }
    if (b < 28)
        return b < 26 ? (b < 25 ? peaks24 : peaks25) : (b < 27 ? peaks26 : peaks27);
    return b < 30 ? (b < 29 ? peaks28 : peaks29) : (b < 31 ? peaks30 : peaks31);
}


#endif

#ifdef VIZ_PARTICLES
vec4 particleAt(int b)
{
    if (b < 16) {
        if (b < 8) {
            if (b < 4)
                return b < 2 ? (b < 1 ? particle0 : particle1) : (b < 3 ? particle2 : particle3);
            return b < 6 ? (b < 5 ? particle4 : particle5) : (b < 7 ? particle6 : particle7);
        }
        if (b < 12)
            return b < 10 ? (b < 9 ? particle8 : particle9) : (b < 11 ? particle10 : particle11);
        return b < 14 ? (b < 13 ? particle12 : particle13) : (b < 15 ? particle14 : particle15);
    }
    if (b < 24) {
        if (b < 20)
            return b < 18 ? (b < 17 ? particle16 : particle17) : (b < 19 ? particle18 : particle19);
        return b < 22 ? (b < 21 ? particle20 : particle21) : (b < 23 ? particle22 : particle23);
    }
    if (b < 28)
        return b < 26 ? (b < 25 ? particle24 : particle25) : (b < 27 ? particle26 : particle27);
    return b < 30 ? (b < 29 ? particle28 : particle29) : (b < 31 ? particle30 : particle31);
}


#endif

#ifdef VIZ_LINEAR
float peak(int i)
{
    if (i < 0 || i >= int(barCount)) return 0.0;
    vec4 v = peakBlock(i / 4);
    int c = i - (i / 4) * 4;
    return c == 0 ? v.x : (c == 1 ? v.y : (c == 2 ? v.z : v.w));
}

#endif

#ifdef VIZ_RIBBON
vec4 rippleAt(int i)
{
    return i < 2 ? (i < 1 ? ripple0 : ripple1) : (i < 3 ? ripple2 : ripple3);
}

#endif

float interpolatedLevel(float x, float width, int n)
{
    float f = clamp(x / max(width, 0.001), 0.0, 1.0) * float(n - 1);
    int i = int(floor(f));
    return mix(level(i), level(min(n - 1, i + 1)), fract(f));
}

float sdRoundBox(vec2 p, vec2 lo, vec2 hi, float radius)
{
    float r = min(radius, min(hi.x - lo.x, hi.y - lo.y) * 0.5);
    vec2 q = abs(p - (lo + hi) * 0.5) - (hi - lo) * 0.5 + r;
    return length(max(q, 0.0)) + min(max(q.x, q.y), 0.0) - r;
}

// Browser shadowBlur 7 uses an approximately 3.5 logical-pixel Gaussian.
// Each new family uses this analytic profile; no texture blur pass is needed.
float htmlSigma()
{
    return max(0.01, 3.5 * bloom);
}

float htmlLineGlow(float d, float halfWidth)
{
    return gaussSpan(-halfWidth - d, halfWidth - d, htmlSigma());
}

float htmlDiscGlow(float d, float radius)
{
    float s = htmlSigma() * htmlSigma();
    float rr = radius * radius;
    return (1.0 - exp(-rr / (2.0 * s))) * exp(-d * d / (2.0 * s + 0.5 * rr));
}

float htmlBoxGlow(vec2 p, vec2 lo, vec2 hi)
{
    float sigma = htmlSigma();
    return gaussSpan(lo.x - p.x, hi.x - p.x, sigma) * gaussSpan(lo.y - p.y, hi.y - p.y, sigma);
}

vec4 tint(vec3 rgb, float alpha)
{
    return vec4(rgb * alpha, alpha);
}

vec4 htmlShadow(float glow)
{
    return colorStop(int(floor(colorCount * 0.5))) * clamp(glow * glowAmount, 0.0, 1.0);
}

// Poster texture: fade both sides (transparent → opaque at 14 % and 86 %).
float edgeMask()
{
    if (edgeFade < 0.5)
        return 1.0;
    float x = qt_TexCoord0.x;
    return clamp(min(x, 1.0 - x) / 0.14, 0.0, 1.0);
}
