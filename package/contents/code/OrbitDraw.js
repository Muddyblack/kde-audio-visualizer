.pragma library
.import "WaveDraw.js" as WaveDraw

// Stateless Qt Canvas translation of docs/index.html::drawOrbit. The owner
// supplies mirrored ring values, geometry, rotation, time and spark state.

function draw(ctx, o) {
    const w = o.width, h = o.height, cx = w / 2, cy = h / 2;
    const values = o.values, half = values.length, n = half * 2;
    if (half < 1 || w <= 0 || h <= 0)
        return;
    const R = o.R, reach = o.reach, lw = o.lineWidth, t = o.t, stops = o.stops;
    const val = j => values[j < half ? j : n - 1 - j];
    const ang = j => j / n * Math.PI * 2 + o.rot - Math.PI / 2;
    const at = (r, a) => [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
    const glowColor = stops[0];

    // The HTML uses a clockwise conic gradient starting at the top and turning
    // with the ring; Qt's conical gradient runs counter-clockwise, so the stops
    // are reversed and the start angle mirrored.
    let paint = stops[0];
    if (stops.length > 1) {
        const gradient = ctx.createConicalGradient(cx, cy, Math.PI / 2 - o.rot);
        const ring = stops.concat([stops[0]]);
        for (let i = 0; i < ring.length; i++)
            gradient.addColorStop(1 - i / (ring.length - 1), ring[i]);
        paint = gradient;
    }
    ctx.strokeStyle = paint;
    ctx.fillStyle = paint;
    ctx.lineCap = "round";
    ctx.lineJoin = "round";

    ctx.globalAlpha = 0.18;
    ctx.lineWidth = 1;
    ctx.beginPath();
    ctx.arc(cx, cy, R, 0, Math.PI * 2);
    ctx.stroke();
    ctx.globalAlpha = 1;

    switch (o.style) {
    case "wave": {
        const ring = (scale, alpha) => {
            const points = [];
            for (let j = 0; j < n; j++)
                points.push(at(R + 2 + val(j) * reach * scale, ang(j)));
            ctx.beginPath();
            ctx.moveTo((points[n - 1][0] + points[0][0]) / 2, (points[n - 1][1] + points[0][1]) / 2);
            for (let j = 0; j < n; j++) {
                const p = points[j], q = points[(j + 1) % n];
                ctx.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2);
            }
            ctx.closePath();
            ctx.globalAlpha = alpha;
            WaveDraw.stroke(ctx, o.glow, 8, glowColor);
            if (o.fill && scale === 1) {
                ctx.globalAlpha = 0.22;
                ctx.fill();
            }
            ctx.globalAlpha = 1;
        };
        ctx.lineWidth = lw;
        ring(1, 1);
        ctx.lineWidth = 1;
        ring(0.5, 0.45);
        break;
    }
    case "dots": {
        const step = 5, r = 1.1 * Math.max(0.8, lw / 1.8);
        ctx.beginPath();
        for (let j = 0; j < n; j++) {
            const a = ang(j), length = val(j) * reach;
            for (let q = 0; q < length; q += step) {
                const p = at(R + 3 + q, a);
                ctx.moveTo(p[0] + r, p[1]);
                ctx.arc(p[0], p[1], r, 0, Math.PI * 2);
            }
            const tip = at(R + 3 + length, a);
            ctx.moveTo(tip[0] + r * 1.6, tip[1]);
            ctx.arc(tip[0], tip[1], r * 1.6, 0, Math.PI * 2);
        }
        ctx.fill();
        break;
    }
    case "ribbon": {
        ctx.save();
        ctx.globalCompositeOperation = "lighter";
        const alphas = [0.9, 0.5, 0.3];
        for (let layer = 0; layer < 3; layer++) {
            ctx.beginPath();
            for (let j = 0; j <= n; j++) {
                const jj = j % n, a = ang(jj);
                const p = at(R + 3 + val(jj) * reach * (0.55 + 0.45 * Math.sin(a * 3 + t * (1.2 + layer * 0.4) + layer * 2)), a);
                if (j)
                    ctx.lineTo(p[0], p[1]);
                else
                    ctx.moveTo(p[0], p[1]);
            }
            ctx.closePath();
            ctx.lineWidth = layer ? 1 : 2;
            ctx.globalAlpha = alphas[layer];
            WaveDraw.stroke(ctx, o.glow, 8, glowColor);
        }
        ctx.restore();
        break;
    }
    case "sparks": {
        const dots = o.particles.map(p => {
            const position = at(p.r, p.a);
            return {
                x: position[0],
                y: position[1],
                r: p.s,
                life: p.life
            };
        });
        WaveDraw.particleHalos(ctx, dots, o.glow, glowColor);
        for (const p of dots) {
            ctx.globalAlpha = p.life;
            ctx.beginPath();
            ctx.arc(p.x, p.y, p.r, 0, Math.PI * 2);
            ctx.fill();
        }
        break;
    }
    default: {
        ctx.lineWidth = Math.max(1.4, Math.min(2 * Math.PI * R / n * 0.55, lw * 1.6));
        ctx.beginPath();
        for (let j = 0; j < n; j++) {
            const a = ang(j), length = val(j) * reach + 2;
            const p0 = at(R + 3, a), p1 = at(R + 3 + length, a);
            ctx.moveTo(p0[0], p0[1]);
            ctx.lineTo(p1[0], p1[1]);
        }
        WaveDraw.stroke(ctx, o.glow, 8, glowColor);
    }
    }
    ctx.globalAlpha = 1;
}
