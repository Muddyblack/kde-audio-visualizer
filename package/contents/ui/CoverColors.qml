import QtQuick

// Portable cover palette for hosts without Kirigami.ImageColors. Sample only
// when the cover changes; the transparent 16px Canvas never follows audio.
Canvas {
    id: sampler
    property string source: ""
    property color fallback: "#b4befe"
    property color primary: fallback
    property color secondary: fallback
    property color accent: fallback
    property bool ready: false
    property string _loadedSource: ""
    width: 16
    height: 16
    opacity: 0
    renderStrategy: Canvas.Cooperative

    function refresh() {
        ready = false;
        primary = fallback;
        secondary = fallback;
        accent = fallback;
        if (_loadedSource)
            unloadImage(_loadedSource);
        _loadedSource = source;
        if (available && source)
            loadImage(source);
    }
    onSourceChanged: refresh()
    onFallbackChanged: {
        if (!ready) {
            primary = fallback;
            secondary = fallback;
            accent = fallback;
        }
    }
    onAvailableChanged: {
        if (available)
            refresh();
    }
    onImageLoaded: {
        if (source && isImageLoaded(source))
            requestPaint();
    }
    onPaint: {
        if (!source || !isImageLoaded(source))
            return;
        const ctx = getContext("2d");
        ctx.reset();
        ctx.drawImage(source, 0, 0, 16, 16);
        const pixels = ctx.getImageData(0, 0, 16, 16).data;
        const buckets = Array.from({
            length: 12
        }, () => [0, 0, 0, 0]);
        for (let i = 0; i < pixels.length; i += 4) {
            if (pixels[i + 3] < 128)
                continue;
            const r = pixels[i] / 255, g = pixels[i + 1] / 255, b = pixels[i + 2] / 255;
            const max = Math.max(r, g, b), min = Math.min(r, g, b), delta = max - min;
            const hue = delta === 0 ? 0 : max === r ? ((g - b) / delta + 6) % 6 : max === g ? (b - r) / delta + 2 : (r - g) / delta + 4;
            const bucket = buckets[Math.min(11, Math.floor(hue * 2))];
            const weight = 0.05 + delta * Math.max(0.1, max);
            bucket[0] += r * weight;
            bucket[1] += g * weight;
            bucket[2] += b * weight;
            bucket[3] += weight;
        }
        const sorted = buckets.filter(b => b[3] > 0).sort((a, b) => b[3] - a[3]);
        if (!sorted.length)
            return;
        const first = sorted[0], second = sorted[Math.min(1, sorted.length - 1)];
        primary = Qt.rgba(first[0] / first[3], first[1] / first[3], first[2] / first[3], 1);
        secondary = Qt.rgba(second[0] / second[3], second[1] / second[3], second[2] / second[3], 1);
        accent = primary;
        ready = true;
    }
}
