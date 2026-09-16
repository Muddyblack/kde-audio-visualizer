.pragma library

// Stateless Qt Canvas translation of docs/index.html::drawWave (styles 6–15).
// The audio-frame owner supplies levels, peaks, particles, ripples and time.
// In particular, painting twice cannot advance a particle or decay a peak.

function alpha(color, value) {
    return Qt.rgba(color.r, color.g, color.b, value);
}

function colorAt(stops, position) {
    if (stops.length < 2)
        return stops[0];
    const f = Math.max(0, Math.min(1, position)) * (stops.length - 1);
    const i = Math.min(stops.length - 2, Math.floor(f));
    const t = f - i;
    const a = stops[i], b = stops[i + 1];
    return Qt.rgba(a.r + (b.r - a.r) * t, a.g + (b.g - a.g) * t,
                   a.b + (b.b - a.b) * t, a.a + (b.a - a.a) * t);
}

function paintFor(ctx, stops, width) {
    if (stops.length === 1)
        return stops[0];
    const gradient = ctx.createLinearGradient(0, 0, width, 0);
    for (let i = 0; i < stops.length; i++)
        gradient.addColorStop(i / (stops.length - 1), stops[i]);
    return gradient;
}

function roundRect(ctx, x, y, width, height, radius) {
    const r = Math.max(0, Math.min(radius, width / 2, height / 2));
    ctx.moveTo(x + r, y);
    ctx.lineTo(x + width - r, y);
    ctx.arcTo(x + width, y, x + width, y + r, r);
    ctx.lineTo(x + width, y + height - r);
    ctx.arcTo(x + width, y + height, x + width - r, y + height, r);
    ctx.lineTo(x + r, y + height);
    ctx.arcTo(x, y + height, x, y + height - r, r);
    ctx.lineTo(x, y + r);
    ctx.arcTo(x, y, x + r, y, r);
    ctx.closePath();
}

function smoothTrace(ctx, points, move) {
    if (move)
        ctx.moveTo(points[0][0], points[0][1]);
    else
        ctx.lineTo(points[0][0], points[0][1]);
    for (let i = 1; i < points.length - 1; i++)
        ctx.quadraticCurveTo(points[i][0], points[i][1],
                             (points[i][0] + points[i + 1][0]) / 2,
                             (points[i][1] + points[i + 1][1]) / 2);
    ctx.lineTo(points[points.length - 1][0], points[points.length - 1][1]);
}

// Canvas shadowBlur runs a CPU image blur for every primitive. Two extra
// strokes bound the work while approximating the reference's Gaussian bloom.
// With glow disabled, the reference paths and alphas are used directly.
function halo(ctx, glow, scale, color) {
    if (glow <= 0)
        return;
    const width = ctx.lineWidth, opacity = ctx.globalAlpha, paint = ctx.strokeStyle;
    ctx.strokeStyle = color;
    const spread = (scale || 7) * glow;
    ctx.lineWidth = width + spread * 1.6;
    ctx.globalAlpha = opacity * .065;
    ctx.stroke();
    ctx.lineWidth = width + spread * .65;
    ctx.globalAlpha = opacity * .13;
    ctx.stroke();
    ctx.lineWidth = width;
    ctx.globalAlpha = opacity;
    ctx.strokeStyle = paint;
}

function stroke(ctx, glow, scale, color) {
    halo(ctx, glow, scale, color);
    ctx.stroke();
}

function particleHalos(ctx, particles, glow, color) {
    if (glow <= 0)
        return;
    const paint = ctx.fillStyle;
    ctx.fillStyle = color;
    // Four opacity groups keep the halo work bounded at eight fills even when
    // all 32 particles are alive. The particle cores retain their exact alpha.
    for (let layer = 0; layer < 2; layer++) {
        const spread = glow * (layer ? 2.275 : 5.6);
        for (let group = 0; group < 4; group++) {
            ctx.beginPath();
            for (let i = 0; i < Math.min(32, particles.length); i++) {
                const p = particles[i];
                if (Math.min(3, Math.floor(p.life * 4)) !== group)
                    continue;
                const radius = p.r + spread;
                ctx.moveTo(p.x + radius, p.y);
                ctx.arc(p.x, p.y, radius, 0, 7);
            }
            ctx.globalAlpha = (group + .5) / 4 * (layer ? .13 : .065);
            ctx.fill();
        }
    }
    ctx.fillStyle = paint;
}

