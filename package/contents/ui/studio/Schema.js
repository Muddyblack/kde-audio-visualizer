.pragma library
.import "StudioCatalog.js" as Catalog
.import "PresetCodec.js" as PresetCodec

// The studio settings model, ported from docs/index.html (TABS, SECTIONS,
// PRESETS). Labels and descriptions follow the HTML. Hosts pass `env`
// ("kde" or "hypr") to the `when` predicates; `s` is the current draft.

var TABS = Catalog.StudioCatalog.tabs;

var VIZ = ["Smooth Wave", "Rounded Bars", "Mirror Bars", "Tech Line", "Floating Dots", "Floating Dots Bold", "Peak Bars", "LED Meter", "Mountain", "Oscilloscope", "Ribbon", "Radial Burst", "Pixel Matrix", "Pulse Orb", "Sparkles", "Silk Ribbon"];
var PBS = ["Glassy Sleek", "Ultra Minimal", "Glowing Pulse", "Bold Pill", "Waveform", "Squiggle", "Segmented", "Dotted", "Capsule", "Time only", "Cover ring"];
var ORBITS = ["Bars", "Wave", "Dots", "Ribbon", "Sparks"];
var PALETTES = {
    aurora: ["#5ef2c1", "#4aa8ff", "#b57bff"], ember: ["#ffc36b", "#ff6a3d", "#d6246e"], ice: ["#e6f9ff", "#86d6ff", "#3a7bd5"],
    grove: ["#d8f59a", "#6fcf6f", "#1f8a70"], iris: ["#cdb8ff", "#8f6bff", "#ff7ad9"], coral: ["#ffd6b8", "#ff8a7a", "#ff4f81"]
};
var SWATCHES = ["#3daee9", "#a855f7", "#ff6fb0", "#f5b26b", "#d1e5bd", "#34d399", "#ffffff", "#1e241d"];
var BGSWATCHES = ["#0a0b10", "#1b1e21", "#231a33", "#10231d", "#2b1d14", "#f4f1ea"];
var BACKDROPS = Catalog.StudioCatalog.wallpapers.map(function (wallpaper) { return [wallpaper.id, wallpaper.label]; });
var STATES = [["normal", "Playing"], ["paused", "Paused"], ["long", "Long title"], ["nometa", "No metadata"], ["idle", "Nothing playing"], ["backend", "cava missing"]];

// Colour keys "Keep my colours" preserves; placement is never part of a look.
var COLOR_KEYS = ["useSystemAccent", "customColor", "accentFromArt", "useSystemText", "customTextColor", "useSystemControls", "customControlColor", "useSystemDockBg", "customDockBgColor", "vizColorMode", "vizPalette", "hueReactive", "bgColor", "lyricsHighlightColor", "lyricsTextStyleColor"];
var PLACEMENT_KEYS = ["monitor", "verticalPosition", "desktopLayer", "pauseWhenCovered", "hAnchor", "widgetWidth", "widgetHeight"];

function isPill(s) {
    return s.layoutMode === "pill" || s.layoutMode === "pillicon";
}
function notPill(s) {
    return !isPill(s);
}
function pct(v) {
    return Math.round(v * 100) + "%";
}
function fields(value) {
    return (Array.isArray(value) ? value : String(value || "").split(",")).map(function (v) { return String(v).trim(); }).filter(Boolean);
}
function layoutValue(s) {
    return s.showMpris === false && !isPill(s) ? "compact" : s.layoutMode;
}
function surfaceValue(s) {
    return s.artBg ? "art" : s.surfaceStyle;
}

// The HTML uses "compact" and "art" as picker values; on disk they are
// showMpris = false and artBg = true.
function normalize(patch) {
    var out = {};
    for (var key in patch)
        out[key] = patch[key];
    if (out.layoutMode === "compact") {
        delete out.layoutMode;
        out.showMpris = false;
    }
    if (out.surfaceStyle === "art") {
        delete out.surfaceStyle;
        out.artBg = true;
    }
    if (out.detailFields !== undefined)
        out.detailFields = fields(out.detailFields);
    return out;
}

function tab(id, title, rows, when) {
    return { tab: id, title: title, rows: rows, when: when };
}

