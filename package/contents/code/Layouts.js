.pragma library

// Design sizes at 1× (docs/redesign-plan.md §4). `compact` is showMpris=false.
const SIZES = {
    classic: [360, 104],
    mirrored: [360, 104],
    inline: [360, 104],
    hero: [340, 138],
    stacked: [320, 200],
    strip: [460, 46],
    poster: [360, 112],
    orbit: [250, 332],
    lyrics: [380, 320],
    pillicon: [30, 30],
    compact: [200, 84]
};

// Layouts the widget can draw; other stored values fall back to Classic.
const MODES = ["classic", "mirrored", "inline", "hero", "stacked", "poster", "strip", "orbit", "lyrics", "pill", "pillicon"];

function mode(configuration) {
    const value = configuration.layoutMode || "classic";
    // The panel forms show the track regardless of showMpris.
    if (value === "pill" || value === "pillicon")
        return value;
    if (!configuration.showMpris)
        return "compact";
    return MODES.indexOf(value) === -1 ? "classic" : value;
}

function size(configuration) {
    const current = mode(configuration);
    if (current === "pill")
        return [configuration.pillMaxWidth || 300, 30];
    if (current === "lyrics")
        return [Math.max(240, Math.min(900, configuration.lyricsWidth ?? 380)), Math.max(180, Math.min(800, configuration.lyricsHeight ?? 320))];
    if (current === "poster")
        return [360, configuration.posterLines === 2 ? 138 : 112];
    return SIZES[current];
}