function ribbonHalo(ctx, points, glow, color) {
    if (glow <= 0)
        return;
    const paint = ctx.fillStyle;
    ctx.fillStyle = color;
    // A ribbon is one luminous surface. Fill its expanded silhouette twice
    // instead of stroking every filament with a wide, complex gradient pen.
    for (let layer = 0; layer < 2; layer++) {
        const spread = glow * (layer ? 5.2 : 12.8);
        ctx.beginPath();
        for (let j = 0; j < points.length; j++) {
            const p = points[j], y = p[1] - p[2] / 2 - spread;
            if (j)
                ctx.lineTo(p[0], y);
            else
                ctx.moveTo(p[0], y);
        }
        for (let j = points.length - 1; j >= 0; j--) {
            const p = points[j];
            ctx.lineTo(p[0], p[1] + p[2] / 2 + spread);
        }
        ctx.closePath();
        ctx.globalAlpha = layer ? .11 : .055;
        ctx.fill();
    }
    ctx.fillStyle = paint;
}

function draw(ctx, o) {
    const w = o.width, h = o.height, c = h / 2, lw = o.lineWidth;
    const levels = o.levels, n = levels.length, type = o.type;
    if (n < 2 || w <= 0 || h <= 0)
        return;
    const t = o.reducedMotion ? 0 : o.time;
    const stops = o.stops, paint = paintFor(ctx, stops, w);
    const glowColor = stops[Math.floor(stops.length / 2)];
    const glow = o.glow ? Math.max(0, Math.min(2, o.bloom)) : 0;
    ctx.lineJoin = "round";
    ctx.lineCap = "round";
    ctx.lineWidth = lw;
    ctx.strokeStyle = paint;
    ctx.fillStyle = paint;

    switch (type) {
    case 6: {
        const slot = w / n, bw = Math.max(1.5, slot * .58);
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const bh = Math.max(Math.min(lw, 2), levels[i] * h * .86);
            roundRect(ctx, i * slot + (slot - bw) / 2, h - bh, bw, bh, bw / 2);
        }
        ctx.globalAlpha = o.fill ? .75 : 1;
        halo(ctx, glow, 7, glowColor);
        ctx.fill();
        ctx.globalAlpha = .9;
        ctx.beginPath();
        for (let i = 0; i < n; i++)
            roundRect(ctx, i * slot + (slot - bw) / 2,
                      h - (o.peaks[i] || 0) * h * .86 - 4, bw, 2, 1);
        ctx.fill();
        break;
    }
    case 7: {
        const slot = w / n, bw = Math.max(2, slot * .7), seg = 4;
        const rows = Math.floor(h / seg);
        for (let i = 0; i < n; i++) {
            const lit = Math.round(levels[i] * rows);
            for (let r = 0; r < rows; r++) {
                ctx.fillStyle = r >= lit ? "rgba(255,255,255,0.06)"
                    : o.colorMode === "solid" && r > rows * .78 ? "#ff6b6b"
                    : o.colorMode === "solid" && r > rows * .55 ? "#ffd166" : paint;
                ctx.fillRect(i * slot + (slot - bw) / 2, h - (r + 1) * seg + 1,
                             bw, seg - 1.3);
            }
        }
        break;
    }
    case 8: {
        const points = [];
        for (let i = 0; i < n; i++)
            points.push([i / (n - 1) * w, h - lw - levels[i] * (h - lw * 2) * .95]);
        ctx.beginPath();
        ctx.moveTo(0, h);
        smoothTrace(ctx, points, false);
        ctx.lineTo(w, h);
        ctx.closePath();
        const gradient = ctx.createLinearGradient(0, 0, 0, h);
        const base = stops[Math.min(1, stops.length - 1)];
        gradient.addColorStop(0, alpha(base, .55));
        gradient.addColorStop(1, alpha(base, .02));
        ctx.fillStyle = gradient;
        ctx.fill();
        ctx.beginPath();
        smoothTrace(ctx, points, true);
        stroke(ctx, glow, 7, glowColor);
        break;
    }
    case 9: {
        ctx.beginPath();
        for (let x = 0; x <= w; x += 1.5) {
            const f = x / w * (n - 1), i = Math.floor(f);
            const a = levels[i] + (levels[Math.min(n - 1, i + 1)] - levels[i]) * (f - i);
            const y = c + Math.sin(x * .11 + t * 9) * a * (c - lw)
                      * (.65 + .35 * Math.sin(x * .025 - t * 3));
            if (x)
                ctx.lineTo(x, y);
            else
                ctx.moveTo(x, y);
        }
        stroke(ctx, glow, 7, glowColor);
        break;
    }
    case 10: {
        const layers = [[1, 0, 1], [.7, 1.3, .55], [.45, 2.6, .3]];
        for (let layer = 0; layer < layers.length; layer++) {
            const scale = layers[layer][0], phase = layers[layer][1], opacity = layers[layer][2];
            const up = [], down = [];
            for (let i = 0; i < n; i++) {
                const x = lw + i / (n - 1) * (w - 2 * lw);
                const a = levels[i] * (c - lw) * scale * (.75 + .25 * Math.sin(t * 2 + i * .3 + phase));
                up.push([x, c - a]);
                down.push([x, c + a]);
            }
            if (o.fill && opacity === 1) {
                ctx.beginPath();
                smoothTrace(ctx, up, true);
                smoothTrace(ctx, down.slice().reverse(), false);
                ctx.closePath();
                ctx.globalAlpha = .32;
                ctx.fill();
            }
            ctx.globalAlpha = opacity;
            ctx.beginPath();
            smoothTrace(ctx, up, true);
            stroke(ctx, glow, 7, glowColor);
            ctx.beginPath();
            smoothTrace(ctx, down, true);
            stroke(ctx, glow, 7, glowColor);
        }
        break;
    }
    case 11: {
        const cx = w / 2, r0 = c * .42;
        ctx.lineWidth = Math.max(1, lw * .8);
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const angle = i / n * Math.PI * 2 - t * .25;
            const length = levels[i] * c * .56 + 1;
            ctx.moveTo(cx + Math.cos(angle) * r0, c + Math.sin(angle) * r0);
            ctx.lineTo(cx + Math.cos(angle) * (r0 + length), c + Math.sin(angle) * (r0 + length));
        }
        stroke(ctx, glow, 7, glowColor);
        ctx.globalAlpha = .35;
        ctx.beginPath();
        ctx.arc(cx, c, r0 * (.9 + .15 * o.bass * o.energy), 0, 7);
        stroke(ctx, glow, 7, glowColor);
        break;
    }
    case 12: {
        const slot = w / n, cell = Math.max(2, Math.min(slot, 5) * .72);
        const rows = Math.max(3, Math.floor(h / 5)), middle = (rows - 1) / 2;
        for (let i = 0; i < n; i++) {
            const reach = levels[i] * (rows / 2);
            for (let r = 0; r < rows; r++) {
                ctx.globalAlpha = Math.abs(r - middle) <= reach ? 1 : .07;
                ctx.fillRect(i * slot + (slot - cell) / 2,
                             r * (h / rows) + (h / rows - cell) / 2, cell, cell);
            }
        }
        break;
    }
    case 13: {
        const cx = w / 2, radius = c * (.3 + .55 * o.bass * o.energy) + 2;
        const gradient = ctx.createRadialGradient(cx, c, 0, cx, c, radius * 1.6);
        // The HTML uses opaque HSL stops after hue/rainbow conversion, while
        // unshifted hex colours fade. Preserve that reference distinction.
        const opaque = o.colorMode === "rainbow" || o.hueShifted;
        gradient.addColorStop(0, alpha(stops[0], opaque ? 1 : .95));
        gradient.addColorStop(.55, alpha(stops[0], opaque ? 1 : .35));
        gradient.addColorStop(1, Qt.rgba(0, 0, 0, 0));
        ctx.fillStyle = gradient;
        ctx.beginPath();
        ctx.arc(cx, c, radius * 1.6, 0, 7);
        ctx.fill();
        ctx.lineWidth = 1;
        for (let ring = 0; ring < 3; ring++) {
            const phase = (t * .6 + ring / 3) % 1;
            ctx.globalAlpha = (1 - phase) * .5 * o.energy;
            ctx.beginPath();
            ctx.arc(cx, c, radius + phase * c * 1.4, 0, 7);
            ctx.stroke();
        }
        ctx.globalAlpha = .55;
        ctx.fillStyle = paint;
        ctx.beginPath();
        const slot = w / n;
        for (let i = 0; i < n; i++) {
            const x = (i + .5) * slot;
            if (Math.abs(x - cx) < radius * 1.8)
                continue;
            const a = levels[i] * c * .8;
            ctx.moveTo(x + 1, c - a);
            ctx.arc(x, c - a, 1, 0, 7);
            ctx.moveTo(x + 1, c + a);
            ctx.arc(x, c + a, 1, 0, 7);
        }
        ctx.fill();
        break;
    }
    case 14: {
        const slot = w / n;
        ctx.beginPath();
        for (let i = 0; i < n; i++) {
            const x = (i + .5) * slot;
            if (i)
                ctx.lineTo(x, c - levels[i] * (c - lw) * .25);
            else
                ctx.moveTo(x, c);
        }
        ctx.globalAlpha = .35;
        ctx.lineWidth = 1;
        stroke(ctx, glow, 7, glowColor);
        particleHalos(ctx, o.particles, glow, glowColor);
        for (let i = 0; i < Math.min(32, o.particles.length); i++) {
            const particle = o.particles[i];
            ctx.globalAlpha = particle.life;
            ctx.beginPath();
            ctx.arc(particle.x, particle.y, particle.r, 0, 7);
            ctx.fill();
        }
        break;
    }
    case 15: {
        const energy = o.energy, curvature = o.curvature, fullness = o.fullness;
        const bend = o.reducedMotion ? .4 : o.mid, points = [];
        const steps = Math.max(24, Math.floor(w / 4));
        for (let j = 0; j <= steps; j++) {
            const p = j / steps, x = p * w, envelope = Math.pow(Math.sin(p * Math.PI), .7);
            const f = p * (n - 1), i = Math.floor(f);
            const a = levels[i] + (levels[Math.min(n - 1, i + 1)] - levels[i]) * (f - i);
            const y = c + Math.sin(p * Math.PI * 1.6 * curvature + t * .7)
                      * c * .32 * bend * curvature * energy;
            const thickness = (1.2 + (o.bass * .55 + a * .8) * c * .9 * fullness)
                              * envelope * (energy * .92 + .08);
            points.push([x, y, thickness, a]);
        }
        ctx.save();
        ctx.globalCompositeOperation = "lighter";
        ribbonHalo(ctx, points, glow, glowColor);
        ctx.beginPath();
        for (let j = 0; j < points.length; j++) {
            const p = points[j];
            if (j)
                ctx.lineTo(p[0], p[1] - p[2] / 2);
            else
                ctx.moveTo(p[0], p[1] - p[2] / 2);
        }
        for (let j = points.length - 1; j >= 0; j--)
            ctx.lineTo(points[j][0], points[j][1] + points[j][2] / 2);
        ctx.closePath();
        ctx.globalAlpha = .28;
        ctx.fill();
        ctx.lineWidth = .8;
        for (let filament = -2; filament <= 2; filament++) {
            ctx.beginPath();
            for (let j = 0; j < points.length; j++) {
                const p = points[j];
                const y = p[1] + p[2] * filament / 5
                          + Math.sin(p[0] * .19 + t * 4 + filament) * o.high * p[3] * 2.2;
                if (j)
                    ctx.lineTo(p[0], y);
                else
                    ctx.moveTo(p[0], y);
            }
            ctx.globalAlpha = filament === 0 ? .95 : .4;
            ctx.stroke();
        }
        for (let i = 0; i < Math.min(4, o.ripples.length); i++) {
            const ripple = o.ripples[i];
            ctx.globalAlpha = (1 - ripple.age) * .6;
            ctx.lineWidth = 1;
            const rx = 4 + ripple.age * 30, ry = 2 + ripple.age * c * .7;
            ctx.beginPath();
            // Qt's ellipse(rect) uses a different path approximation. A unit
            // circle under a transform preserves the browser ellipse angles.
            ctx.save();
            ctx.translate(ripple.x, c);
            ctx.scale(rx, ry);
            ctx.arc(0, 0, 1, 0, 7);
            ctx.restore();
            ctx.stroke();
        }
        ctx.restore();
        break;
    }
    }
    ctx.globalAlpha = 1;
}