var SECTIONS = [
    tab("presets", "Looks", [
        { id: "pick", type: "presets", full: true, label: "Start from a look", desc: "One click sets everything. Fine-tune in the other tabs afterwards — your placement is never touched." }
    ]),
    tab("saved", "My presets", [
        { id: "mine", type: "userPresets", full: true, label: "Saved looks", desc: "Save the current settings under a name, or share a look as a small JSON snippet." }
    ]),
    tab("viz", "Orbit around the cover", [
        { k: "orbitStyle", type: "tiles", full: true, label: "Ring style", desc: "The cover is the centre point and the visualizer circles it. Colour mode, glow and bloom below still apply.", tw: 92,
          opts: ORBITS.map(function (l) { return { v: l.toLowerCase(), label: l, pv: "orbit" }; }) },
        { k: "orbitReach", type: "range", label: "Reach", desc: "How far the ring extends from the cover.", min: .5, max: 1.3, step: .05, fmt: "pct" },
        { k: "orbitRotate", type: "switch", label: "Slow rotation" },
        { k: "orbitCoverPulse", type: "switch", label: "Cover breathes with the bass" }
    ], function (s) { return s.layoutMode === "orbit"; }),
    tab("viz", "Style", [
        { k: "visualizerType", type: "tiles", full: true, label: "Visualizer", desc: "Previews react to your colour, line and bloom settings.", tw: 104,
          when: function (s) { return s.layoutMode !== "orbit"; },
          opts: VIZ.map(function (l, i) { return { v: i, label: l, pv: "viz" }; }) },
        { k: "vizDirection", type: "seg", label: "Direction", desc: "Bars rise from the bottom today — or let them hang from the top edge.", opts: [["up", "Rise from bottom"], ["down", "Hang from top"]],
          when: function (s) { return [1, 6, 7, 8].indexOf(s.visualizerType) !== -1 && s.layoutMode !== "orbit"; } },
        { k: "ribbonCurvature", type: "range", label: "Ribbon curvature", desc: "How far the mids bend the ribbon.", min: .5, max: 1.25, step: .05, fmt: "pct", when: function (s) { return s.visualizerType === 15; } },
        { k: "ribbonFullness", type: "range", label: "Ribbon fullness", desc: "How thick the bass makes it.", min: .6, max: 1.3, step: .05, fmt: "pct", when: function (s) { return s.visualizerType === 15; } },
        { k: "lineWidth", type: "range", label: "Line weight", desc: "Stroke width of lines and dot size.", min: 1, max: 8, step: .2, fmt: "fixed1" },
        { k: "fillWave", type: "switch", label: "Gradient fill", desc: "Transparent fill under the wave and bars." }
    ]),
    tab("controls", "Progress bar", [
        { k: "progressBarStyle", type: "tiles", full: true, label: "Style", desc: "Click anywhere on it in the widget to seek.", tw: 104,
          opts: PBS.map(function (l, i) { return { v: i, label: l, pv: "progress" }; }) },
        { k: "showTimes", type: "switch", label: "Time labels", desc: "Elapsed and total time under the bar." },
        { k: "timeFormat", type: "seg", label: "Time format", opts: [["total", "1:31 · 3:58"], ["remaining", "1:31 · -2:27"]], when: function (s) { return s.showTimes || s.progressBarStyle === 9; } }
    ]),
    tab("controls", "Buttons", [
        { k: "dockStyle", type: "tiles", full: true, label: "Dock style", desc: "The glass pill is today’s look.", tw: 118,
          opts: [{ v: "glass", label: "Glass pill", pv: "dock" }, { v: "bare", label: "Bare icons", pv: "dock" }, { v: "accent", label: "Accent play", pv: "dock" }, { v: "hover", label: "On hover", pv: "dock" }] },
        { k: "showSkipButtons", type: "switch", label: "Previous & next" },
        { k: "showShuffleRepeat", type: "switch", label: "Shuffle & repeat", desc: "For players that support them." }
    ]),
    tab("layout", "Arrangement", [
        { k: "layoutMode", type: "tiles", full: true, label: "Layout", desc: "Lyrics only shows a scrollable verse with the current line highlighted. Uses online lyrics from LRCLIB.", tw: 104,
          get: layoutValue,
          set: function (v) { return v === "compact" ? { showMpris: false, layoutMode: "classic" } : { layoutMode: v, showMpris: true }; },
          opts: [["classic", "Classic"], ["mirrored", "Mirrored"], ["inline", "Inline"], ["hero", "Hero wave"], ["stacked", "Stacked"], ["orbit", "Orbit"], ["lyrics", "Lyrics only"], ["poster", "Poster"], ["strip", "Slim strip"], ["pill", "Panel pill"], ["pillicon", "Panel icon"], ["compact", "No art"]]
              .map(function (o) { return { v: o[0], label: o[1], pv: "diagram" }; }) }
    ]),
    tab("layout", "Panel pill", [
        { id: "pillNote", type: "note", full: true, note: "pill" },
        { k: "pillContent", type: "seg", label: "Text", opts: [["title", "Title"], ["title-artist", "Title · Artist"], ["artist-title", "Artist — Title"]], when: function (s) { return s.layoutMode === "pill"; } },
        { k: "pillArt", type: "switch", label: "Cover thumbnail", when: function (s) { return s.layoutMode === "pill"; } },
        { k: "pillEq", type: "seg", label: "Motion", desc: "Static bars cost no frames at all — the cleanest choice for a panel.", opts: [["off", "Off"], ["static", "Static"], ["live", "Bouncing"], ["wave", "Mini visualizer"]] },
        { k: "pillProgress", type: "seg", label: "Progress", opts: [["off", "Off"], ["underline", "Underline"], ["ring", "Cover ring"]] },
        { k: "pillControls", type: "seg", label: "Buttons", opts: [["none", "None"], ["play", "Play"], ["all", "All"]], when: function (s) { return s.layoutMode === "pill"; } },
        { k: "pillMaxWidth", type: "range", label: "Maximum width", min: 140, max: 420, step: 10, fmt: "px", when: function (s) { return s.layoutMode === "pill"; } },
        { k: "pillClick", type: "seg", label: "Click", opts: [["popup", "Open card"], ["toggle", "Play / pause"]] },
        { k: "autoPillInPanel", type: "switch", label: "Pill automatically in panels", desc: "Plasma: the desktop keeps your card layout, panels get the pill.", when: function (s, env) { return env === "kde"; } }
    ], isPill),
    tab("layout", "Poster", [
        { k: "posterAlign", type: "seg", label: "Alignment", opts: [["left", "Left"], ["center", "Centre"]] },
        { k: "posterLines", type: "seg", label: "Title lines", desc: "Let long titles wrap onto a second line.", opts: [[1, "One"], [2, "Two"]] },
        { k: "posterVizBehind", type: "switch", label: "Visualizer behind the title", desc: "A soft texture under the text; style and direction follow the Visualizer tab." },
        { k: "posterVizOpacity", type: "range", label: "Texture strength", min: .1, max: .8, step: .05, fmt: "pct", when: function (s) { return s.posterVizBehind; } },
        { k: "posterClock", type: "switch", label: "Large clock", desc: "Elapsed time set big beside the progress line." },
        { k: "showAlbum", type: "switch", label: "Album in the top line" }
    ], function (s) { return s.layoutMode === "poster"; }),
    tab("layout", "Track text", [
        { k: "titleSize", type: "range", label: "Text size", desc: "Artist and album follow the title.", min: 9, max: 16, step: 1, fmt: "px" },
        { k: "textAlign", type: "seg", label: "Alignment", opts: [["left", "Left"], ["center", "Centre"], ["right", "Right"]] },
        { k: "marquee", type: "switch", label: "Scroll long titles", desc: "Try the Long title state." }
    ], notPill),
    tab("art", "Cover", [
        { k: "showArtThumb", type: "switch", label: "Show artwork", desc: "Falls back to the player’s icon when a track has no cover.", disabled: function (s) { return layoutValue(s) === "compact"; } },
        { k: "artShape", type: "tiles", full: true, label: "Shape", desc: "Vinyl and CD spin while music plays.", tw: 84,
          opts: [["sharp", "Sharp"], ["rounded", "Rounded"], ["squircle", "Squircle"], ["circle", "Circle"], ["vinyl", "Vinyl"], ["cd", "CD"]].map(function (o) { return { v: o[0], label: o[1], pv: "shape" }; }) },
        { k: "artScale", type: "range", label: "Size", desc: "Capped by the layout height.", min: 60, max: 130, step: 5, fmt: "percent", when: notPill },
        { k: "artBorder", type: "seg", label: "Border", opts: [["none", "None"], ["subtle", "Subtle"], ["accent", "Accent"]] }
    ]),
    tab("art", "Effects", [
        { k: "artGlow", type: "switch", label: "Colour glow", desc: "A shadow tinted with the cover’s own colour." },
        { k: "artTilt", type: "switch", label: "Cover tilt on hover", desc: "A gentle tilt after hovering the cover. Click targets stay fixed; reduced motion disables it." },
        { k: "artReflect", type: "switch", label: "Reflection", desc: "A faint mirror image under the cover.", when: notPill },
        { k: "artGrayPaused", type: "switch", label: "Greyscale while paused" }
    ]),
    tab("art", "When there is no cover", [
        { k: "artFallback", type: "seg", label: "Placeholder", desc: "Try the “No metadata” state.", opts: [["icon", "Player icon"], ["gradient", "Gradient"], ["letters", "Initials"]] },
        { k: "artClick", type: "seg", label: "Clicking the cover", opts: [["none", "Nothing"], ["zoom", "Show large"], ["raise", "Open player"]] }
    ]),
    tab("info", "On the card", [
        { k: "showAlbum", type: "switch", label: "Album name", desc: "A quiet third line with album and year.", when: notPill },
        { k: "showSource", type: "switch", label: "Player name", desc: "Where the music is coming from.", when: notPill },
        { k: "showPlayerSwitch", type: "switch", label: "Player switcher", desc: "Pick which of several running players the widget follows.", when: notPill },
        { k: "showLyrics", type: "switch", label: "Synced lyrics line", desc: "Online lookup (LRCLIB). Sends title, artist, album and length. For a full verse, choose the Lyrics only layout.", when: function (s) { return s.layoutMode !== "lyrics"; } }
    ]),
    tab("lyrics", "Display", [
        { id: "lyricsMode", type: "seg", full: true, label: "Lyrics display", desc: "Online lyrics from LRCLIB. The lookup sends the song title, artist, album and length. Card backgrounds are in the Card tab.",
          get: function (s) { return s.layoutMode === "lyrics" ? "full" : s.showLyrics ? "line" : "off"; },
          set: function (v, s) { return v === "full" ? { layoutMode: "lyrics", showMpris: true, showLyrics: true } : { layoutMode: s && s.layoutMode !== "lyrics" ? s.layoutMode : "stacked", showMpris: true, showLyrics: v === "line" }; },
          opts: [["off", "Off"], ["line", "Line on card"], ["full", "Lyrics only"]] },
        { k: "lyricsOffset", type: "range", label: "Timing offset (seconds)", desc: "Positive values show lyrics earlier; negative values delay them. Applies to both lyrics displays.", min: -10, max: 10, step: .1, fmt: "fixed1" }
    ]),
    tab("lyrics", "Typography", [
        { k: "lyricsFontFamily", type: "select", label: "Font", opts: [["", "System font"], ["sans-serif", "Sans serif"], ["serif", "Serif"], ["monospace", "Monospace"]] },
        { k: "lyricsFontSize", type: "range", label: "Font size", min: 12, max: 48, step: 1, fmt: "px", when: function (s) { return s.layoutMode === "lyrics"; } },
        { k: "lyricsInlineFontSize", type: "range", label: "Card line size", min: 10, max: 24, step: 1, fmt: "px", when: function (s) { return s.layoutMode !== "lyrics"; } },
        { k: "lyricsFontWeight", when: function (s) { return s.layoutMode === "lyrics"; }, type: "select", label: "Text weight", opts: [[300, "Light"], [400, "Regular"], [500, "Medium"], [600, "Semibold"], [700, "Bold"]] },
        { k: "lyricsCurrentWeight", type: "select", label: "Current line weight", opts: [[400, "Regular"], [500, "Medium"], [600, "Semibold"], [700, "Bold"], [800, "Extra bold"]] },
        { k: "lyricsItalic", type: "switch", label: "Italic" },
        { k: "lyricsLetterSpacing", type: "range", label: "Letter spacing", min: 0, max: 4, step: .2, fmt: "fixed1" },
        { k: "lyricsLineHeight", when: function (s) { return s.layoutMode === "lyrics"; }, type: "range", label: "Wrapped line height", desc: "Spacing within a verse that wraps across multiple lines.", min: 1, max: 2, step: .05, fmt: "fixed2" },
        { k: "lyricsAlign", type: "seg", label: "Alignment", opts: [["left", "Left"], ["center", "Centre"], ["right", "Right"]] }
    ], function (s) { return s.layoutMode === "lyrics" || s.showLyrics; }),
    tab("lyrics", "Highlight and contrast", [
        { k: "lyricsHighlight", type: "seg", label: "Current line colour", opts: [["text", "Text"], ["accent", "Accent"], ["custom", "Custom"]] },
        { k: "lyricsHighlightColor", type: "color", label: "Highlight colour", swatches: SWATCHES, when: function (s) { return s.lyricsHighlight === "custom"; } },
        { k: "lyricsPastOpacity", when: function (s) { return s.layoutMode === "lyrics"; }, type: "range", label: "Past lines", min: .1, max: 1, step: .05, fmt: "pct" },
        { k: "lyricsFutureOpacity", when: function (s) { return s.layoutMode === "lyrics"; }, type: "range", label: "Upcoming lines", min: .1, max: 1, step: .05, fmt: "pct" },
        { k: "lyricsTextStyle", type: "seg", label: "Text edge", desc: "Extra contrast on busy wallpapers.", opts: [["none", "None"], ["outline", "Outline"], ["shadow", "Shadow"]] },
        { k: "lyricsTextStyleColor", type: "color", label: "Edge colour", swatches: BGSWATCHES, when: function (s) { return s.lyricsTextStyle !== "none"; } }
    ], function (s) { return s.layoutMode === "lyrics" || s.showLyrics; }),
    tab("lyrics", "Reading layout", [
        { k: "lyricsWidth", type: "range", label: "Preferred width", desc: "Desktop hosts can override the preferred size by resizing the widget.", min: 240, max: 900, step: 10, fmt: "px" },
        { k: "lyricsHeight", type: "range", label: "Preferred height", min: 180, max: 800, step: 10, fmt: "px" },
        { k: "lyricsPadding", type: "range", label: "Card padding", min: 0, max: 48, step: 2, fmt: "px" },
        { k: "lyricsMaxWidth", type: "range", label: "Maximum text width", desc: "Keep verses easy to read on a wide card.", min: 160, max: 800, step: 20, fmt: "px" },
        { k: "lyricsLineSpacing", type: "range", label: "Space between verses", min: 0, max: 40, step: 2, fmt: "px" },
        { k: "lyricsShowHeader", type: "switch", label: "Song title and artist" },
        { k: "lyricsShowScrollbar", type: "switch", label: "Show scrollbar" }
    ], function (s) { return s.layoutMode === "lyrics"; }),
    tab("lyrics", "Following playback", [
        { k: "lyricsFollow", type: "switch", label: "Follow current line", desc: "Scrolling pauses following so you can read ahead. Use the button on the card to resume." },
        { k: "lyricsFollowPosition", type: "seg", label: "Current line position", opts: [["top", "Top"], ["center", "Centre"], ["bottom", "Bottom"]] }
    ], function (s) { return s.layoutMode === "lyrics"; }),
    tab("info", "On hover", [
        { k: "hoverDetails", type: "seg", label: "Details", desc: "Tooltip and drawer appear on hover. Flip card adds an info button; click it again or press Escape to return.", opts: [["off", "Off"], ["tooltip", "Tooltip"], ["drawer", "Drawer"], ["flip", "Flip card"]] },
        { k: "detailFields", type: "chips", full: true, label: "Show", when: function (s) { return s.hoverDetails !== "off"; },
          opts: [["album", "Album & year"], ["track", "Track number"], ["genre", "Genre"], ["length", "Length"], ["format", "Audio format"], ["player", "Player"], ["volume", "Volume"]] }
    ]),
    tab("card", "Background", [
        { k: "showBg", type: "switch", label: "Show a card", desc: "Off: the widget floats directly on the wallpaper (current default)." },
        { k: "surfaceStyle", type: "tiles", full: true, label: "Material", tw: 84, when: function (s) { return s.showBg; },
          get: surfaceValue,
          set: function (v) { return v === "art" ? { artBg: true } : { artBg: false, surfaceStyle: v }; },
          opts: [["color", "Tint"], ["art", "Cover"], ["glass", "Glass"], ["liquid", "Liquid"], ["solid", "Solid"], ["atmosphere", "Atmosphere"]].map(function (o) { return { v: o[0], label: o[1], pv: "material" }; }) },
        { id: "cardNote", type: "note", full: true, note: "card", when: function (s) { return s.showBg; } },
        { k: "bgColor", type: "color", label: "Tint colour", swatches: BGSWATCHES, when: function (s) { return s.showBg && surfaceValue(s) === "color"; } },
        { k: "glassBlur", type: "range", label: "Wallpaper blur", desc: "Choose how frosted the glass looks. 0% turns blur off; text and artwork stay sharp.", min: 0, max: 1, step: .01, fmt: "pct", when: function (s) { return s.showBg && !s.artBg && ["glass", "liquid"].indexOf(s.surfaceStyle) !== -1; } },
        { k: "artBgBlur", type: "range", label: "Cover blur", desc: "0 keeps the art crisp.", min: 0, max: 1, step: .02, fmt: "pct", when: function (s) { return s.showBg && s.artBg; } },
        { k: "artBgDim", type: "range", label: "Cover darkness", desc: "Keeps text readable on bright covers.", min: 0, max: 1, step: .02, fmt: "pct", when: function (s) { return s.showBg && s.artBg; } },
        { k: "artBgKeepThumb", type: "switch", label: "Keep sharp thumbnail", when: function (s) { return s.showBg && s.artBg; }, disabled: function (s) { return !s.showArtThumb || layoutValue(s) === "compact"; } },
        { k: "artBgTransparency", type: "range", label: "Card opacity", desc: "Only the card fades; text and wave stay solid.", min: 0, max: 1, step: .02, fmt: "pct", when: function (s) { return s.showBg; } },
        { k: "bgRadius", type: "range", label: "Corner radius", min: 0, max: 30, step: 1, fmt: "px", when: function (s) { return s.showBg && notPill(s); } }
    ]),
    tab("card", "Liquid glass", [
        { k: "glassTint", type: "seg", label: "Tint", opts: [["clear", "Clear"], ["frost", "Frost"], ["cover", "Cover colour"]] },
        { k: "glassSpecular", type: "switch", label: "Light follows pointer", desc: "A soft specular highlight tracks the mouse." }
    ], function (s) { return s.showBg && surfaceValue(s) === "liquid"; }),
    tab("card", "Depth & finish", [
        { k: "cardShadow", type: "seg", label: "Shadow", opts: [["none", "None"], ["soft", "Soft"], ["lifted", "Lifted"]] },
        { k: "edgeHighlight", type: "switch", label: "Edge highlight", desc: "A thin line of light along the top edge." },
        { k: "grain", type: "switch", label: "Film grain", desc: "Stops gradients from banding." },
        { k: "bassPulse", type: "switch", label: "Bass pulse", desc: "The edge glows in the accent colour on every kick." }
    ], function (s) { return s.showBg; }),
    tab("colors", "Accent", [
        { id: "waveSrc", type: "seg", label: "Accent colour", desc: "Drives the wave, progress and play button. System follows your desktop accent.",
          opts: [["system", "System"], ["art", "From cover"], ["custom", "Custom"]],
          get: function (s) { return s.accentFromArt ? "art" : s.useSystemAccent ? "system" : "custom"; },
          set: function (v) { return { accentFromArt: v === "art", useSystemAccent: v !== "custom" }; } },
        { k: "customColor", type: "color", label: "Custom colour", swatches: SWATCHES, when: function (s) { return !s.accentFromArt && !s.useSystemAccent; } }
    ]),
    tab("colors", "Visualizer colour & light", [
        { k: "vizColorMode", type: "seg", label: "Colour mode", desc: "Solid uses the accent selected above; other modes blend or animate colours.", opts: [["solid", "Solid"], ["gradient", "Gradient"], ["cover", "Cover"], ["palette", "Palette"], ["rainbow", "Rainbow"]] },
        { k: "vizPalette", type: "tiles", full: true, label: "Palette", desc: "Curated palettes with bounded hues, so they never turn muddy.", tw: 84,
          when: function (s) { return s.vizColorMode === "palette"; },
          opts: Object.keys(PALETTES).map(function (k) { return { v: k, label: k[0].toUpperCase() + k.slice(1), pv: "palette" }; }) },
        { k: "hueReactive", type: "switch", label: "Music-reactive hue", desc: "Colours drift slowly with the bass / treble balance." },
        { k: "glowWave", type: "switch", label: "Glow", desc: "Soft light around the visualizer." },
        { k: "bloom", type: "range", label: "Bloom", desc: "How far the glow spreads.", min: 0, max: 1.5, step: .05, fmt: "pct", when: function (s) { return s.glowWave; } }
    ]),
    tab("colors", "Text & controls", [
        { id: "textSrc", type: "seg", label: "Text colour", opts: [[true, "System"], [false, "Custom"]], get: function (s) { return s.useSystemText; }, set: function (v) { return { useSystemText: v }; } },
        { k: "customTextColor", type: "color", label: "Custom text colour", swatches: SWATCHES, when: function (s) { return !s.useSystemText; } },
        { k: "autoContrast", type: "switch", label: "Adapt to light cards", desc: "Dark text and icons on the Solid material.", when: function (s) { return s.useSystemText || s.useSystemControls; } },
        { id: "ctlSrc", type: "seg", label: "Controls colour", desc: "Buttons, knob and playhead.", opts: [[true, "System"], [false, "Custom"]], get: function (s) { return s.useSystemControls; }, set: function (v) { return { useSystemControls: v }; } },
        { k: "customControlColor", type: "color", label: "Custom controls colour", swatches: SWATCHES, when: function (s) { return !s.useSystemControls; } },
        { id: "dockSrc", type: "seg", label: "Dock background", opts: [[true, "Glass"], [false, "Custom"]], get: function (s) { return s.useSystemDockBg; }, set: function (v) { return { useSystemDockBg: v }; } },
        { k: "customDockBgColor", type: "color", label: "Custom dock colour", swatches: SWATCHES, when: function (s) { return !s.useSystemDockBg; } }
    ]),
    tab("behavior", "When nothing plays", [
        { k: "alwaysVisible", type: "switch", label: "Keep visible", desc: "Off hides the widget until a player appears. Try the “Nothing playing” state." },
        { k: "idleText", type: "switch", label: "Friendly idle message", when: function (s) { return s.alwaysVisible; } },
        { k: "idleAmbient", type: "switch", label: "Ambient idle wave", desc: "A slow, quiet movement instead of a flat line.", when: function (s) { return s.alwaysVisible; } }
    ]),
    tab("behavior", "When paused", [
        { k: "dimWhenPaused", type: "switch", label: "Dim the widget" },
        { k: "fadeVizWhenPaused", type: "switch", label: "Fade the visualizer" }
    ]),
    tab("behavior", "Interaction", [
        { k: "hoverLift", type: "switch", label: "Lift on hover" },
        { k: "scrollVolume", type: "switch", label: "Scroll to change volume", desc: "Adjusts the system output volume, not the player’s own." }
    ]),
    tab("behavior", "Comfort & power", [
        { k: "reducedMotion", type: "switch", label: "Reduced motion", desc: "No ripples, sweeps, spins or scrolling text; the wave still reacts." },
        { k: "batterySaver", type: "switch", label: "Battery saver", desc: "On battery: 20 Hz and no glow." },
        { k: "simpleRender", type: "switch", label: "Simple rendering", desc: "Lightweight Canvas path — also the automatic fallback if shaders fail." }
    ]),
    tab("behavior", "Position", [
        { id: "placeNote", type: "note", full: true, note: "place" },
        { id: "anchor", type: "anchor", full: true, label: "Screen position", when: function (s, env) { return env === "hypr"; } },
        { k: "verticalPosition", type: "range", label: "Vertical position", min: 0, max: 1, step: .01, fmt: "pct", when: function (s, env) { return env === "hypr"; } },
        { k: "monitor", type: "select", label: "Monitor", opts: "screens", when: function (s, env) { return env === "hypr"; } },
        { k: "desktopLayer", type: "seg", label: "Layer", opts: [[true, "Behind windows"], [false, "Above windows"]], when: function (s, env) { return env === "hypr"; } },
        { k: "pauseWhenCovered", type: "switch", label: "Pause when covered", desc: "Stops drawing while a window hides the widget — saves real power.", when: function (s, env) { return env === "hypr" && s.desktopLayer; } },
        { k: "widgetWidth", type: "range", label: "Width", desc: "360 × 104 follows the chosen layout.", min: 160, max: 1600, step: 10, fmt: "px", when: function (s, env) { return env === "hypr"; } },
        { k: "widgetHeight", type: "range", label: "Height", min: 64, max: 600, step: 2, fmt: "px", when: function (s, env) { return env === "hypr"; } }
    ], function (s, env) { return env === "hypr"; }),
    tab("audio", "Connection", [
        { id: "diag", type: "diagnostics", full: true, label: "Status" }
    ]),
    tab("audio", "Capture", [
        { k: "inputMethod", type: "select", label: "Audio input", desc: "Auto-detect tries PipeWire, then PulseAudio, then ALSA.", opts: [["auto", "Auto-detect"], ["pipewire", "PipeWire"], ["pulse", "PulseAudio"], ["alsa", "ALSA (snd_aloop)"]] },
        { k: "numBars", type: "range", label: "Detail", desc: "More bars look finer, fewer look bolder.", min: 8, max: 128, step: 2, fmt: "bars" },
        { k: "sensitivity", type: "range", label: "Sensitivity", desc: "Raise it if quiet music barely moves the wave.", min: 10, max: 300, step: 5, fmt: "percent" },
        { k: "noiseReduction", type: "range", label: "Smoothing", desc: "Higher glides gently; lower snaps to every beat.", min: 0, max: 1, step: .05, fmt: "fixed2" },
        { k: "framerate", type: "range", label: "Frame rate", desc: "Lower saves power. 30 Hz already looks smooth.", min: 15, max: 144, step: 5, fmt: "hz" }
    ])
];

var NOTES = {
    card: {
        kde: "Glass and Liquid blur the desktop wallpaper when it is available, with tint and highlights above it. Text and artwork stay sharp. Wallpaper blur requires GPU rendering; panels and hosts without a wallpaper source keep the translucent tint.",
        hypr: "Glass and Liquid are drawn by the widget. Add a blur layer rule for the audio-wave-visualizer namespace to blur behind them — on a Bottom-layer surface this re-blurs the whole monitor on every frame, so keep the frame rate low."
    },
    pill: {
        kde: "In a panel the widget shows this pill; clicking it opens the full card as a popup.",
        hypr: "Add hyprland/PanelPill.qml to a Quickshell bar, or use run.sh --waybar for a Waybar custom module."
    },
    place: {
        kde: "Plasma places desktop widgets by dragging them in edit mode, and panel widgets inside the panel, so there is nothing to set here.",
        hypr: "Where the desktop widget sits on your screens."
    }
};

function format(kind, v) {
    switch (kind) {
    case "pct": return pct(v);
    case "px": return Math.round(v) + " px";
    case "percent": return Math.round(v) + "%";
    case "fixed1": return Number(v).toFixed(1);
    case "fixed2": return Number(v).toFixed(2);
    case "bars": return Math.round(v) + " bars";
    case "hz": return Math.round(v) + " Hz";
    default: return String(v);
    }
}

function rowValue(row, s) {
    return row.get ? row.get(s) : s[row.k];
}
function rowPatch(row, value, state) {
    if (row.set)
        return row.set(value, state);
    var patch = {};
    patch[row.k] = value;
    return patch;
}
function optionLabels(row) {
    return Array.isArray(row.opts) ? row.opts.map(function (o) { return Array.isArray(o) ? o[1] : o.label; }).join(" ") : "";
}
function searchText(row) {
    return [row.label || "", row.desc || "", row.k || "", optionLabels(row)].join(" ").toLowerCase();
}
function rowVisible(row, section, s, env, query) {
    if (section.when && !section.when(s, env))
        return false;
    if (row.when && !row.when(s, env))
        return false;
    return query === "" || searchText(row).indexOf(query) !== -1;
}

var FILTERS = [["all", "All"], ["current", "Today’s options"], ["desktop", "Desktop"], ["panel", "Panel"], ["glass", "Glass"], ["adaptive", "Adaptive colour"]];

function preset(id, cat, name, note, bd, s, env) {
    return { id: id, cat: cat, name: name, note: note, bd: bd, s: normalize(s), env: env || "" };
}

var PRESETS = [
    preset("classic", ["current", "desktop"], "Classic", "Exactly today’s defaults — nothing changes for current users.", "dusk", {}),
    preset("glass", ["desktop", "glass"], "Glass Classic", "The layout people know, on a frosted card with a soft lift.", "neon", { showBg: true, surfaceStyle: "glass", bgRadius: 16, cardShadow: "soft", edgeHighlight: true }),
    preset("liquid", ["desktop", "glass"], "Liquid Glass", "Clear glass, a light rim that follows your pointer, colour from the cover.", "sea", { layoutMode: "stacked", showBg: true, surfaceStyle: "liquid", glassTint: "clear", glassRefraction: .5, bgRadius: 28, accentFromArt: true, artShape: "squircle", artGlow: true, dockStyle: "accent", showSource: true, progressBarStyle: 8, titleSize: 12, cardShadow: "soft", visualizerType: 0, fillWave: true }),
    preset("poster", ["desktop"], "Poster", "The title set big, the music as a soft texture behind it, and a large clock.", "dusk", { layoutMode: "poster", showAlbum: true, visualizerType: 2, vizColorMode: "gradient", glowWave: false, dockStyle: "bare", progressBarStyle: 1 }),
    preset("posterhang", ["desktop"], "Poster · Hanging bars", "A centred two-line title with bars hanging from the top edge behind it.", "olive", { layoutMode: "poster", posterAlign: "center", posterLines: 2, posterClock: false, posterVizOpacity: .5, visualizerType: 1, vizDirection: "down", glowWave: false, useSystemAccent: false, customColor: "#d1e5bd", dockStyle: "bare", progressBarStyle: 6 }),
    preset("stalactite", ["desktop", "adaptive"], "Stalactites", "Peak bars hang from the top edge and drip toward the title. Ice palette.", "breeze", { layoutMode: "hero", visualizerType: 6, vizDirection: "down", vizColorMode: "palette", vizPalette: "ice", showBg: true, surfaceStyle: "glass", bgRadius: 18, cardShadow: "soft", showTimes: false, dockStyle: "bare" }),
    preset("orbit", ["desktop", "adaptive"], "Orbit", "The cover is the centre; bars circle it, rotate slowly, and the cover breathes with the bass.", "neon", { layoutMode: "orbit", orbitStyle: "bars", artShape: "circle", showBg: true, surfaceStyle: "glass", bgRadius: 28, vizColorMode: "cover", accentFromArt: true, cardShadow: "soft", edgeHighlight: true, dockStyle: "accent", progressBarStyle: 1, showTimes: false }),
    preset("halo", ["desktop", "adaptive"], "Halo", "A spinning record inside a soft ribbon halo, with a progress ring. Iris palette.", "dusk", { layoutMode: "orbit", orbitStyle: "ribbon", artShape: "vinyl", vizColorMode: "palette", vizPalette: "iris", hueReactive: true, bloom: 1.2, dockStyle: "bare", progressBarStyle: 10, showSource: true }),
    preset("sunburst", ["desktop"], "Sunburst", "Sparks fly off the cover on every beat. Ember palette on a dark tint.", "sea", { layoutMode: "orbit", orbitStyle: "sparks", artShape: "squircle", vizColorMode: "palette", vizPalette: "ember", showBg: true, bgColor: "#0a0b10", artBgTransparency: .75, bgRadius: 24, progressBarStyle: 5, showTimes: false }),
    preset("orbiticon", ["panel"], "Orbit Icon", "A tiny radial ring around the cover, living in the bar.", "breeze", { layoutMode: "pillicon", pillEq: "wave", artShape: "circle", vizColorMode: "palette", vizPalette: "aurora", hoverDetails: "tooltip" }, "hypr"),
    preset("quiet", ["desktop", "glass"], "Quiet Glass", "Title leads, calm mirror bars, one soft accent, round play button.", "olive", { layoutMode: "stacked", showBg: true, surfaceStyle: "glass", bgRadius: 22, useSystemAccent: false, customColor: "#d1e5bd", visualizerType: 2, glowWave: false, progressBarStyle: 1, dockStyle: "accent", showSource: true, showAlbum: true, cardShadow: "soft", edgeHighlight: true, titleSize: 12 }),
    preset("panelpill", ["panel"], "Panel Pill", "Clean text pill for Plasma panels. Static EQ — zero animation cost.", "breeze", { layoutMode: "pill", pillEq: "static", pillProgress: "underline", pillControls: "play", hoverDetails: "tooltip" }, "kde"),
    preset("baricon", ["panel"], "Bar Icon", "Just the cover with a progress ring, for a Hyprland bar.", "neon", { layoutMode: "pillicon", artShape: "circle", pillProgress: "ring", pillEq: "live", hoverDetails: "tooltip" }, "hypr"),
    preset("ribbonpill", ["panel", "adaptive"], "Ribbon Pill", "A glowing silk ribbon living in the panel, Aurora palette.", "dusk", { layoutMode: "pill", pillEq: "wave", visualizerType: 15, vizColorMode: "palette", vizPalette: "aurora", hueReactive: true, pillArt: false, pillContent: "title", showBg: true, surfaceStyle: "glass" }, "kde"),
    preset("ribbon", ["desktop", "adaptive"], "Silk Ribbon", "Bass thickens it, mids bend it, highs light the filaments. Ember palette.", "breeze", { layoutMode: "hero", visualizerType: 15, vizColorMode: "palette", vizPalette: "ember", hueReactive: true, bloom: 1.3, showBg: true, surfaceStyle: "color", bgColor: "#0a0b10", artBgTransparency: .7, bgRadius: 20, progressBarStyle: 1, showTimes: false, dockStyle: "bare", artShape: "circle" }),
    preset("cover", ["current", "desktop"], "Cover Art", "Album art fills the card; the sharp thumbnail stays on top.", "neon", { showBg: true, surfaceStyle: "art", artBgBlur: .44, artBgDim: .3, bgRadius: 22, artBgKeepThumb: true }),
    preset("atmos", ["desktop", "adaptive"], "Album Atmosphere", "Cover colours bleed into the card and drive the accent.", "breeze", { layoutMode: "stacked", showBg: true, surfaceStyle: "atmosphere", artShape: "circle", accentFromArt: true, bgRadius: 26, fillWave: true, dockStyle: "accent", showSource: true, cardShadow: "lifted", titleSize: 12, edgeHighlight: true, vizColorMode: "cover" }),
    preset("lyricsonly", ["desktop"], "Lyrics only", "Room to read: surrounding lines, a clear current line, and automatic scrolling. Online lyrics from LRCLIB.", "sea", { layoutMode: "lyrics", showLyrics: true, showBg: true, surfaceStyle: "color", bgColor: "#101318", artBgTransparency: .92, bgRadius: 22, titleSize: 14, showArtThumb: false, hoverDetails: "off", cardShadow: "soft" }),
    preset("lyrics", ["desktop", "adaptive"], "Lyrics Card", "Synced lyric line under the artist, Ribbon wave, cover palette.", "sea", { layoutMode: "stacked", showBg: true, surfaceStyle: "atmosphere", showLyrics: true, accentFromArt: true, visualizerType: 10, vizColorMode: "cover", bgRadius: 22, dockStyle: "accent", progressBarStyle: 5, showTimes: false, cardShadow: "soft" }),
    preset("cd", ["desktop"], "CD Player", "Spinning disc art, squiggle seek bar, flips over for track details.", "day", { layoutMode: "inline", artShape: "cd", showBg: true, surfaceStyle: "glass", bgRadius: 18, progressBarStyle: 5, hoverDetails: "flip", detailFields: "album,track,genre,format", cardShadow: "soft", dockStyle: "bare", visualizerType: 9 }),
    preset("solid", ["desktop"], "Soft Solid", "Warm mineral surface and crisp dark text. No blur needed.", "day", { layoutMode: "inline", showBg: true, surfaceStyle: "solid", bgRadius: 14, useSystemAccent: false, customColor: "#5c734c", glowWave: false, progressBarStyle: 6, dockStyle: "bare", visualizerType: 6, cardShadow: "soft", showTimes: false }),
    preset("neon", ["current", "desktop"], "Neon Night", "Dark tint, mirror bars and the glowing pulse bar.", "neon", { showBg: true, bgColor: "#0a0b10", bgRadius: 12, useSystemAccent: false, customColor: "#c084fc", visualizerType: 2, progressBarStyle: 2, artBgTransparency: .82 }),
    preset("arcade", ["desktop"], "Arcade", "LED meter with hot peaks, pixel-sharp art, time-only readout.", "breeze", { visualizerType: 7, glowWave: false, artShape: "sharp", progressBarStyle: 9, showBg: true, bgColor: "#0b0d0c", bgRadius: 4, useSystemAccent: false, customColor: "#5dff9e", artBorder: "accent", dockStyle: "bare", grain: true }),
    preset("vinyl", ["desktop", "adaptive"], "Vinyl", "A record that spins while playing, sparkles, colour from the cover.", "dusk", { layoutMode: "inline", artShape: "vinyl", showBg: true, surfaceStyle: "glass", bgRadius: 18, visualizerType: 14, accentFromArt: true, progressBarStyle: 4, showTimes: false, dockStyle: "accent", cardShadow: "soft", grain: true }),
    preset("hero", ["desktop"], "Hero Wave", "The visualizer takes the stage; track info tucks underneath.", "breeze", { layoutMode: "hero", showBg: true, surfaceStyle: "glass", bgRadius: 18, fillWave: true, lineWidth: 2.2, dockStyle: "bare", cardShadow: "soft", artShape: "squircle", showTimes: false, vizColorMode: "gradient" }),
    preset("strip", ["desktop"], "Slim Strip", "A wide, low bar for the bottom of the screen.", "dusk", { layoutMode: "strip", showBg: true, surfaceStyle: "glass", bgRadius: 23, visualizerType: 3, dockStyle: "bare", lineWidth: 1.4, artShape: "circle" }),
    preset("mirror", ["desktop"], "Mirrored Minimal", "Art on the right, dotted progress, no card, controls on hover.", "olive", { layoutMode: "mirrored", visualizerType: 12, progressBarStyle: 7, dockStyle: "hover", textAlign: "right" }),
    preset("compact", ["current", "desktop"], "Compact", "No art column — visualizer, progress and title only.", "breeze", { layoutMode: "compact", visualizerType: 4 })
];

function copy(object) {
    var out = {};
    for (var key in object)
        out[key] = object[key];
    return out;
}

// next = { ...defaults, ...preset } with placement kept and, optionally, colours.
function applyPreset(defaults, current, settings, keepColors) {
    var next = copy(defaults);
    for (var key in settings)
        next[key] = settings[key];
    if (keepColors)
        COLOR_KEYS.forEach(function (k) { if (current[k] !== undefined) next[k] = current[k]; });
    PLACEMENT_KEYS.forEach(function (k) { if (current[k] !== undefined) next[k] = current[k]; });
    return next;
}

function same(a, b) {
    if (typeof a === "number" && typeof b === "number")
        return Math.abs(a - b) < 1e-6;
    if (Array.isArray(a) || Array.isArray(b))
        return fields(a).join(",") === fields(b).join(",");
    return String(a).toLowerCase() === String(b).toLowerCase();
}

// Keys differing from the defaults (placement excluded), for user presets.
function changedKeys(defaults, current) {
    var out = {};
    for (var key in current) {
        if (key === "userPresets" || PLACEMENT_KEYS.indexOf(key) !== -1 || defaults[key] === undefined)
            continue;
        if (!same(current[key], defaults[key]))
            out[key] = current[key];
    }
    return out;
}

function matchesPreset(defaults, current, p) {
    var target = applyPreset(defaults, current, p.s, false);
    for (var key in defaults) {
        if (key === "userPresets" || PLACEMENT_KEYS.indexOf(key) !== -1)
            continue;
        if (current[key] !== undefined && !same(current[key], target[key]))
            return false;
    }
    return true;
}

function parseUserPresets(text) {
    try {
        var list = JSON.parse(text || "[]");
        return Array.isArray(list) ? list.filter(function (p) { return p && typeof p.name === "string" && p.settings; }) : [];
    } catch (e) {
        return [];
    }
}

// Accepts {"name", "settings"} or a bare key map.
function importPreset(text, known) {
    return PresetCodec.decode(text, known, false);
}

function surprise(defaults, current) {
    function pick(a) { return a[Math.floor(Math.random() * a.length)]; }
    function coin(p) { return Math.random() < p; }
    return applyPreset(defaults, current, normalize({
        layoutMode: pick(["classic", "classic", "mirrored", "inline", "hero", "stacked", "strip", "pill", "orbit", "orbit", "poster"]),
        vizDirection: pick(["up", "up", "down"]), orbitStyle: pick(["bars", "wave", "dots", "ribbon", "sparks"]),
        visualizerType: Math.floor(Math.random() * VIZ.length), progressBarStyle: Math.floor(Math.random() * PBS.length),
        showBg: coin(.8), surfaceStyle: pick(["color", "art", "glass", "liquid", "atmosphere", "solid"]), bgRadius: pick([10, 14, 18, 22, 26]),
        artShape: pick(["sharp", "rounded", "squircle", "circle", "vinyl", "cd"]), dockStyle: pick(["glass", "bare", "accent"]),
        accentFromArt: coin(.5), vizColorMode: pick(["solid", "gradient", "cover", "palette", "rainbow"]), vizPalette: pick(Object.keys(PALETTES)),
        fillWave: coin(.5), glowWave: coin(.6), cardShadow: pick(["none", "soft", "lifted"]), edgeHighlight: coin(.5), artGlow: coin(.4),
        showSource: coin(.4), showAlbum: coin(.4), hoverDetails: pick(["off", "tooltip", "flip"]), pillEq: pick(["static", "live", "wave"]), pillProgress: pick(["off", "underline", "ring"])
    }), false);
}

function exportPreset(name, settings, known) {
    return PresetCodec.encode(name, settings, known, false);
}
