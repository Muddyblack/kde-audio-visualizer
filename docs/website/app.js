'use strict';
const $ = (s, r = document) => r.querySelector(s);
const $$ = (s, r = document) => [...r.querySelectorAll(s)];

/* ─── page tab switcher ─── */
(function() {
  const pages = $$('main div[data-page]');
  const navLinks = $$('nav.jump a[data-page]');
  function showPage(id) {
    pages.forEach(p => { p.hidden = p.dataset.page !== id; });
    navLinks.forEach(a => {
      if (a.dataset.page === id) a.setAttribute('aria-current', 'page');
      else a.removeAttribute('aria-current');
    });
    window.scrollTo(0, 0);
  }
  window.showPage = showPage;
  $$('a[data-page]').forEach(a => {
    a.addEventListener('click', e => { e.preventDefault(); showPage(a.dataset.page); });
  });
})();

/* ─── config model ─────────────────────────────────────────────── */
// Mirrors package/contents/config/main.xml exactly.
const EXISTING = {
  visualizerType: 0, progressBarStyle: 0, numBars: 24, sensitivity: 100, framerate: 30, noiseReduction: 0.77,
  inputMethod: 'auto', showMpris: true, alwaysVisible: true, useSystemAccent: true, customColor: '#a855f7',
  lineWidth: 1.8, fillWave: false, showBg: false, bgColor: '#0a0b10', bgRadius: 12, glowWave: true,
  useSystemText: true, customTextColor: '#ffffff', useSystemControls: true, customControlColor: '#ffffff',
  useSystemDockBg: true, customDockBgColor: '#ffffff', artBg: false, artBgDim: 0.5, artBgBlur: 0.22,
  artBgTransparency: 1.0, showArtThumb: true, artBgKeepThumb: false,
};
// Hyprland-only keys from hyprland/AudioVisualizerShell.qml.
const HYPR = { monitor: '', verticalPosition: 0.60, desktopLayer: true, pauseWhenCovered: true };
const PROPOSED = {
  layoutMode:        { def: 'classic', type: 'String', vals: 'classic · mirrored · inline · hero · stacked · strip · orbit · poster · lyrics · pill · pillicon  (compact = showMpris off)' },
  lyricsAlign:       { def: 'left', type: 'String', vals: 'Lyrics only layout: left · center · right' },
  lyricsShowHeader:  { def: false, type: 'Bool', vals: 'Lyrics only layout: show the song title and artist above the verses' },
  lyricsWidth:       { def: 380, type: 'Int', vals: 'Lyrics only layout: preferred width; hosts can override by resizing' },
  lyricsHeight:      { def: 320, type: 'Int', vals: 'Lyrics only layout: preferred height' },
  lyricsFontSize:    { def: 22, type: 'Int', vals: 'Lyrics only layout: verse text size' },
  lyricsHighlight:   { def: 'text', type: 'String', vals: 'Current line colour: text · accent · custom' },
  lyricsHighlightColor: { def: '#3daee9', type: 'Color', vals: 'Current line colour when Highlight is custom' },
  lyricsPastOpacity: { def: 0.55, type: 'Double', vals: 'Opacity of verses already sung' },
  lyricsFutureOpacity: { def: 0.55, type: 'Double', vals: 'Opacity of verses still to come' },
  orbitStyle:        { def: 'bars', type: 'String', vals: 'Orbit layout: bars · wave · dots · ribbon · sparks around the cover' },
  orbitReach:        { def: 1.0, type: 'Double', vals: 'How far the ring reaches out (50–130 %)' },
  orbitRotate:       { def: true, type: 'Bool', vals: 'Ring slowly rotates while playing' },
  orbitCoverPulse:   { def: true, type: 'Bool', vals: 'Cover breathes with the bass' },
  vizDirection:      { def: 'up', type: 'String', vals: 'up (bars rise, today) · down (bars hang from the top edge)' },
  posterAlign:       { def: 'left', type: 'String', vals: 'Poster layout: left · center' },
  posterLines:       { def: 1, type: 'Int', vals: 'Poster layout: title lines, 1–2' },
  posterVizBehind:   { def: true, type: 'Bool', vals: 'Poster layout: visualizer as a soft texture behind the title' },
  posterVizOpacity:  { def: 0.35, type: 'Double', vals: 'Poster layout: texture strength' },
  posterClock:       { def: true, type: 'Bool', vals: 'Poster layout: large elapsed-time clock' },
  userPresets:       { def: '', type: 'String', vals: 'Saved looks as JSON: name + changed keys (placement excluded)' },
  autoPillInPanel: { def: true, type: 'Bool', vals: 'Plasma: use the pill automatically when placed in a panel (compactRepresentation)' },
  pillContent:       { def: 'title-artist', type: 'String', vals: 'title · title-artist · artist-title' },
  pillArt:           { def: true, type: 'Bool', vals: 'Cover thumbnail in the pill' },
  pillEq:            { def: 'static', type: 'String', vals: 'off · static · live — static costs no frames at all' },
  pillProgress:      { def: 'off', type: 'String', vals: 'off · underline · ring (around the cover)' },
  pillControls:      { def: 'none', type: 'String', vals: 'none · play · all' },
  pillMaxWidth:      { def: 300, type: 'Int', vals: 'Maximum pill width in px; text elides' },
  pillClick:         { def: 'popup', type: 'String', vals: 'popup (full card) · toggle (play/pause)' },
  surfaceStyle:      { def: 'color', type: 'String', vals: 'color · glass · liquid · solid · atmosphere  (album cover = artBg)' },
  glassTint:         { def: 'clear', type: 'String', vals: 'clear · frost · cover — liquid glass tint' },
  glassRefraction:   { def: 0.45, type: 'Double', vals: 'Edge refraction strength (needs wallpaper sampling / compositor)' },
  glassSpecular:     { def: true, type: 'Bool', vals: 'Specular light follows the pointer' },
  cardShadow:        { def: 'none', type: 'String', vals: 'none · soft · lifted' },
  edgeHighlight:     { def: false, type: 'Bool', vals: 'Inner top light on the card edge' },
  grain:             { def: false, type: 'Bool', vals: 'Subtle film grain on the card' },
  bassPulse:         { def: false, type: 'Bool', vals: 'Card edge glows on bass hits' },
  artShape:          { def: 'rounded', type: 'String', vals: 'sharp · rounded · squircle · circle · vinyl · cd' },
  artScale:          { def: 100, type: 'Int', vals: 'Cover size in % of the layout default (capped by height)' },
  artBorder:         { def: 'subtle', type: 'String', vals: 'none · subtle · accent' },
  artGlow:           { def: false, type: 'Bool', vals: 'Coloured shadow sampled from the cover' },
  artTilt:           { def: false, type: 'Bool', vals: '3D tilt on hover' },
  artReflect:        { def: false, type: 'Bool', vals: 'Mirror reflection under the cover' },
  artGrayPaused:     { def: false, type: 'Bool', vals: 'Desaturate the cover while paused' },
  artFallback:       { def: 'icon', type: 'String', vals: 'icon · gradient · letters — when a track has no cover' },
  artClick:          { def: 'none', type: 'String', vals: 'none · zoom (big cover) · raise (focus the player)' },
  vizColorMode:      { def: 'solid', type: 'String', vals: 'solid · gradient · cover · palette · rainbow' },
  vizPalette:        { def: 'aurora', type: 'String', vals: 'aurora · ember · ice · grove · iris · coral (curated, bounded hues)' },
  hueReactive:       { def: false, type: 'Bool', vals: 'Hue drifts slowly with the bass/treble balance' },
  bloom:             { def: 1.0, type: 'Double', vals: 'Glow strength 0–150 % (replaces on/off glow when > 0)' },
  ribbonCurvature:   { def: 1.0, type: 'Double', vals: 'Silk Ribbon: 50–125 % — mids bend the ribbon' },
  ribbonFullness:    { def: 1.0, type: 'Double', vals: 'Silk Ribbon: 60–130 % — bass thickens the ribbon' },
  reducedMotion:     { def: false, type: 'Bool', vals: 'No ripples, sweeps, spins or marquee; wave still reacts' },
  simpleRender:      { def: false, type: 'Bool', vals: 'Lightweight Canvas path instead of the shader (fallback)' },
  accentFromArt:     { def: false, type: 'Bool', vals: 'Take the accent colour from the cover' },
  autoContrast:      { def: true, type: 'Bool', vals: 'Dark text on light surfaces when using system colours' },
  dockStyle:         { def: 'glass', type: 'String', vals: 'glass · bare · accent · hover' },
  showSkipButtons:   { def: true, type: 'Bool', vals: 'Previous / next buttons' },
  showShuffleRepeat: { def: false, type: 'Bool', vals: 'Shuffle & loop buttons (MPRIS Shuffle/LoopStatus)' },
  showTimes:         { def: true, type: 'Bool', vals: 'Elapsed / total labels' },
  timeFormat:        { def: 'total', type: 'String', vals: 'total (3:58) · remaining (-2:27)' },
  titleSize:         { def: 11, type: 'Int', vals: 'Title pixel size; artist and album scale with it' },
  textAlign:         { def: 'left', type: 'String', vals: 'left · center · right' },
  showAlbum:         { def: false, type: 'Bool', vals: 'Album line (xesam:album)' },
  showSource:        { def: false, type: 'Bool', vals: 'Player name chip (MPRIS Identity)' },
  showPlayerSwitch:  { def: false, type: 'Bool', vals: 'Switch between several running players' },
  marquee:           { def: false, type: 'Bool', vals: 'Scroll long titles instead of eliding' },
  showLyrics:        { def: false, type: 'Bool', vals: 'Current synced lyric line (LRCLIB, online, opt-in)' },
  hoverDetails:      { def: 'off', type: 'String', vals: 'off · tooltip · drawer · flip' },
  detailFields:      { def: 'album,genre,format,player', type: 'StringList', vals: 'album · track · genre · length · format · player · volume' },
  idleText:          { def: false, type: 'Bool', vals: '“Nothing playing” text when no player' },
  idleAmbient:       { def: false, type: 'Bool', vals: 'Slow ambient wave while idle' },
  dimWhenPaused:     { def: false, type: 'Bool', vals: 'Fade the whole widget while paused' },
  fadeVizWhenPaused: { def: false, type: 'Bool', vals: 'Fade the visualizer line while paused' },
  hoverLift:         { def: false, type: 'Bool', vals: 'Gentle lift under the pointer' },
  scrollVolume:      { def: false, type: 'Bool', vals: 'Mouse wheel changes player volume (MPRIS Volume)' },
  batterySaver:      { def: false, type: 'Bool', vals: 'Cap to 20 Hz and drop glow while on battery' },
  hAnchor:           { def: 'center', type: 'String', vals: 'Hyprland: left · center · right (complements verticalPosition)' },
};
const DEFAULTS = { ...EXISTING, ...HYPR };
for (const [k, v] of Object.entries(PROPOSED)) DEFAULTS[k] = v.def;
const LOOK_DEFAULTS = { ...DEFAULTS };
delete DEFAULTS.showMpris; delete DEFAULTS.artBg;

const VIZ = ['Smooth Wave', 'Rounded Bars', 'Mirror Bars', 'Tech Line', 'Floating Dots', 'Floating Dots Bold',
  'Peak Bars', 'LED Meter', 'Mountain', 'Oscilloscope', 'Ribbon', 'Radial Burst', 'Pixel Matrix', 'Pulse Orb', 'Sparkles', 'Silk Ribbon'];
const PBS = ['Glassy Sleek', 'Ultra Minimal', 'Glowing Pulse', 'Bold Pill', 'Waveform',
  'Squiggle', 'Segmented', 'Dotted', 'Capsule', 'Time only', 'Cover ring'];
const PILLS = ['pill', 'pillicon'];
const isPill = s => PILLS.includes(s.layoutMode);
const SIZES = { classic: [360, 104], mirrored: [360, 104], inline: [360, 104], hero: [340, 138], stacked: [320, 200], strip: [460, 46], orbit: [250, 332], poster: [360, 112], lyrics: [380, 320], compact: [200, 84] };
const ORBITS = ['Bars', 'Wave', 'Dots', 'Ribbon', 'Sparks'];
const sizeOf = s => s.layoutMode === 'pill' ? [s.pillMaxWidth, 30] : s.layoutMode === 'pillicon' ? [40, 30]
  : s.layoutMode === 'poster' ? [360, s.posterLines === 2 ? 138 : 112]
  : s.layoutMode === 'lyrics' ? [s.lyricsWidth, s.lyricsHeight] : SIZES[s.layoutMode];

/* ─── sample music ─────────────────────────────────────────────── */
// Single-quoted and fully escaped: the value is written into inline style="" attributes.
const svgUrl = s => `url('data:image/svg+xml,${encodeURIComponent(s).replace(/'/g, '%27')}')`;
const TRACKS = [
  { title: 'A Little Further', artist: 'Northbound', album: 'Open Horizons', year: 2026, len: 238, app: 'Spotify', genre: 'Indie folk', no: 3, of: 11, format: 'Ogg Vorbis · 320 kbps',
    lyrics: ['Take the long road home tonight', 'where the hills forget the light', 'just a little further now', 'I can hear the morning somehow'],
    pal: { accent: '#bfdc9f', p1: '#c9c48a', p2: '#4d6a58', p3: '#17271f' },
    svg: `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><defs><linearGradient id='g' x1='0' y1='0' x2='.6' y2='1'><stop offset='0' stop-color='#f1e6bd'/><stop offset='.5' stop-color='#8fa78c'/><stop offset='1' stop-color='#1d332c'/></linearGradient></defs><rect width='100' height='100' fill='url(#g)'/><circle cx='66' cy='32' r='11' fill='#fbf3d5' opacity='.9'/><path d='M0 66Q28 48 58 62T100 56V100H0Z' fill='#4f6b57'/><path d='M0 80Q42 62 100 78V100H0Z' fill='#1a2f27'/><text x='8' y='14' font-size='6' fill='#fff' letter-spacing='1.5' font-family='sans-serif'>OPEN HORIZONS</text></svg>` },
  { title: 'Neon Hours', artist: 'Velvet Static', album: 'Afterglow City', year: 2025, len: 204, app: 'Tidal', genre: 'Synthwave', no: 1, of: 9, format: 'FLAC · 44.1 kHz · 16-bit',
    lyrics: ['City lights in violet rain', 'every signal calls your name', 'we were neon, we were gold', 'running hot and never old'],
    pal: { accent: '#ff6fb0', p1: '#ff3d8b', p2: '#5b2cff', p3: '#140b30' },
    svg: `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><defs><radialGradient id='g' cx='.3' cy='.3' r='.9'><stop offset='0' stop-color='#ff4f9a'/><stop offset='.45' stop-color='#6a2cff'/><stop offset='1' stop-color='#120a2c'/></radialGradient></defs><rect width='100' height='100' fill='url(#g)'/><g fill='none' stroke='#fff' stroke-opacity='.45'><circle cx='30' cy='32' r='10'/><circle cx='30' cy='32' r='22' stroke-opacity='.25'/><circle cx='30' cy='32' r='36' stroke-opacity='.12'/></g><g stroke='#ff9fd0' stroke-opacity='.5'><path d='M0 74H100M0 84H100M0 94H100'/><path d='M50 64L20 100M50 64L80 100M50 64V100' stroke-opacity='.3'/></g></svg>` },
  { title: 'After the Rain', artist: 'Lumen Coast', album: 'Tidewater', year: 2026, len: 262, app: 'Elisa', genre: 'Ambient pop', no: 7, of: 12, format: 'FLAC · 96 kHz · 24-bit',
    lyrics: ['Salt on the window, sun on the sea', 'the storm took the noise away from me', 'after the rain there is only the tide', 'and everything quiet we held inside'],
    pal: { accent: '#f5b26b', p1: '#f2a65a', p2: '#1f6f78', p3: '#0b2328' },
    svg: `<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 100 100'><defs><linearGradient id='g' x1='0' y1='0' x2='0' y2='1'><stop offset='0' stop-color='#f7c57e'/><stop offset='.5' stop-color='#e0775a'/><stop offset='.51' stop-color='#1f6f78'/><stop offset='1' stop-color='#0b2c33'/></linearGradient></defs><rect width='100' height='100' fill='url(#g)'/><circle cx='50' cy='50' r='16' fill='#ffe0a6'/><rect y='50' width='100' height='50' fill='#1f6f78' opacity='.9'/><g stroke='#ffd9a0' stroke-opacity='.55' stroke-linecap='round'><path d='M38 58h24M32 66h36M40 74h20M30 82h14M56 82h14'/></g></svg>` },
];
TRACKS.forEach(t => t.cover = svgUrl(t.svg));
const LONG = { title: 'Everything We Said Before the Summer Ended (Extended Night Version)', artist: 'Northbound feat. Ada Lin' };
const ALT_PLAYERS = ['Firefox', 'mpv'];

const P = { track: 0, pos: 91, playing: true, sysAccent: '#3daee9', volume: .62, alt: 0, shuffle: false, repeat: false };

/* ─── widget renderer ──────────────────────────────────────────── */
const ICONS = {
  prev: '<path d="M19 4 5 12l14 8z"/>', next: '<path d="m5 4 14 8-14 8z"/>', play: '<path d="m6 3 15 9-15 9z"/>',
  pause: '<path d="M5 3h5v18H5zM14 3h5v18h-5z"/>',
  shuffle: '<path d="M16 3h5v5l-1.8-1.8-4.4 4.4-1.4-1.4 4.4-4.4zM3 5.4 4.4 4 20 19.6 18.6 21zM13.4 14.8l1.4-1.4 4.4 4.4L21 16v5h-5l1.8-1.8z"/>',
  repeat: '<path d="M7 7h11V4l4 4-4 4V9H7v4H5V9a2 2 0 0 1 2-2zm10 10H6v3l-4-4 4-4v3h11v-4h2v4a2 2 0 0 1-2 2z"/>',
  note: '<path d="M12 3v10.6A4 4 0 1 0 14 17V7h4V3z"/>',
};
const icon = n => `<svg viewBox="0 0 24 24" aria-hidden="true">${ICONS[n]}</svg>`;
const fmtTime = s => `${Math.floor(s / 60)}:${String(Math.floor(s % 60)).padStart(2, '0')}`;
const esc = s => String(s).replace(/[&<>"]/g, c => ({ '&': '&amp;', '<': '&lt;', '>': '&gt;', '"': '&quot;' }[c]));
const hashHue = s => { let h = 0; for (const c of s) h = (h * 31 + c.charCodeAt(0)) % 360; return h; };
const initials = s => s.split(/\s+/).filter(Boolean).slice(0, 2).map(w => w[0].toUpperCase()).join('');
const appName = d => P.alt ? ALT_PLAYERS[P.alt - 1] : d.t.app;
const lyricIndexAt = t => Math.floor(P.pos / 5) % t.lyrics.length;
const lyricAt = t => t.lyrics[lyricIndexAt(t)];

function derive(s, status) {
  const t = TRACKS[P.track];
  const hasPlayer = status !== 'idle';
  const playing = hasPlayer && (status === 'demo' || (status !== 'paused' && P.playing));
  const surf = s.showBg ? s.surfaceStyle : 'none';
  const light = surf === 'solid';
  const ink = '#1e241d';
  const accent = s.accentFromArt ? t.pal.accent : s.useSystemAccent ? P.sysAccent : s.customColor;
  const text = s.useSystemText ? (light && s.autoContrast ? ink : '#eff0f1') : s.customTextColor;
  const control = s.useSystemControls ? (light && s.autoContrast ? ink : '#ffffff') : s.customControlColor;
  const dock = s.useSystemDockBg ? (light ? '#2a33241a' : '#00000047') : `color-mix(in srgb,${s.customDockBgColor} 55%,transparent)`;
  const pg1 = s.useSystemControls ? accent : control;
  const pg2 = s.useSystemControls ? (light ? accent : '#ffffff') : control;
  return { t, hasPlayer, playing, surf, light, accent, text, control, dock, pg1, pg2 };
}
const colorVars = d => `--accent:${d.accent};--text:${d.text};--control:${d.control};--dock:${d.dock};--pg1:${d.pg1};--pg2:${d.pg2};`;

function artHTML(s, d, size, o) {
  const shape = s.artShape, cls = ['art', shape, 'b-' + s.artBorder];
  if (!o.coverOK) cls.push('empty', 'fb-' + s.artFallback);
  if ((shape === 'vinyl' || shape === 'cd') && d.playing && o.coverOK) cls.push('spin');
  if (s.artGlow && o.coverOK) cls.push('glow');
  if (s.artTilt) cls.push('tilt');
  if (s.artReflect && !o.small) cls.push('reflect');
  if (s.artGrayPaused && d.hasPlayer && !d.playing) cls.push('gray');
  if (s.artClick === 'zoom' && o.coverOK) cls.push('zoomable');
  let inner = '';
  if (!o.coverOK) inner = s.artFallback === 'letters' && o.title ? `<b>${esc(initials(o.title))}</b>` : s.artFallback === 'gradient' && o.title ? '' : icon('note');
  const act = s.artClick !== 'none' && o.coverOK && !o.small ? 'data-act="art"' : '';
  const art = `<div class="${cls.join(' ')}" ${act} style="--a:${size}px;--fh:${hashHue(o.title || 'x')}">${inner}</div>`;
  if (!o.ring) return art;
  const wr = ['circle', 'vinyl', 'cd'].includes(shape) ? 'round' : shape === 'squircle' ? 'sq' : '';
  return `<div class="artwrap ${wr}" style="--a:${size}px">${art}<i class="rg"></i></div>`;
}
function dockHTML(s, playing) {
  const b = (n, cls = '') => `<button class="${cls}" data-act="${n}" aria-label="${n}">${icon(n)}</button>`;
  return `<div class="dock ${s.dockStyle}">${s.showShuffleRepeat ? b('shuffle', 'xs' + (P.shuffle ? ' on' : '')) : ''}${s.showSkipButtons ? b('prev') : ''}<button class="play" data-act="play" aria-label="${playing ? 'Pause' : 'Play'}">${icon(playing ? 'pause' : 'play')}</button>${s.showSkipButtons ? b('next') : ''}${s.showShuffleRepeat ? b('repeat', 'xs' + (P.repeat ? ' on' : '')) : ''}</div>`;
}
function pbHTML(style, o, on, len, fixed) {
  const rem = o.timeFormat === 'remaining';
  const el = fixed == null ? fmtTime(P.pos) : '1:31';
  const tot = rem ? '-' + fmtTime(len - (fixed == null ? P.pos : 91)) : fmtTime(len);
  return `<div class="pb pb${style} ${o.showTimes ? '' : 'notimes'} ${on ? 'on' : ''} ${o.textAlign === 'center' ? 'center' : ''}" data-act="seek" ${fixed != null ? `style="--p:${fixed}"` : ''}><div class="track"><div class="fill"><i class="sweep"></i></div><i class="knob"></i></div><canvas data-c="seek"></canvas><div class="times"><span ${fixed == null ? 'data-el' : ''}>${el}</span><span ${fixed == null && rem ? 'data-rem' : ''}>${tot}</span></div></div>`;
}
function detailRows(s, d) {
  const t = d.t, map = {
    album: ['Album', `${esc(t.album)} (${t.year})`], track: ['Track', `${t.no} of ${t.of}`], genre: ['Genre', t.genre],
    length: ['Length', fmtTime(t.len)], format: ['Format', t.format], player: ['Player', appName(d)],
    volume: ['Volume', `<span class="vb" style="--v:${P.volume}"><i></i></span>`],
  };
  return s.detailFields.split(',').filter(k => map[k]).map(k => `<dt>${map[k][0]}</dt><dd>${map[k][1]}</dd>`).join('');
}
function surfHTML(s, cls, fill) {
  const liquid = cls === 'liquid';
  const extra = liquid ? ` t-${s.glassTint}${s.glassRefraction > .02 ? ' refract' : ''}` : '';
  return `<div class="surf s-${cls}${extra}" style="opacity:${s.artBgTransparency};--bgc:${fill};--blur:${(s.artBgBlur * 24).toFixed(1)}px;--dim:${s.artBgDim}">${cls === 'art' ? '<i class="cover"></i><i class="scrim"></i>' : ''}${liquid ? '<i class="spec"></i>' : ''}<i class="edge ${s.edgeHighlight ? 'hl' : ''}"></i>${s.grain ? '<i class="grain"></i>' : ''}</div>`;
}

// opt: { noHover, hcAbove }
function widgetHTML(s, status, opt = {}) {
  const d = derive(s, status);
  const mode = s.layoutMode;
  const [W, H] = sizeOf(s);
  const bg = d.surf !== 'none';
  const pill = isPill(s);
  const radius = pill ? H / 2 : s.bgRadius;
  const base = `--W:${W}px;--H:${H}px;--r:${radius}px;`;
  if (status === 'idle' && !s.alwaysVisible)
    return `<div class="w" style="${base}${pill ? 'width:120px' : ''}"><div class="ghostw">${pill ? 'Hidden' : 'Hidden while nothing plays<br>(“Keep visible” is off)'}</div></div>`;

  let title = d.t.title, artist = d.t.artist, tcls = '', acls = '';
  if (status === 'long') ({ title, artist } = LONG);
  if (status === 'nometa') { title = 'No track metadata'; artist = 'Direct YouTube stream'; tcls = 'unknown'; acls = 'hint'; }
  if (status === 'idle') { title = s.idleText ? 'Nothing playing' : ''; artist = s.idleText ? 'Start music in any player' : ''; tcls = 'idle'; }
  const coverOK = status !== 'nometa' && status !== 'idle';
  const surfCls = d.surf === 'art' && !coverOK ? 'color' : d.surf;
  const artIsBg = d.surf === 'art' && coverOK;
  const fill = d.hasPlayer ? s.bgColor : '#ffffff0f';
  const surf = bg ? surfHTML(s, surfCls, fill) + (s.bassPulse ? '<i class="bglow"></i>' : '') : '';
  const hoverMode = opt.noHover || !d.hasPlayer || status === 'nometa' ? 'off' : s.hoverDetails;
  const hc = hoverMode === 'tooltip' || hoverMode === 'drawer' || (hoverMode === 'flip' && (pill || mode === 'strip'))
    ? `<div class="hc ${hoverMode === 'drawer' ? 'drawer' : ''} ${opt.hcAbove ? 'above' : ''}"><div class="hc-head">${artHTML(s, d, 40, { coverOK, title, small: true })}<div><b>${esc(title)}</b><span>${esc(artist)}</span></div></div><dl>${detailRows(s, d)}</dl>${s.showLyrics ? `<div class="ly" data-ly style="margin-top:8px;font-size:10.5px">${esc(lyricAt(d.t))}</div>` : ''}</div>` : '';
  const vol = s.scrollVolume ? `<div class="vol" data-vol><i style="--v:${P.volume}"></i></div>` : '';
  const cls = ['w', `L-${mode}`, bg && s.cardShadow !== 'none' ? `sh-${s.cardShadow}` : '', s.hoverLift ? 'lift' : '',
    s.dimWhenPaused && d.hasPlayer && !d.playing ? 'dim' : '', pill && !bg ? 'nobg' : '', s.bassPulse || (mode === 'orbit' && s.orbitCoverPulse) ? 'bass' : '',
    s.surfaceStyle === 'liquid' && s.glassSpecular ? 'specular' : ''];
  const vars = `${base}${colorVars(d)}--ts:${s.titleSize}px;--cover:${coverOK ? d.t.cover : 'none'};--p1:${d.t.pal.p1};--p2:${d.t.pal.p2};--p3:${d.t.pal.p3}`;

  /* ── panel pill ── */
  if (pill) {
    const ring = s.pillProgress === 'ring' && d.hasPlayer;
    const eq = s.pillEq === 'off' || !d.hasPlayer ? '' : s.pillEq === 'wave' ? `<span style="position:relative;width:${mode === 'pillicon' ? 0 : 64}px;height:20px;flex-shrink:0"><canvas data-c="wave" style="position:absolute;inset:0;width:100%;height:100%"></canvas></span>` : `<span class="eq ${s.pillEq === 'live' && d.playing ? 'live' : ''} ${d.playing ? '' : 'paused'}"><i></i><i></i><i></i><i></i></span>`;
    let body;
    if (mode === 'pillicon' && s.pillEq === 'wave') {
      body = `<div class="picon"><canvas data-c="orbit" data-r=".45"></canvas>${artHTML(s, d, 18, { coverOK, title, ring, small: true })}</div>`;
    } else if (mode === 'pillicon') {
      body = `<div style="position:relative;display:flex">${artHTML(s, d, 22, { coverOK, title, ring, small: true })}${eq}</div>`;
    } else {
      const t1 = title || 'No media', a1 = artist;
      const parts = s.pillContent === 'title' || !a1 ? `<span class="pt">${esc(t1)}</span>`
        : s.pillContent === 'artist-title' ? `<span class="pt">${esc(a1)}</span><span class="psep">—</span><span class="pa">${esc(t1)}</span>`
        : `<span class="pt">${esc(t1)}</span><span class="psep">·</span><span class="pa">${esc(a1)}</span>`;
      const b = n => `<button data-act="${n}" aria-label="${n}">${icon(n)}</button>`;
      const ctl = !d.hasPlayer || s.pillControls === 'none' ? '' : `<span class="pctl">${s.pillControls === 'all' ? b('prev') : ''}${b(d.playing ? 'pause' : 'play').replace('data-act="pause"', 'data-act="play"')}${s.pillControls === 'all' ? b('next') : ''}</span>`;
      body = `${s.pillArt ? artHTML(s, d, 20, { coverOK, title, ring, small: true }) : ''}${eq}<span class="ptxt ${tcls}">${parts}</span>${ctl}`;
    }
    const line = s.pillProgress === 'underline' && d.hasPlayer ? '<i class="pline"><i></i></i>' : '';
    return `<div class="${cls.join(' ')}" style="${vars};--pad:0"><div class="face">${surf}</div><div class="L" data-act="pill">${body}</div>${line}${hc}${vol}</div>`;
  }

  /* ── cards ── */
  const ringMode = s.progressBarStyle === 10;
  const showArt = mode !== 'compact' && mode !== 'poster' && s.showArtThumb && (!artIsBg || s.artBgKeepThumb);
  const pbStyle = ringMode && !showArt ? 0 : s.progressBarStyle;
  const art = size => showArt ? artHTML(s, d, Math.round(size), { coverOK, title, ring: ringMode && d.hasPlayer }) : '';
  const scaled = (def, cap) => Math.min(cap, def * s.artScale / 100);
  const dock = () => d.hasPlayer ? dockHTML(s, d.playing) : '';
  const faded = s.fadeVizWhenPaused && d.hasPlayer && !d.playing;
  const wave = `<div class="wavebox ${faded ? 'faded' : ''} ${[1, 6, 7, 8].includes(s.visualizerType) && s.vizDirection === 'down' ? 'dir-down' : ''}"><canvas data-c="wave"></canvas>${status === 'backend' ? '<div class="bmsg"><span>cava is not installed</span><code>sudo pacman -S cava</code></div>' : ''}</div>`;
  const pb = d.hasPlayer && !(ringMode && showArt) ? pbHTML(pbStyle, s, d.playing, d.t.len) : '';
  const marq = s.marquee && title.length > 26;
  const titleInner = marq ? `<span class="mi"><span>${esc(title)}</span><span>${esc(title)}</span></span>` : esc(title);
  const srcOn = (s.showSource || s.showPlayerSwitch) && d.hasPlayer;
  const src = srcOn ? `<div class="src"><i></i>${status === 'nometa' ? 'Firefox' : appName(d)}${s.showPlayerSwitch ? '<button data-act="player" title="Switch player">3 ▾</button>' : ''}</div>` : '';
  const texts = `<div class="texts ${s.textAlign}">${src}<div class="tt ${tcls} ${marq ? 'marq' : ''}" title="${esc(title)}">${titleInner || '&nbsp;'}</div><div class="ta ${acls}">${esc(artist) || '&nbsp;'}</div>${s.showAlbum && coverOK ? `<div class="tal">${esc(d.t.album)} · ${d.t.year}</div>` : ''}${s.showLyrics && coverOK ? `<div class="ly" data-ly>${esc(lyricAt(d.t))}</div>` : ''}</div>`;

  let pad, body;
  switch (mode) {
    case 'classic': case 'mirrored': {
      pad = bg ? '4px 10px 0' : '0';
      const a = scaled(72, Math.min(72, H - (bg ? 4 : 0) - (d.hasPlayer ? 30 : 0)) - (ringMode ? 6 : 0));
      const col = `<div class="artcol">${showArt ? art(a) : '<i class="g2"></i>'}${dock()}${showArt ? '' : '<i class="g1"></i>'}</div>`;
      body = `<div class="L ${mode === 'mirrored' ? 'rev' : ''}">${col}<div class="maincol">${wave}${pb}${texts}</div></div>`;
      break;
    }
    case 'inline': {
      pad = bg ? '8px 12px 6px 8px' : '0';
      const a = scaled(H - (bg ? 16 : 8), H - (bg ? 14 : 4)) - (ringMode ? 8 : 0);
      body = `<div class="L">${showArt ? `<div class="artcol">${art(a)}</div>` : ''}<div class="maincol">${texts}${wave}<div class="pbrow">${pb}${dock()}</div></div></div>`;
      break;
    }
    case 'hero':
      pad = bg ? '12px 14px 10px' : '0';
      body = `<div class="L col" style="gap:6px">${wave}${pb}<div class="mid">${art(scaled(34, 44))}${texts}${dock()}</div></div>`;
      break;
    case 'stacked':
      pad = bg ? '18px 20px 14px' : '4px';
      body = `<div class="L col" style="gap:10px"><div class="top">${art(scaled(64, 84))}${texts}</div>${wave}<div>${pb}<div class="center" style="margin-top:4px">${dock()}</div></div></div>`;
      break;
    case 'poster': {
      pad = bg ? '12px 16px 10px' : '4px 2px';
      const meta = [artist, s.showAlbum && coverOK ? d.t.album : ''].filter(Boolean).map(esc).join(' · ');
      const viz = s.posterVizBehind ? wave.replace('class="wavebox', 'class="wavebox po-viz') : '';
      const clock = s.posterClock && d.hasPlayer ? `<span class="po-clock" data-el>${fmtTime(P.pos)}</span>` : '';
      const pbP = d.hasPlayer ? pbHTML(pbStyle, { ...s, showTimes: s.posterClock ? false : s.showTimes }, d.playing, d.t.len) : '';
      body = `<div class="L col po ${s.posterAlign === 'center' ? 'center' : ''}" style="--pvo:${s.posterVizOpacity};--pl:${s.posterLines}">${viz}<div class="po-meta ${acls}"><i></i>${meta || '&nbsp;'}</div><div class="po-title ${tcls}" title="${esc(title)}">${esc(title) || '&nbsp;'}</div><div class="po-foot">${pbP}${clock}${dock()}</div></div>`;
      break;
    }
    case 'orbit': {
      pad = bg ? '14px 16px 12px' : '4px';
      const box = W - (bg ? 60 : 28);
      const a = Math.round(Math.min(box * .56, box * .38 * s.artScale / 100)) - (ringMode ? 8 : 0);
      body = `<div class="L col" style="gap:8px"><div class="orbit ${s.orbitCoverPulse ? 'pulse' : ''}" style="width:${box}px;height:${box}px"><canvas data-c="orbit" data-r="${((a + (ringMode ? 8 : 0)) / box).toFixed(3)}"></canvas>${showArt ? art(a) : ''}</div>${texts}<div class="pbx">${pb}</div>${dock()}</div>`;
      break;
    }
    case 'strip':
      pad = bg ? '6px 8px 6px 6px' : '2px';
      body = `<div class="L">${art(H - (bg ? 12 : 4) - (ringMode ? 6 : 0))}${texts}${wave}${dock()}</div>`;
      break;
    case 'lyrics': {
      pad = bg ? '18px 20px' : '10px';
      const idx = lyricIndexAt(d.t);
      const nowColor = s.lyricsHighlight === 'accent' ? 'var(--accent)' : s.lyricsHighlight === 'custom' ? s.lyricsHighlightColor : 'currentColor';
      const head = s.lyricsShowHeader ? `<div class="lyr-head">${esc([title, artist].filter(Boolean).join(' · ')) || '&nbsp;'}</div>` : '';
      const verses = d.t.lyrics.map((line, i) => `<div class="lyr-line ${i === idx ? 'now' : i < idx ? 'past' : 'future'}" data-i="${i}">${esc(line)}</div>`).join('');
      body = `<div class="lyr-wrap ${s.lyricsAlign}" style="--lyr-size:${s.lyricsFontSize}px;--lyr-now-c:${nowColor};--lyr-past:${s.lyricsPastOpacity};--lyr-future:${s.lyricsFutureOpacity}">${head}<div class="lyr-scroll">${verses}</div></div>`;
      break;
    }
    default:
      pad = bg ? '4px 10px 0' : '0';
      body = `<div class="L col" style="gap:0">${wave}${pb}${texts}</div>`;
  }
  const front = `<div class="face front">${surf}${body}</div>`;
  if (hoverMode === 'flip' && mode !== 'strip') {
    const back = `<div class="face back">${surfHTML(s, bg && surfCls !== 'art' ? surfCls : 'glass', fill)}<div class="bk">${artHTML(s, d, Math.min(62, H - 22), { coverOK, title, small: true })}<dl><div class="bt">${esc(title)}</div>${detailRows(s, d)}</dl></div></div>`;
    return `<div class="${cls.join(' ')} flip" style="${vars};--pad:${pad}"><div class="flipin">${front}${back}</div>${vol}</div>`;
  }
  return `<div class="${cls.join(' ')}" style="${vars};--pad:${pad}">${front}${hc}${vol}</div>`;
}

// Pills live inside a mock panel: a floating Plasma panel or a Hyprland (waybar-style) bar.
function panelHTML(inner, env, popupHTML, width) {
  const mh = env === 'kde' ? 44 : 36;
  const pop = popupHTML ? `<div class="popup">${popupHTML}</div>` : '';
  const slot = `<div class="slot">${inner}${pop}</div>`;
  const clock = env === 'kde' ? '<div class="pm-clock">16:42<small>Tue 15 Sep</small></div>' : '<div class="pm-clock"> 16:42</div>';
  const tray = '<div class="pm-tray"><i></i><i style="border-radius:50%"></i><i></i></div>';
  const body = env === 'kde'
    ? `<div class="pm-ico"><i style="background:radial-gradient(circle,#fff 0 22%,#3daee9 24%);border-radius:50%"></i></div><div class="pm-ico act"><i style="background:linear-gradient(135deg,#ff9a3d,#e4572e)"></i></div><div class="pm-ico"><i style="background:linear-gradient(135deg,#5bd08b,#1f8f57)"></i></div><div class="pm-ico"><i style="background:linear-gradient(135deg,#8f9bff,#4a50c9)"></i></div><div class="pm-sp"></div>${slot}${tray}${clock}`
    : `<div class="pm-ws"><i></i><i class="on"></i><i></i><i></i></div><div class="pm-sp"></div>${slot}<div class="pm-sp"></div>${tray}${clock}`;
  return { html: `<div class="pmock pm-${env}" style="height:${mh}px;width:${width}px">${body}</div>`, mh };
}
const popupState = s => ({ ...s, layoutMode: 'classic', showBg: true, surfaceStyle: s.showBg ? s.surfaceStyle : 'glass', bgRadius: Math.max(14, s.bgRadius), cardShadow: 'lifted', hoverDetails: 'off' });

/* ─── colour helpers & fake audio analysis ─────────────────────── */
function hexRgb(hex) {
  const h = hex.replace('#', '');
  const n = parseInt(h.length === 3 ? h.split('').map(c => c + c).join('') : h.slice(0, 6), 16);
  return [n >> 16 & 255, n >> 8 & 255, n & 255];
}
const hexRgba = (hex, a) => { const [r, g, b] = hexRgb(hex); return `rgba(${r},${g},${b},${a})`; };
function hexHsl(hex) {
  let [r, g, b] = hexRgb(hex).map(v => v / 255);
  const mx = Math.max(r, g, b), mn = Math.min(r, g, b), l = (mx + mn) / 2;
  if (mx === mn) return [0, 0, l * 100];
  const dd = mx - mn, s = l > .5 ? dd / (2 - mx - mn) : dd / (mx + mn);
  const h = mx === r ? (g - b) / dd + (g < b ? 6 : 0) : mx === g ? (b - r) / dd + 2 : (r - g) / dd + 4;
  return [h * 60, s * 100, l * 100];
}
const shiftHue = (hex, deg, a = 1) => { const [h, s, l] = hexHsl(hex); return `hsla(${(h + deg + 360) % 360},${s}%,${l}%,${a})`; };
const PALETTES = {
  aurora: ['#5ef2c1', '#4aa8ff', '#b57bff'], ember: ['#ffc36b', '#ff6a3d', '#d6246e'], ice: ['#e6f9ff', '#86d6ff', '#3a7bd5'],
  grove: ['#d8f59a', '#6fcf6f', '#1f8a70'], iris: ['#cdb8ff', '#8f6bff', '#ff7ad9'], coral: ['#ffd6b8', '#ff8a7a', '#ff4f81'],
};
function bands(t) {
  const bass = Math.pow(.5 + .5 * Math.sin(t * 7.4), 7);
  return { bass, mid: .5 + .5 * Math.sin(t * 1.3), high: .5 + .5 * Math.sin(t * 5.1 + 1), attack: bass > .86 };
}
function spectrum(i, n, t) {
  const p = n > 1 ? i / (n - 1) : .5;
  const env = Math.pow(Math.sin(p * Math.PI), .85);
  const beat = Math.pow(.5 + .5 * Math.sin(t * 7.4), 7);
  const a = .5 + .5 * Math.sin(t * 2.3 + i * .61 + Math.sin(t * .7 + i * .13) * 2);
  const b = .5 + .5 * Math.sin(t * 3.9 - i * .37);
  return env * (.16 + .58 * a * b + .34 * beat * env);
}
// Colour stops for the chosen colour mode; hueReactive drifts them with the "music".
function colorStops(s, d, t) {
  const drift = s.hueReactive ? Math.sin(t * .15) * 20 + (bands(t).high - .5) * 14 : 0;
  const tint = arr => arr.map(c => drift ? shiftHue(c, drift) : c);
  switch (s.vizColorMode) {
    case 'gradient': return tint([d.accent, shiftHue(d.accent, 55)]);
    case 'cover': return tint([d.t.pal.p1, d.accent, d.t.pal.p2]);
    case 'palette': return tint(PALETTES[s.vizPalette] || PALETTES.aurora);
    case 'rainbow': return [0, 60, 120, 180, 240, 300].map(h => `hsl(${(h + t * 24) % 360},85%,65%)`);
    default: return [drift ? shiftHue(d.accent, drift) : d.accent];
  }
}
function paintFor(ctx, stops, w) {
  if (stops.length === 1) return stops[0];
  const g = ctx.createLinearGradient(0, 0, w, 0);
  stops.forEach((c, i) => g.addColorStop(i / (stops.length - 1), c));
  return g;
}

/* ─── canvas animation (one rAF loop for every widget & tile) ───── */
let registry = [];
let canvasSeq = 0;
const memo = new Map();
function mount(container, html, cfg) {
  container.innerHTML = html;
  $$('canvas[data-c]', container).forEach((el, i) => registry.push({ el, kind: el.dataset.c, ...cfg, key: `${cfg.key}:${el.dataset.c}:${i}` }));
}
function prepCanvas(e) {
  const c = e.el, w = c.clientWidth, h = c.clientHeight;
  if (!w || !h) return null;
  const k = (window.devicePixelRatio || 1) * (e.scale ? e.scale() : 1);
  const bw = Math.round(w * k), bh = Math.round(h * k);
  if (c.width !== bw || c.height !== bh) { c.width = bw; c.height = bh; }
  const ctx = c.getContext('2d');
  ctx.setTransform(k, 0, 0, k, 0, 0);
  ctx.clearRect(0, 0, w, h);
  return { ctx, w, h, k };
}
function rr(ctx, x, y, w, h, r) {
  if (ctx.roundRect) ctx.roundRect(x, y, w, h, Math.max(0, Math.min(r, w / 2, h / 2))); else ctx.rect(x, y, w, h);
}
function smoothTrace(ctx, pts, move) {
  if (move) ctx.moveTo(pts[0][0], pts[0][1]); else ctx.lineTo(pts[0][0], pts[0][1]);
  for (let i = 1; i < pts.length - 1; i++) ctx.quadraticCurveTo(pts[i][0], pts[i][1], (pts[i][0] + pts[i + 1][0]) / 2, (pts[i][1] + pts[i + 1][1]) / 2);
  ctx.lineTo(pts[pts.length - 1][0], pts[pts.length - 1][1]);
}

function drawWave(e, t) {
  const s = e.getS(), status = e.getStatus(), d = derive(s, status);
  const cv = prepCanvas(e); if (!cv) return;
  const { ctx, w, h, k } = cv;
  let st = memo.get(e.key);
  if (!st) memo.set(e.key, st = { v: new Float32Array(200), peak: new Float32Array(200), energy: 0, parts: [], ripples: [], amp: 0 });
  const idle = status === 'idle';
  const target = d.playing && status !== 'backend' ? 1 : idle && s.idleAmbient ? .22 : 0;
  st.energy += (target - st.energy) * .08;
  const type = e.viz ?? s.visualizerType;
  const n = Math.max(6, Math.min(s.numBars, Math.floor(w / ([4, 5, 7, 12, 14].includes(type) ? 4 : 2.5))));
  const sm = .3 + .62 * s.noiseReduction;
  const tt = idle ? t * .35 : t;
  for (let i = 0; i < n; i++) {
    const tg = Math.min(1, spectrum(i, n, tt) * st.energy * s.sensitivity / 100);
    st.v[i] = st.v[i] * sm + tg * (1 - sm);
  }
  const B = bands(tt), stops = colorStops(s, d, t), paint = paintFor(ctx, stops, w);
  const lw = s.lineWidth, c = h / 2, amp = i => st.v[i] * (c - lw);
  const glow = s.glowWave && !s.batterySaver ? s.bloom : 0;
  ctx.lineJoin = 'round'; ctx.lineCap = 'round';
  if (glow > 0) { ctx.shadowColor = typeof paint === 'string' ? paint : stops[Math.floor(stops.length / 2)]; ctx.shadowBlur = 7 * glow * k; }
  ctx.strokeStyle = paint; ctx.fillStyle = paint; ctx.lineWidth = lw;
  const fillGrad = (a0, a1) => { // vertical alpha fade using the first colour
    const g = ctx.createLinearGradient(0, 0, 0, h);
    const base = stops.length > 1 ? stops[1] : stops[0];
    const col = base.startsWith('#') ? a => hexRgba(base, a) : a => base.replace(/^hsl\((.*)\)$/, `hsla($1,${a})`).replace(/,1\)$/, `,${a})`);
    g.addColorStop(0, col(a0)); g.addColorStop(1, col(a1)); return g;
  };

  switch (type) {
    case 0: case 10: {
      const layers = type === 10 ? [[1, 0, 1], [.7, 1.3, .55], [.45, 2.6, .3]] : [[1, 0, 1]];
      for (const [scaleA, phase, alpha] of layers) {
        const up = [], dn = [];
        for (let i = 0; i < n; i++) {
          const x = lw + i / (n - 1) * (w - 2 * lw);
          const a = amp(i) * scaleA * (type === 10 ? .75 + .25 * Math.sin(t * 2 + i * .3 + phase) : 1);
          up.push([x, c - a]); dn.push([x, c + a]);
        }
        ctx.globalAlpha = alpha;
        if (s.fillWave && alpha === 1) {
          ctx.save(); ctx.shadowBlur = 0; ctx.beginPath(); smoothTrace(ctx, up, true); smoothTrace(ctx, [...dn].reverse(), false); ctx.closePath();
          ctx.globalAlpha = .32; ctx.fill(); ctx.restore();
        }
        ctx.beginPath(); smoothTrace(ctx, up, true); ctx.stroke();
        ctx.beginPath(); smoothTrace(ctx, dn, true); ctx.stroke();
      }
      ctx.globalAlpha = 1;
      break;
    }
    case 1: case 2: case 6: {
      const slot = w / n, bw = Math.max(1.5, slot * .58);
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const bh = Math.max(Math.min(lw, 2), st.v[i] * h * (type === 6 ? .86 : .96));
        rr(ctx, i * slot + (slot - bw) / 2, type === 2 ? c - bh / 2 : h - bh, bw, bh, bw / 2);
      }
      if (s.fillWave) ctx.globalAlpha = .75;
      ctx.fill(); ctx.globalAlpha = 1;
      if (type === 6) {
        ctx.shadowBlur = 0; ctx.beginPath();
        for (let i = 0; i < n; i++) {
          st.peak[i] = Math.max(st.v[i], st.peak[i] - .01);
          rr(ctx, i * slot + (slot - bw) / 2, h - st.peak[i] * h * .86 - 4, bw, 2, 1);
        }
        ctx.globalAlpha = .9; ctx.fill(); ctx.globalAlpha = 1;
      }
      break;
    }
    case 3: {
      const slot = w / n;
      for (const sign of [-1, 1]) {
        ctx.beginPath(); ctx.moveTo(0, c);
        for (let i = 0; i < n; i++) { const y = c + sign * amp(i); ctx.lineTo(i * slot, y); ctx.lineTo((i + 1) * slot, y); }
        ctx.lineTo(w, c); ctx.lineJoin = 'miter'; ctx.stroke();
      }
      break;
    }
    case 4: case 5: {
      const bold = type === 5, r = (bold ? 1.7 : 1.05) * Math.max(.8, lw / 1.8), slot = w / n;
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const x = (i + .5) * slot, a = st.v[i] * (c - r);
        ctx.moveTo(x + r, c - a); ctx.arc(x, c - a, r, 0, 7);
        ctx.moveTo(x + r, c + a); ctx.arc(x, c + a, r, 0, 7);
        if (bold && a > 4 * r) { ctx.moveTo(x + r * .7, c - a / 2); ctx.arc(x, c - a / 2, r * .7, 0, 7); ctx.moveTo(x + r * .7, c + a / 2); ctx.arc(x, c + a / 2, r * .7, 0, 7); }
      }
      ctx.fill();
      ctx.shadowBlur = 0; ctx.globalAlpha = .25; ctx.beginPath();
      for (let i = 0; i < n; i += 2) { const x = (i + .5) * slot; ctx.moveTo(x + r * .6, c); ctx.arc(x, c, r * .6, 0, 7); }
      ctx.fill(); ctx.globalAlpha = 1;
      break;
    }
    case 7: { // LED meter
      const slot = w / n, bw = Math.max(2, slot * .7), seg = 4, rows = Math.floor(h / seg);
      ctx.shadowBlur = 0;
      for (let i = 0; i < n; i++) {
        const lit = Math.round(st.v[i] * rows);
        for (let r = 0; r < rows; r++) {
          const on = r < lit, hot = r > rows * .78;
          ctx.fillStyle = !on ? 'rgba(255,255,255,.06)' : s.vizColorMode === 'solid' && hot ? '#ff6b6b' : s.vizColorMode === 'solid' && r > rows * .55 ? '#ffd166' : paint;
          ctx.fillRect(i * slot + (slot - bw) / 2, h - (r + 1) * seg + 1, bw, seg - 1.3);
        }
      }
      break;
    }
    case 8: { // mountain
      const pts = [];
      for (let i = 0; i < n; i++) pts.push([i / (n - 1) * w, h - lw - st.v[i] * (h - lw * 2) * .95]);
      ctx.beginPath(); ctx.moveTo(0, h); smoothTrace(ctx, pts, false); ctx.lineTo(w, h); ctx.closePath();
      ctx.save(); ctx.shadowBlur = 0; ctx.fillStyle = fillGrad(.55, .02); ctx.fill(); ctx.restore();
      ctx.beginPath(); smoothTrace(ctx, pts, true); ctx.stroke();
      break;
    }
    case 9: { // oscilloscope
      ctx.beginPath();
      for (let x = 0; x <= w; x += 1.5) {
        const f = x / w * (n - 1), i0 = Math.floor(f), a = st.v[i0] + (st.v[Math.min(n - 1, i0 + 1)] - st.v[i0]) * (f - i0);
        const y = c + Math.sin(x * .11 + t * 9) * a * (c - lw) * (.65 + .35 * Math.sin(x * .025 - t * 3));
        x ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
      }
      ctx.stroke();
      break;
    }
    case 11: { // radial burst
      const cx = w / 2, r0 = c * .42;
      ctx.lineWidth = Math.max(1, lw * .8);
      ctx.beginPath();
      for (let i = 0; i < n; i++) {
        const ang = i / n * Math.PI * 2 - (s.reducedMotion ? 0 : t * .25), len = st.v[i] * c * .56 + 1;
        ctx.moveTo(cx + Math.cos(ang) * r0, c + Math.sin(ang) * r0);
        ctx.lineTo(cx + Math.cos(ang) * (r0 + len), c + Math.sin(ang) * (r0 + len));
      }
      ctx.stroke();
      ctx.globalAlpha = .35; ctx.beginPath(); ctx.arc(cx, c, r0 * (.9 + .15 * B.bass * st.energy), 0, 7); ctx.stroke(); ctx.globalAlpha = 1;
      break;
    }
    case 12: { // pixel matrix
      const slot = w / n, cell = Math.max(2, Math.min(slot, 5) * .72), rows = Math.max(3, Math.floor(h / 5)), mid = (rows - 1) / 2;
      ctx.shadowBlur = 0;
      for (let i = 0; i < n; i++) {
        const reach = st.v[i] * (rows / 2);
        for (let r = 0; r < rows; r++) {
          const on = Math.abs(r - mid) <= reach;
          ctx.globalAlpha = on ? 1 : .07;
          ctx.fillStyle = paint;
          ctx.fillRect(i * slot + (slot - cell) / 2, r * (h / rows) + (h / rows - cell) / 2, cell, cell);
        }
      }
      ctx.globalAlpha = 1;
      break;
    }
    case 13: { // pulse orb
      const cx = w / 2, R = c * (.3 + .55 * B.bass * st.energy) + 2;
      ctx.shadowBlur = 0;
      const col0 = stops[0];
      const g = ctx.createRadialGradient(cx, c, 0, cx, c, R * 1.6);
      g.addColorStop(0, col0.startsWith('#') ? hexRgba(col0, .95) : col0); g.addColorStop(.55, col0.startsWith('#') ? hexRgba(col0, .35) : col0); g.addColorStop(1, 'rgba(0,0,0,0)');
      ctx.fillStyle = g; ctx.beginPath(); ctx.arc(cx, c, R * 1.6, 0, 7); ctx.fill();
      for (let k2 = 0; k2 < 3; k2++) {
        const ph = ((t * .6 + k2 / 3) % 1);
        ctx.globalAlpha = (1 - ph) * .5 * st.energy; ctx.strokeStyle = paint; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.arc(cx, c, R + ph * c * 1.4, 0, 7); ctx.stroke();
      }
      ctx.globalAlpha = .55; ctx.fillStyle = paint; ctx.beginPath();
      const slot = w / n;
      for (let i = 0; i < n; i++) { const x = (i + .5) * slot; if (Math.abs(x - cx) < R * 1.8) continue; const a = st.v[i] * c * .8; ctx.moveTo(x + 1, c - a); ctx.arc(x, c - a, 1, 0, 7); ctx.moveTo(x + 1, c + a); ctx.arc(x, c + a, 1, 0, 7); }
      ctx.fill(); ctx.globalAlpha = 1;
      break;
    }
    case 14: { // sparkles
      const slot = w / n;
      if (!s.reducedMotion) for (let i = 0; i < n; i++) if (Math.random() < st.v[i] * .22 && st.parts.length < 220)
        st.parts.push({ x: (i + .5) * slot + (Math.random() - .5) * slot, y: c + (Math.random() - .5) * st.v[i] * h, vy: -(.2 + Math.random() * .8) * (1 + st.v[i]), r: .6 + Math.random() * 1.4 * (lw / 1.8), life: 1 });
      ctx.beginPath();
      for (let i = 0; i < n; i++) { const x = (i + .5) * slot; i ? ctx.lineTo(x, c - amp(i) * .25) : ctx.moveTo(x, c); }
      ctx.globalAlpha = .35; ctx.lineWidth = 1; ctx.stroke();
      st.parts = st.parts.filter(p => (p.life -= .025) > 0);
      for (const p of st.parts) { p.y += p.vy; ctx.globalAlpha = p.life; ctx.beginPath(); ctx.arc(p.x, p.y, p.r, 0, 7); ctx.fill(); }
      ctx.globalAlpha = 1;
      break;
    }
    case 15: { // silk ribbon — bass thickens, mids bend, highs add filaments, attacks ripple
      const E = st.energy, curv = s.ribbonCurvature, full = s.ribbonFullness;
      const bend = s.reducedMotion ? .4 : B.mid, pts = [];
      const steps = Math.max(24, Math.floor(w / 4));
      for (let j = 0; j <= steps; j++) {
        const x = j / steps * w, p = j / steps, env = Math.pow(Math.sin(p * Math.PI), .7);
        const f = p * (n - 1), i0 = Math.floor(f), a = st.v[i0] + (st.v[Math.min(n - 1, i0 + 1)] - st.v[i0]) * (f - i0);
        const y0 = c + Math.sin(p * Math.PI * 1.6 * curv + t * .7) * c * .32 * bend * curv * E;
        const th = (1.2 + (B.bass * .55 + a * .8) * c * .9 * full) * env * (E * .92 + .08);
        pts.push([x, y0, th, a]);
      }
      if (!s.reducedMotion && B.attack && E > .5 && st.ripples.length < 4 && Math.random() < .3) st.ripples.push({ x: Math.random() * w, age: 0 });
      ctx.save();
      ctx.shadowBlur = glow ? 16 * glow * k : 0;
      ctx.globalCompositeOperation = 'lighter';
      ctx.beginPath();
      pts.forEach(([x, y, th], j) => j ? ctx.lineTo(x, y - th / 2) : ctx.moveTo(x, y - th / 2));
      for (let j = pts.length - 1; j >= 0; j--) ctx.lineTo(pts[j][0], pts[j][1] + pts[j][2] / 2);
      ctx.closePath(); ctx.globalAlpha = .28; ctx.fill();
      ctx.lineWidth = .8; ctx.globalAlpha = .75;
      for (let f = -2; f <= 2; f++) {
        ctx.beginPath();
        pts.forEach(([x, y, th, a], j) => {
          const yy = y + th * f / 5 + Math.sin(x * .19 + t * 4 + f) * B.high * a * 2.2;
          j ? ctx.lineTo(x, yy) : ctx.moveTo(x, yy);
        });
        ctx.globalAlpha = f === 0 ? .95 : .4; ctx.stroke();
      }
      st.ripples = st.ripples.filter(r => (r.age += .03) < 1);
      for (const r of st.ripples) {
        ctx.globalAlpha = (1 - r.age) * .6; ctx.lineWidth = 1;
        ctx.beginPath(); ctx.ellipse(r.x, c, 4 + r.age * 30, 2 + r.age * c * .7, 0, 0, 7); ctx.stroke();
      }
      ctx.restore();
      break;
    }
  }
  ctx.shadowBlur = 0;
}

// Radial visualizers with the cover as the centre point. Mirrored like cava, so the ring is symmetric.
function drawOrbit(e, t) {
  const s = e.getS(), status = e.getStatus(), d = derive(s, status);
  const cv = prepCanvas(e); if (!cv) return;
  const { ctx, w, h, k } = cv;
  let st = memo.get(e.key);
  if (!st) memo.set(e.key, st = { v: new Float32Array(160), energy: 0, parts: [] });
  const target = d.playing && status !== 'backend' ? 1 : status === 'idle' && s.idleAmbient ? .22 : 0;
  st.energy += (target - st.energy) * .08;
  const style = e.orbit ?? ORBITS.map(o => o.toLowerCase()).indexOf(s.orbitStyle);
  const S0 = Math.min(w, h) / 2, small = S0 < 30;
  const half = Math.max(12, Math.min(small ? 14 : 48, s.numBars)), n = half * 2;
  const sm = .3 + .62 * s.noiseReduction;
  for (let i = 0; i < half; i++) {
    const tg = Math.min(1, spectrum(i * .5 + half * .5, half * 2, t) * st.energy * s.sensitivity / 100);
    st.v[i] = st.v[i] * sm + tg * (1 - sm);
  }
  const val = j => st.v[j < half ? j : n - 1 - j];
  const cx = w / 2, cy = h / 2;
  const R = S0 * Number(e.el.dataset.r || .38) + (small ? 1.5 : 4);
  // Bar values rarely pass ~0.75, so overscale a little to use the whole box.
  const reach = Math.max(2, (S0 - R - 2) * 1.3 * s.orbitReach);
  const rot = s.orbitRotate && !s.reducedMotion ? t * .2 : 0;
  const stops = colorStops(s, d, t);
  let paint = stops[0];
  if (stops.length > 1 && ctx.createConicGradient) {
    const g = ctx.createConicGradient(rot - Math.PI / 2, cx, cy), ring = [...stops, stops[0]];
    ring.forEach((c, i) => g.addColorStop(i / (ring.length - 1), c));
    paint = g;
  }
  const glow = s.glowWave && !s.batterySaver ? s.bloom : 0;
  if (glow > 0) { ctx.shadowColor = stops[0]; ctx.shadowBlur = (small ? 3 : 8) * glow * k; }
  ctx.strokeStyle = paint; ctx.fillStyle = paint; ctx.lineCap = 'round'; ctx.lineJoin = 'round';
  const ang = j => j / n * Math.PI * 2 + rot - Math.PI / 2;
  const at = (r, a) => [cx + Math.cos(a) * r, cy + Math.sin(a) * r];
  ctx.save(); ctx.shadowBlur = 0; ctx.globalAlpha = .18; ctx.lineWidth = 1; ctx.beginPath(); ctx.arc(cx, cy, R, 0, 7); ctx.stroke(); ctx.restore();
  switch (style) {
    case 1: { // wave
      const ring = (scale, alpha) => {
        const pts = [];
        for (let j = 0; j < n; j++) pts.push(at(R + 2 + val(j) * reach * scale, ang(j)));
        ctx.beginPath(); ctx.moveTo((pts[n - 1][0] + pts[0][0]) / 2, (pts[n - 1][1] + pts[0][1]) / 2);
        for (let j = 0; j < n; j++) { const p = pts[j], q = pts[(j + 1) % n]; ctx.quadraticCurveTo(p[0], p[1], (p[0] + q[0]) / 2, (p[1] + q[1]) / 2); }
        ctx.closePath(); ctx.globalAlpha = alpha; ctx.stroke();
        if (s.fillWave && scale === 1) { ctx.save(); ctx.shadowBlur = 0; ctx.globalAlpha = .22; ctx.fill(); ctx.restore(); }
      };
      ctx.lineWidth = small ? 1 : s.lineWidth; ring(1, 1);
      ctx.lineWidth = 1; ring(.5, .45);
      break;
    }
    case 2: { // dots
      const step = small ? 3 : 5, r = small ? .7 : 1.1 * Math.max(.8, s.lineWidth / 1.8);
      ctx.beginPath();
      for (let j = 0; j < n; j++) {
        const a = ang(j), len = val(j) * reach;
        for (let q = 0; q < len; q += step) { const [x, y] = at(R + 3 + q, a); ctx.moveTo(x + r, y); ctx.arc(x, y, r, 0, 7); }
        const [x, y] = at(R + 3 + len, a); ctx.moveTo(x + r * 1.6, y); ctx.arc(x, y, r * 1.6, 0, 7);
      }
      ctx.fill();
      break;
    }
    case 3: { // ribbon
      ctx.save(); ctx.globalCompositeOperation = 'lighter';
      for (let layer = 0; layer < 3; layer++) {
        ctx.beginPath();
        for (let j = 0; j <= n; j++) {
          const jj = j % n, a = ang(jj);
          const [x, y] = at(R + 3 + val(jj) * reach * (.55 + .45 * Math.sin(a * 3 + t * (1.2 + layer * .4) + layer * 2)), a);
          j ? ctx.lineTo(x, y) : ctx.moveTo(x, y);
        }
        ctx.closePath(); ctx.lineWidth = layer ? 1 : (small ? 1.2 : 2); ctx.globalAlpha = [.9, .5, .3][layer]; ctx.stroke();
      }
      ctx.restore();
      break;
    }
    case 4: { // sparks
      if (!s.reducedMotion) for (let j = 0; j < n; j++) if (Math.random() < val(j) * .12 && st.parts.length < 260)
        st.parts.push({ a: ang(j) + (Math.random() - .5) * .1, r: R + 3, v: (.4 + Math.random()) * (small ? .3 : 1) * (1 + val(j)), life: 1, s: .6 + Math.random() * (small ? .5 : 1.3) });
      st.parts = st.parts.filter(p => (p.life -= .02) > 0 && p.r < S0);
      for (const p of st.parts) { p.r += p.v; ctx.globalAlpha = p.life; const [x, y] = at(p.r, p.a); ctx.beginPath(); ctx.arc(x, y, p.s, 0, 7); ctx.fill(); }
      break;
    }
    default: { // bars
      ctx.lineWidth = Math.max(small ? 1 : 1.4, Math.min(2 * Math.PI * R / n * .55, s.lineWidth * 1.6));
      ctx.beginPath();
      for (let j = 0; j < n; j++) {
        const a = ang(j), len = val(j) * reach + (small ? .8 : 2);
        const [x0, y0] = at(R + 3, a), [x1, y1] = at(R + 3 + len, a);
        ctx.moveTo(x0, y0); ctx.lineTo(x1, y1);
      }
      ctx.stroke();
    }
  }
  ctx.shadowBlur = 0; ctx.globalAlpha = 1;
}

function seedHeights(key, n) {
  let seed = 0;
  for (let c = 0; c < key.length; c++) seed = (seed * 31 + key.charCodeAt(c)) >>> 0;
  const out = [];
  for (let i = 0; i < n; i++) {
    seed = (seed * 1664525 + 1013904223) >>> 0;
    out.push(.15 + (seed >>> 16) / 65535 * .85 * Math.sin((n > 1 ? i / (n - 1) : 0) * Math.PI));
  }
  return out;
}
function drawSeek(e, t) {
  const s = e.getS(), d = derive(s, e.getStatus());
  const style = e.pbs ?? s.progressBarStyle;
  if (![4, 5, 7].includes(style)) return;
  const cv = prepCanvas(e); if (!cv) return;
  const { ctx, w, h } = cv;
  const prog = e.fixedP ?? P.pos / d.t.len, px = prog * w;
  let st = memo.get(e.key); if (!st) memo.set(e.key, st = { amp: 0 });
  if (style === 4) {
    const n = Math.floor(w / 5), hs = seedHeights(d.t.title + d.t.artist, n);
    for (let i = 0; i < n; i++) {
      const x = i * 5, played = x + 1.5 < px, bh = Math.max(2, hs[i] * h * (played ? 1 : .45));
      ctx.fillStyle = played ? hexRgba(d.accent, .9) : hexRgba(d.text, .25);
      ctx.beginPath(); rr(ctx, x, (h - bh) / 2, 3, bh, 1.5); ctx.fill();
    }
    if (prog > 0 && prog < 1) { ctx.fillStyle = hexRgba(d.control, .95); ctx.fillRect(px - 1, 0, 2, h); }
  } else if (style === 5) { // Android-style squiggle
    st.amp += ((d.playing && !s.reducedMotion ? 2.2 : 0) - st.amp) * .1;
    ctx.lineWidth = 2; ctx.lineCap = 'round';
    ctx.strokeStyle = hexRgba(d.pg1, 1); ctx.beginPath();
    for (let x = 1; x <= px; x += 1) { const y = h / 2 + Math.sin(x * .38 - t * 6) * st.amp; x > 1 ? ctx.lineTo(x, y) : ctx.moveTo(x, y); }
    ctx.stroke();
    ctx.strokeStyle = hexRgba(d.text, .25); ctx.beginPath(); ctx.moveTo(Math.min(w - 1, px + 5), h / 2); ctx.lineTo(w - 1, h / 2); ctx.stroke();
    ctx.fillStyle = d.control; ctx.beginPath(); rr(ctx, px - 1.5, 0, 3, h, 1.5); ctx.fill();
  } else { // dotted
    for (let x = 3; x < w; x += 6) {
      const played = x < px;
      ctx.fillStyle = played ? d.accent : hexRgba(d.text, .3);
      ctx.beginPath(); ctx.arc(x, h / 2, played ? 1.6 : 1.1, 0, 7); ctx.fill();
    }
    ctx.fillStyle = d.control; ctx.beginPath(); ctx.arc(Math.max(3, Math.min(w - 3, px)), h / 2, 3.2, 0, 7); ctx.fill();
  }
}

let lastT = performance.now();
function frame(now) {
  const dt = Math.min(.1, (now - lastT) / 1000); lastT = now;
  const t = now / 1000;
  if (P.playing && stageStatus !== 'idle' && stageStatus !== 'paused') {
    P.pos += dt;
    if (P.pos >= TRACKS[P.track].len) { P.pos = 0; if (!P.repeat) P.track = (P.track + 1) % TRACKS.length; renderPlayers(); }
  }
  registry = registry.filter(e => e.el.isConnected);
  for (const e of registry) {
    const s = e.getS(), fps = s.batterySaver ? Math.min(20, s.framerate) : s.framerate;
    if (now - (e.last || 0) < 1000 / fps - 3) continue;
    e.last = now;
    if (e.kind === 'wave') drawWave(e, t);
    else if (e.kind === 'orbit') drawOrbit(e, t);
    else if (e.el.offsetParent) drawSeek(e, t);
  }
  const tr = TRACKS[P.track], prog = String(P.pos / tr.len), txt = fmtTime(P.pos), rem = '-' + fmtTime(tr.len - P.pos), ly = lyricAt(tr);
  const bass = P.playing && stageStatus !== 'idle' ? bands(t).bass : 0;
  $$('.w').forEach(el => el.style.setProperty('--p', prog));
  $$('.w.bass').forEach(el => el.style.setProperty('--bass', bass.toFixed(3)));
  $$('.w [data-el]').forEach(el => { if (el.textContent !== txt) el.textContent = txt; });
  $$('.w [data-rem]').forEach(el => { if (el.textContent !== rem) el.textContent = rem; });
  $$('.w [data-ly]').forEach(el => { if (el.textContent !== ly) el.textContent = ly; });
  const lyi = lyricIndexAt(tr);
  $$('.w .lyr-line').forEach(el => {
    const i = +el.dataset.i;
    el.classList.toggle('now', i === lyi);
    el.classList.toggle('past', i < lyi);
    el.classList.toggle('future', i > lyi);
  });
  requestAnimationFrame(frame);
}

/* ─── main stage ───────────────────────────────────────────────── */
let S = load() || structuredClone(DEFAULTS);
const env = 'kde'; // One consistent desktop/panel presentation for the browser demo.
let stageStatus = 'normal', zoom = 'fit', backdrop = 'dusk', popupOpen = true, activePreset = null, activeTab = 'presets', query = '', presetFilter = 'all';
function load() {
  try { const o = JSON.parse(localStorage.getItem('pav-lab4')); if (o) return { ...DEFAULTS, ...o }; } catch (e) { }
  return null;
}
function save() { try { localStorage.setItem('pav-lab4', JSON.stringify(S)); } catch (e) { } }

let stageScale = 1;
const mainCfg = { key: 'main', getS: () => S, getStatus: () => stageStatus, scale: () => stageScale };
function sceneInfo() {
  if (isPill(S)) {
    const [pw] = sizeOf(S);
    const W = Math.max(560, pw + 380);
    return { W, H: env === 'kde' ? 44 : 36, pop: popupOpen && S.pillClick === 'popup' ? 124 : (S.hoverDetails !== 'off' ? 150 : 0) };
  }
  const [W, H] = sizeOf(S);
  return { W, H, pop: ['tooltip', 'drawer'].includes(S.hoverDetails) ? 150 : 0 };
}
function renderMain() {
  const info = sceneInfo();
  let html;
  if (isPill(S)) {
    const pop = popupOpen && S.pillClick === 'popup' && stageStatus !== 'idle' ? widgetHTML(popupState(S), stageStatus, { noHover: true }) : '';
    html = panelHTML(widgetHTML(S, stageStatus, { hcAbove: env === 'kde' }), env, pop, info.W).html;
  } else html = widgetHTML(S, stageStatus);
  mount($('#mainWidget'), html, mainCfg);
  fitStage();
  const d = derive(S, 'demo');
  $('#panel').setAttribute('style', colorVars(d) + '--cover:' + d.t.cover + ';--p1:' + d.t.pal.p1 + ';--p2:' + d.t.pal.p2 + ';--p3:' + d.t.pal.p3 + ';--ts:11px;--p:.58');
  $('#panel').classList.toggle('dir-down', S.vizDirection === 'down');
  $('#lgMap').setAttribute('scale', (S.glassRefraction * 80).toFixed(0));
  const hints = [];
  if (isPill(S) && S.pillClick === 'popup') hints.push('Click the pill to ' + (popupOpen ? 'close' : 'open') + ' the popup');
  if (S.hoverDetails !== 'off') hints.push('hover for track details');
  if (S.scrollVolume) hints.push('scroll to change volume');
  if (S.surfaceStyle === 'liquid' && S.showBg && S.glassSpecular) hints.push('move the pointer over the glass');
  $('#hint').hidden = !hints.length;
  $('#hint').textContent = hints.join(' · ').replace(/^./, c => c.toUpperCase());
}
function fitStage() {
  const { W, H, pop } = sceneInfo();
  const st = $('#stage'), sw = st.clientWidth, sh = st.clientHeight;
  const aw = sw - 48, ah = sh - 124;
  const fit = Math.max(.35, Math.min(aw / W, ah / (H + pop)));
  stageScale = zoom === 'fit' ? Math.min(fit, 1) : Math.min(Number(zoom), Math.max(.35, aw / W));
  const sc = $('#scaler'), inner = $('#mainWidget');
  inner.style.width = W + 'px'; inner.style.height = H + 'px'; inner.style.transform = `scale(${stageScale})`;
  sc.style.width = W * stageScale + 'px'; sc.style.height = H * stageScale + 'px';
  let x = (sw - W * stageScale) / 2, y;
  const freeH = ah - (H + pop) * stageScale;
  if (isPill(S)) y = env === 'kde' ? sh - 60 - H * stageScale : 60;
  else if (env === 'hypr') {
    y = 62 + Math.max(0, freeH) * S.verticalPosition;
    x = S.hAnchor === 'left' ? 24 : S.hAnchor === 'right' ? sw - 24 - W * stageScale : x;
  } else y = 62 + Math.max(0, freeH) / 2;
  sc.style.left = x + 'px'; sc.style.top = y + 'px';
  $('#sizeInfo').textContent = `${isPill(S) ? sizeOf(S).join(' × ') + ' pill' : W + ' × ' + H + ' px'} · ${stageScale.toFixed(2)}×`;
}
new ResizeObserver(() => { fitStage(); fitPresets(); fitHero(); }).observe(document.body);

const BACKDROPS = Object.fromEntries(StudioCatalog.wallpapers.map(w => [w.id, w.label]));
$('#bdPicker').insertAdjacentHTML('beforeend', Object.entries(BACKDROPS).map(([k, n]) => `<button class="bdsw" data-bd="${k}" title="${n}" aria-label="${n}" aria-pressed="${k === backdrop}"><span class="bd bd-${k}"></span></button>`).join(''));
$('#bdPicker').addEventListener('click', e => {
  const b = e.target.closest('[data-bd]'); if (!b) return;
  backdrop = b.dataset.bd; $('#stageBd').className = 'bd bd-' + backdrop;
  $$('[data-bd]').forEach(x => x.setAttribute('aria-pressed', x === b));
});
const ACCENTS = { '#3daee9': 'Breeze blue', '#a855f7': 'Purple', '#e93d8f': 'Pink', '#3dd68c': 'Green', '#f67400': 'Orange' };
$('#accentPicker').insertAdjacentHTML('beforeend', Object.entries(ACCENTS).map(([c, n]) => `<button class="acc" data-acc="${c}" title="${n}" aria-label="${n} custom accent" aria-pressed="${c === P.sysAccent}" style="background:${c}"></button>`).join(''));
$('#accentPicker').addEventListener('click', e => {
  const b = e.target.closest('[data-acc]'); if (!b) return;
  update({ useSystemAccent: false, accentFromArt: false, customColor: b.dataset.acc });
});
$('#zoomPicker').addEventListener('click', e => {
  const b = e.target.closest('[data-z]'); if (!b) return;
  zoom = b.dataset.z; $$('[data-z]').forEach(x => x.setAttribute('aria-pressed', x === b)); fitStage();
});
$('#statusSel').addEventListener('change', e => {
  stageStatus = e.target.value;
  P.playing = !['paused', 'idle'].includes(stageStatus);
  renderPlayers();
});
$('#lightbox').addEventListener('click', () => { $('#lightbox').hidden = true; });

// Transport, seek, pill, art and player switch work on every widget on the page.
document.addEventListener('click', e => {
  const a = e.target.closest('.w [data-act]'); if (!a) return;
  e.stopPropagation();
  const act = a.dataset.act, tr = TRACKS[P.track];
  switch (act) {
    case 'play':
      P.playing = !P.playing;
      if (stageStatus === 'paused' && P.playing) stageStatus = 'normal';
      else if (stageStatus === 'normal' && !P.playing) stageStatus = 'paused';
      $('#statusSel').value = stageStatus;
      break;
    case 'prev': if (P.pos > 3) P.pos = 0; else { P.track = (P.track + 2) % 3; P.pos = 0; } break;
    case 'next': P.track = (P.track + 1) % 3; P.pos = 0; break;
    case 'seek': { const r = a.getBoundingClientRect(); P.pos = Math.max(0, Math.min(1, (e.clientX - r.left) / r.width)) * tr.len; return; }
    case 'shuffle': P.shuffle = !P.shuffle; break;
    case 'repeat': P.repeat = !P.repeat; break;
    case 'player': P.alt = (P.alt + 1) % 3; toast(`Now controlling ${P.alt ? ALT_PLAYERS[P.alt - 1] : tr.app}`); break;
    case 'art': {
      const s = a.closest('#mainWidget') ? S : null;
      const mode = s ? s.artClick : 'zoom';
      if (mode === 'raise') { toast(`Would raise the ${tr.app} window`); return; }
      if (!a.closest('#mainWidget')) return;
      $('#lightbox').innerHTML = `<div style="background-image:${tr.cover}"></div><p>${esc(tr.title)}<span>${esc(tr.artist)} · ${esc(tr.album)}</span></p>`;
      $('#lightbox').hidden = false;
      return;
    }
    case 'pill':
      if (!a.closest('#mainWidget')) return;
      if (S.pillClick === 'popup') { popupOpen = !popupOpen; renderMain(); return; }
      P.playing = !P.playing; stageStatus = P.playing ? 'normal' : 'paused'; $('#statusSel').value = stageStatus;
      break;
  }
  renderPlayers();
}, true);

let volTimer;
document.addEventListener('wheel', e => {
  const w = e.target.closest('#mainWidget .w');
  if (!w || !S.scrollVolume) return;
  e.preventDefault();
  P.volume = Math.max(0, Math.min(1, P.volume + (e.deltaY < 0 ? .04 : -.04)));
  $$('#mainWidget [data-vol]').forEach(v => { v.classList.add('on'); v.firstChild.style.setProperty('--v', P.volume); });
  $$('#mainWidget .vb').forEach(v => v.style.setProperty('--v', P.volume));
  clearTimeout(volTimer);
  volTimer = setTimeout(() => $$('[data-vol]').forEach(v => v.classList.remove('on')), 1100);
}, { passive: false });
document.addEventListener('pointermove', e => {
  const w = e.target.closest('.w.specular'); if (!w) return;
  const r = w.getBoundingClientRect();
  w.style.setProperty('--mx', ((e.clientX - r.left) / r.width * 100).toFixed(1) + '%');
  w.style.setProperty('--my', ((e.clientY - r.top) / r.height * 100).toFixed(1) + '%');
});

/* ─── presets ──────────────────────────────────────────────────── */
const PRESETS = [
  { id: 'classic', cat: ['current', 'desktop'], name: 'Classic', note: 'Exactly today’s defaults — nothing changes for current users.', tags: [['Current default', 'exist']], bd: 'dusk', s: {} },
  { id: 'glass', cat: ['desktop', 'glass'], name: 'Glass Classic', note: 'The layout people know, on a frosted card with a soft lift.', tags: [['Surface']], bd: 'neon', s: { showBg: true, surfaceStyle: 'glass', bgRadius: 16, cardShadow: 'soft', edgeHighlight: true } },
  { id: 'liquid', cat: ['desktop', 'glass'], name: 'Liquid Glass', note: 'Clear refracting glass, a light rim that follows your pointer, colour from the cover.', tags: [['Liquid glass'], ['Adaptive']], bd: 'sea', s: { layoutMode: 'stacked', showBg: true, surfaceStyle: 'liquid', glassTint: 'clear', glassRefraction: .5, bgRadius: 28, accentFromArt: true, artShape: 'squircle', artGlow: true, dockStyle: 'accent', showSource: true, progressBarStyle: 8, titleSize: 12, cardShadow: 'soft', visualizerType: 0, fillWave: true } },
  { id: 'poster', cat: ['desktop'], name: 'Poster', note: 'The title set big, the music as a soft texture behind it, and a large clock.', tags: [['Layout'], ['Typography']], bd: 'dusk', s: { layoutMode: 'poster', showAlbum: true, visualizerType: 2, vizColorMode: 'gradient', glowWave: false, dockStyle: 'bare', progressBarStyle: 1 } },
  { id: 'posterhang', cat: ['desktop'], name: 'Poster · Hanging bars', note: 'A centred two-line title with bars hanging from the top edge behind it.', tags: [['Layout'], ['Hanging bars']], bd: 'olive', s: { layoutMode: 'poster', posterAlign: 'center', posterLines: 2, posterClock: false, posterVizOpacity: .5, visualizerType: 1, vizDirection: 'down', glowWave: false, useSystemAccent: false, customColor: '#d1e5bd', dockStyle: 'bare', progressBarStyle: 6 } },
  { id: 'stalactite', cat: ['desktop', 'adaptive'], name: 'Stalactites', note: 'Peak bars hang from the top edge and drip toward the title. Ice palette.', tags: [['Hanging bars']], bd: 'breeze', s: { layoutMode: 'hero', visualizerType: 6, vizDirection: 'down', vizColorMode: 'palette', vizPalette: 'ice', showBg: true, surfaceStyle: 'glass', bgRadius: 18, cardShadow: 'soft', showTimes: false, dockStyle: 'bare' } },
  { id: 'orbit', cat: ['desktop', 'adaptive'], name: 'Orbit', note: 'The cover is the centre; bars circle it, rotate slowly, and the cover breathes with the bass.', tags: [['Layout'], ['Radial']], bd: 'neon', s: { layoutMode: 'orbit', orbitStyle: 'bars', artShape: 'circle', showBg: true, surfaceStyle: 'glass', bgRadius: 28, vizColorMode: 'cover', accentFromArt: true, cardShadow: 'soft', edgeHighlight: true, dockStyle: 'accent', progressBarStyle: 1, showTimes: false } },
  { id: 'halo', cat: ['desktop', 'adaptive'], name: 'Halo', note: 'A spinning record inside a soft ribbon halo, with a progress ring. Iris palette.', tags: [['Layout'], ['Radial']], bd: 'dusk', s: { layoutMode: 'orbit', orbitStyle: 'ribbon', artShape: 'vinyl', vizColorMode: 'palette', vizPalette: 'iris', hueReactive: true, bloom: 1.2, dockStyle: 'bare', progressBarStyle: 10, showSource: true } },
  { id: 'sunburst', cat: ['desktop'], name: 'Sunburst', note: 'Sparks fly off the cover on every beat. Ember palette on a dark tint.', tags: [['Layout'], ['Radial']], bd: 'sea', s: { layoutMode: 'orbit', orbitStyle: 'sparks', artShape: 'squircle', vizColorMode: 'palette', vizPalette: 'ember', showBg: true, bgColor: '#0a0b10', artBgTransparency: .75, bgRadius: 24, progressBarStyle: 5, showTimes: false } },
  { id: 'orbiticon', cat: ['panel'], env: 'hypr', name: 'Orbit Icon', note: 'A tiny radial ring around the cover, living in the bar.', tags: [['Panel'], ['Radial']], bd: 'breeze', s: { layoutMode: 'pillicon', pillEq: 'wave', artShape: 'circle', vizColorMode: 'palette', vizPalette: 'aurora', hoverDetails: 'tooltip' } },
  { id: 'quiet',cat: ['desktop', 'glass'], name: 'Quiet Glass', note: 'Title leads, calm mirror bars, one soft accent, round play button.', tags: [['Layout'], ['Dock']], bd: 'olive', s: { layoutMode: 'stacked', showBg: true, surfaceStyle: 'glass', bgRadius: 22, useSystemAccent: false, customColor: '#d1e5bd', visualizerType: 2, glowWave: false, progressBarStyle: 1, dockStyle: 'accent', showSource: true, showAlbum: true, cardShadow: 'soft', edgeHighlight: true, titleSize: 12 } },
  { id: 'panelpill', cat: ['panel'], env: 'kde', name: 'Panel Pill', note: 'Clean text pill for Plasma panels. Static EQ — zero animation cost.', tags: [['Panel']], bd: 'breeze', s: { layoutMode: 'pill', pillEq: 'static', pillProgress: 'underline', pillControls: 'play', hoverDetails: 'tooltip' } },
  { id: 'baricon', cat: ['panel'], env: 'hypr', name: 'Bar Icon', note: 'Just the cover with a progress ring, for a Hyprland bar.', tags: [['Panel'], ['Hyprland', 'hypr']], bd: 'neon', s: { layoutMode: 'pillicon', artShape: 'circle', pillProgress: 'ring', pillEq: 'live', hoverDetails: 'tooltip' } },
  { id: 'ribbonpill', cat: ['panel', 'adaptive'], env: 'kde', name: 'Ribbon Pill', note: 'A glowing silk ribbon living in the panel, Aurora palette.', tags: [['Panel'], ['Ribbon']], bd: 'dusk', s: { layoutMode: 'pill', pillEq: 'wave', visualizerType: 15, vizColorMode: 'palette', vizPalette: 'aurora', hueReactive: true, pillArt: false, pillContent: 'title', showBg: true, surfaceStyle: 'glass' } },
  { id: 'ribbon', cat: ['desktop', 'adaptive'], name: 'Silk Ribbon', note: 'Bass thickens it, mids bend it, highs light the filaments. Ember palette.', tags: [['Visualizer'], ['Palettes']], bd: 'breeze', s: { layoutMode: 'hero', visualizerType: 15, vizColorMode: 'palette', vizPalette: 'ember', hueReactive: true, bloom: 1.3, showBg: true, surfaceStyle: 'color', bgColor: '#0a0b10', artBgTransparency: .7, bgRadius: 20, progressBarStyle: 1, showTimes: false, dockStyle: 'bare', artShape: 'circle' } },
  { id: 'cover', cat: ['current', 'desktop'], name: 'Cover Art', note: 'Album art fills the card; the sharp thumbnail stays on top.', tags: [['Existing options', 'exist']], bd: 'neon', s: { showBg: true, surfaceStyle: 'art', artBgBlur: .44, artBgDim: .3, bgRadius: 22, artBgKeepThumb: true } },
  { id: 'atmos', cat: ['desktop', 'adaptive'], name: 'Album Atmosphere', note: 'Cover colours bleed into the card and drive the accent.', tags: [['Surface'], ['Adaptive']], bd: 'breeze', s: { layoutMode: 'stacked', showBg: true, surfaceStyle: 'atmosphere', artShape: 'circle', accentFromArt: true, bgRadius: 26, fillWave: true, dockStyle: 'accent', showSource: true, cardShadow: 'lifted', titleSize: 12, edgeHighlight: true, vizColorMode: 'cover' } },
  { id: 'lyrics', cat: ['desktop', 'adaptive'], name: 'Lyrics Card', note: 'Synced lyric line under the artist, Ribbon wave, cover palette.', tags: [['Lyrics'], ['Info']], bd: 'sea', s: { layoutMode: 'stacked', showBg: true, surfaceStyle: 'atmosphere', showLyrics: true, accentFromArt: true, visualizerType: 10, vizColorMode: 'cover', bgRadius: 22, dockStyle: 'accent', progressBarStyle: 5, showTimes: false, cardShadow: 'soft' } },
  { id: 'lyricsonly', cat: ['desktop'], name: 'Lyrics Only', note: 'Room to read: surrounding lines and a clear current line, no card clutter.', tags: [['Lyrics'], ['Layout']], bd: 'sea', s: { layoutMode: 'lyrics', showLyrics: true, showBg: true, surfaceStyle: 'color', bgColor: '#101318', artBgTransparency: .92, bgRadius: 22, titleSize: 14, showArtThumb: false, hoverDetails: 'off', cardShadow: 'soft' } },
  { id: 'cd', cat: ['desktop'], name: 'CD Player', note: 'Spinning disc art, squiggle seek bar, flips over for track details.', tags: [['Art shape'], ['Flip details']], bd: 'day', s: { layoutMode: 'inline', artShape: 'cd', showBg: true, surfaceStyle: 'glass', bgRadius: 18, progressBarStyle: 5, hoverDetails: 'flip', detailFields: 'album,track,genre,format', cardShadow: 'soft', dockStyle: 'bare', visualizerType: 9 } },
  { id: 'solid', cat: ['desktop'], name: 'Soft Solid', note: 'Warm mineral surface and crisp dark text. No blur needed.', tags: [['Surface'], ['Layout']], bd: 'day', s: { layoutMode: 'inline', showBg: true, surfaceStyle: 'solid', bgRadius: 14, useSystemAccent: false, customColor: '#5c734c', glowWave: false, progressBarStyle: 6, dockStyle: 'bare', visualizerType: 6, cardShadow: 'soft', showTimes: false } },
  { id: 'neon', cat: ['current', 'desktop'], name: 'Neon Night', note: 'Dark tint, mirror bars and the glowing pulse bar.', tags: [['Existing options', 'exist']], bd: 'neon', s: { showBg: true, bgColor: '#0a0b10', bgRadius: 12, useSystemAccent: false, customColor: '#c084fc', visualizerType: 2, progressBarStyle: 2, artBgTransparency: .82 } },
  { id: 'arcade', cat: ['desktop'], name: 'Arcade', note: 'LED meter with hot peaks, pixel-sharp art, time-only readout.', tags: [['Visualizer'], ['Progress']], bd: 'breeze', s: { visualizerType: 7, glowWave: false, artShape: 'sharp', progressBarStyle: 9, showBg: true, bgColor: '#0b0d0c', bgRadius: 4, useSystemAccent: false, customColor: '#5dff9e', artBorder: 'accent', dockStyle: 'bare', grain: true } },
  { id: 'vinyl', cat: ['desktop', 'adaptive'], name: 'Vinyl', note: 'A record that spins while playing, sparkles, colour from the cover.', tags: [['Art shape'], ['Adaptive']], bd: 'dusk', s: { layoutMode: 'inline', artShape: 'vinyl', showBg: true, surfaceStyle: 'glass', bgRadius: 18, visualizerType: 14, accentFromArt: true, progressBarStyle: 4, showTimes: false, dockStyle: 'accent', cardShadow: 'soft', grain: true } },
  { id: 'hero', cat: ['desktop'], name: 'Hero Wave', note: 'The visualizer takes the stage; track info tucks underneath.', tags: [['Layout']], bd: 'breeze', s: { layoutMode: 'hero', showBg: true, surfaceStyle: 'glass', bgRadius: 18, fillWave: true, lineWidth: 2.2, dockStyle: 'bare', cardShadow: 'soft', artShape: 'squircle', showTimes: false, vizColorMode: 'gradient' } },
  { id: 'strip', cat: ['desktop'], name: 'Slim Strip', note: 'A wide, low bar for the bottom of the screen.', tags: [['Layout']], bd: 'dusk', s: { layoutMode: 'strip', showBg: true, surfaceStyle: 'glass', bgRadius: 23, visualizerType: 3, dockStyle: 'bare', lineWidth: 1.4, artShape: 'circle' } },
  { id: 'mirror', cat: ['desktop'], name: 'Mirrored Minimal', note: 'Art on the right, dotted progress, no card, controls on hover.', tags: [['Layout'], ['Dock']], bd: 'olive', s: { layoutMode: 'mirrored', visualizerType: 12, progressBarStyle: 7, dockStyle: 'hover', textAlign: 'right' } },
  { id: 'compact', cat: ['current', 'desktop'], name: 'Compact', note: 'No art column — visualizer, progress and title only.', tags: [['Existing options', 'exist']], bd: 'breeze', s: { layoutMode: 'compact', visualizerType: 4 } },
];
const FILTERS = [['all', 'All'], ['current', 'Today’s options'], ['desktop', 'Desktop'], ['panel', 'Panel'], ['glass', 'Glass'], ['adaptive', 'Adaptive colour']];
$('#filters').innerHTML = FILTERS.map(([k, l]) => `<button data-f="${k}" aria-pressed="${k === presetFilter}">${l}</button>`).join('');
$('#filters').addEventListener('click', e => {
  const b = e.target.closest('[data-f]'); if (!b) return;
  presetFilter = b.dataset.f; $$('[data-f]').forEach(x => x.setAttribute('aria-pressed', x === b)); renderPresets();
});
const presetState = p => ({ ...DEFAULTS, ...p.s });
function presetScene(p, ps, status) {
  if (!isPill(ps)) { const [W, H] = sizeOf(ps); return { html: widgetHTML(ps, status, { noHover: true }), W, H }; }
  const W = Math.max(520, sizeOf(ps)[0] + 330), pm = panelHTML(widgetHTML(ps, status, { noHover: true }), p.env || 'kde', '', W);
  return { html: pm.html, W, H: pm.mh };
}
function renderPresets() {
  const list = PRESETS.filter(p => presetFilter === 'all' || p.cat.includes(presetFilter));
  $('#presets').innerHTML = list.map(p => `<article class="pcard ${activePreset === p.id ? 'active' : ''}" data-preset="${p.id}">
    <div class="pv" title="Apply ${p.name}"><span class="bd bd-${p.bd}"></span><div class="fit"><div class="fi"></div></div></div>
    <div class="meta"><div><h3>${p.name}</h3><p>${p.note}</p><div class="tags">${p.tags.map(([t, k]) => `<span class="new ${k || ''}">${k === 'exist' || k === 'hypr' ? t : 'New · ' + t}</span>`).join('')}</div></div><button class="use">${activePreset === p.id ? 'Applied' : 'Use'}</button></div></article>`).join('');
  $$('.pcard').forEach(card => {
    const p = PRESETS.find(x => x.id === card.dataset.preset), ps = presetState(p);
    const fi = $('.fi', card);
    const getStatus = () => (stageStatus === 'paused' ? 'paused' : 'normal');
    const sc = presetScene(p, ps, getStatus());
    card._size = [sc.W, sc.H];
    mount(fi, sc.html, { key: 'preset-' + p.id, getS: () => ps, getStatus, scale: () => Number(fi.dataset.scale || 1) });
  });
  fitPresets();
}
function fitPresets() {
  $$('.pcard').forEach(card => {
    const [W, H] = card._size || [360, 104];
    const pv = $('.pv', card), fi = $('.fi', card), fit = $('.fit', card);
    const sc = Math.min(1.25, (pv.clientWidth - 32) / W, (pv.clientHeight - 28) / H);
    fi.dataset.scale = sc;
    fit.style.width = W * sc + 'px'; fit.style.height = H * sc + 'px';
    fi.style.cssText = `width:${W}px;height:${H}px;transform:scale(${sc});transform-origin:0 0`;
  });
}
function renderHero() {
  const p = PRESETS.find(x => x.id === 'liquid'), ps = presetState(p);
  const getStatus = () => (stageStatus === 'paused' ? 'paused' : 'normal');
  const sc = presetScene(p, ps, getStatus());
  const fi = $('#heroFi');
  fi._size = [sc.W, sc.H];
  mount(fi, sc.html, { key: 'hero', getS: () => ps, getStatus, scale: () => Number(fi.dataset.scale || 1) });
  fitHero();
}
function fitHero() {
  const fi = $('#heroFi'); if (!fi || !fi._size) return;
  const [W, H] = fi._size, fit = $('#heroFit'), card = fi.closest('.hero-card');
  if (!card) return;
  const sc = Math.min(1.35, (card.clientWidth - 40) / W, (card.clientHeight - 40) / H);
  fi.dataset.scale = sc;
  fit.style.width = W * sc + 'px'; fit.style.height = H * sc + 'px';
  fi.style.cssText = `width:${W}px;height:${H}px;transform:scale(${sc});transform-origin:0 0`;
}
$('#presets').addEventListener('click', e => {
  if (e.target.closest('.w [data-act]')) return;
  const card = e.target.closest('[data-preset]'); if (!card || !(e.target.closest('.use') || e.target.closest('.pv'))) return;
  applyPreset(PRESETS.find(x => x.id === card.dataset.preset));
  showPage('studio');
});

/* ─── presets inside the settings panel ────────────────────────── */
// Colour keys "Keep my colours" preserves when a look is applied.
const COLOR_KEYS = ['useSystemAccent', 'customColor', 'accentFromArt', 'useSystemText', 'customTextColor', 'useSystemControls', 'customControlColor',
  'useSystemDockBg', 'customDockBgColor', 'vizColorMode', 'vizPalette', 'hueReactive', 'bgColor'];
let keepColors = false, pickFilter = 'all', playerRev = 0, presetDirty = false;

function applyPreset(p) {
  const next = { ...DEFAULTS, ...p.s };
  if (keepColors) for (const k of COLOR_KEYS) next[k] = S[k];
  // Placement is personal, never part of a look.
  for (const k of Object.keys(HYPR)) next[k] = S[k];
  next.hAnchor = S.hAnchor;
  S = next; activePreset = p.id; presetDirty = false;
  popupOpen = true;
  onChange(); renderPresets();
  toast(`Applied “${p.name}”${keepColors ? ' · kept your colours' : ''}`);
}

function presetTile(p, ps, extra) {
  const sc = presetScene(p, ps, 'normal');
  const k = Math.min(1, 138 / sc.W, 58 / sc.H);
  return {
    sc, k,
    html: `<div class="pp" role="button" tabindex="0" data-pid="${p.id}"><div class="ppv"><span class="bd bd-${p.bd || 'breeze'}"></span><div class="fit" style="width:${sc.W * k}px;height:${sc.H * k}px"><div class="fi" style="width:${sc.W}px;height:${sc.H}px;transform:scale(${k});transform-origin:0 0"></div></div></div><div class="tl"><span>${esc(p.name)}</span>${extra || ''}</div></div>`,
  };
}
function fillGrid(grid, list, keyPrefix, extraFn) {
  const tiles = list.map(p => { const ps = presetState(p); return { p, ps, t: presetTile(p, ps, extraFn ? extraFn(p) : '') }; });
  grid.innerHTML = tiles.map(o => o.t.html).join('') || '<div class="rd" style="padding:6px 2px">Nothing saved yet — tune a look, name it below and save.</div>';
  const getStatus = () => (stageStatus === 'paused' ? 'paused' : 'normal');
  tiles.forEach((o, i) => mount($('.fi', grid.children[i]), o.t.sc.html, { key: keyPrefix + o.p.id, getS: () => o.ps, getStatus, scale: () => o.t.k }));
}
function activateOnKey(grid, find) {
  grid.addEventListener('keydown', e => {
    if (e.key !== 'Enter' && e.key !== ' ') return;
    const t = e.target.closest('[data-pid]'); if (!t) return;
    e.preventDefault(); applyPreset(find(t.dataset.pid));
  });
}

function renderPresetPicker(el) {
  el.innerHTML = `<div class="pp-top"><div class="seg">${FILTERS.map(([k, l]) => `<button data-pf="${k}">${l}</button>`).join('')}</div><label class="keep"><input type="checkbox" class="switch" data-keep>Keep my colours</label></div><div class="pp-grid"></div>`;
  const grid = $('.pp-grid', el);
  let builtFor = '';
  const find = id => PRESETS.find(p => p.id === id);
  $$('[data-pf]', el).forEach(b => b.onclick = () => { pickFilter = b.dataset.pf; syncSettings(); });
  $('[data-keep]', el).onchange = e => { keepColors = e.target.checked; };
  grid.addEventListener('click', e => { const t = e.target.closest('[data-pid]'); if (t) applyPreset(find(t.dataset.pid)); });
  activateOnKey(grid, find);
  return () => {
    const want = pickFilter + ':' + playerRev;
    if (builtFor !== want) {
      builtFor = want;
      fillGrid(grid, PRESETS.filter(p => pickFilter === 'all' || p.cat.includes(pickFilter)), 'pick-', p => p.cat.includes('current') ? '<span class="new exist">Today</span>' : '');
    }
    $$('[data-pf]', el).forEach(b => b.setAttribute('aria-pressed', b.dataset.pf === pickFilter));
    $('[data-keep]', el).checked = keepColors;
    $$('[data-pid]', grid).forEach(t => t.setAttribute('aria-pressed', t.dataset.pid === activePreset && !presetDirty));
  };
}

const loadUser = () => { try { return JSON.parse(localStorage.getItem('pav-user-presets')) || []; } catch (e) { return []; } };
const saveUser = list => { try { localStorage.setItem('pav-user-presets', JSON.stringify(list)); } catch (e) { } };
// Save all current look values so receiver defaults cannot alter the look.
const diffOf = st => PresetCodec.browser(PresetCodec.decode(PresetCodec.encode('Saved look', st, LOOK_DEFAULTS, true), LOOK_DEFAULTS, false).settings);

function renderUserPresets(el) {
  el.innerHTML = `<div class="pp-grid"></div>
    <div class="saverow"><input placeholder="Name this look…" maxlength="32" aria-label="Preset name"><button class="primary" data-save>Save current</button></div>
    <div class="saverow"><button class="ghost" data-export>Copy current as JSON</button><button class="ghost" data-import>Import JSON…</button></div>`;
  const grid = $('.pp-grid', el), name = $('input', el);
  let builtFor = '';
  const list = () => loadUser().map(u => ({ ...u, bd: 'breeze', cat: ['mine'] }));
  const find = id => list().find(u => u.id === id);
  $('[data-save]', el).onclick = () => {
    const all = loadUser(), n = name.value.trim() || `My look ${all.length + 1}`;
    all.push({ id: 'u' + Date.now().toString(36), name: n, s: diffOf(S) });
    saveUser(all);
    name.value = ''; activePreset = all[all.length - 1].id; presetDirty = false;
    syncSettings(); toast(`Saved “${n}”`);
  };
  name.onkeydown = e => { if (e.key === 'Enter') $('[data-save]', el).click(); };
  $('[data-export]', el).onclick = async () => {
    const txt = PresetCodec.encode(name.value.trim() || 'Shared look', S, LOOK_DEFAULTS, true);
    try { await navigator.clipboard.writeText(txt); toast('Look copied as JSON'); } catch (e) { prompt('Copy this JSON', txt); }
  };
  $('[data-import]', el).onclick = () => {
    const txt = prompt('Paste a look (JSON)'); if (!txt) return;
    try {
      const o = PresetCodec.decode(txt, LOOK_DEFAULTS, true), all = loadUser();
      const u = { id: 'u' + Date.now().toString(36), name: o.name || 'Imported look', s: o.settings };
      all.push(u); saveUser(all); applyPreset(u);
    } catch (e) { toast(e.message || 'That is not a valid look'); }
  };
  grid.addEventListener('click', e => {
    const del = e.target.closest('[data-del]');
    if (del) { e.stopPropagation(); saveUser(loadUser().filter(u => u.id !== del.dataset.del)); syncSettings(); return; }
    const t = e.target.closest('[data-pid]'); if (t) applyPreset(find(t.dataset.pid));
  });
  activateOnKey(grid, find);
  return () => {
    const L = list(), want = L.map(u => u.id).join() + ':' + playerRev;
    if (builtFor !== want) { builtFor = want; fillGrid(grid, L, 'mine-', u => `<button class="del" data-del="${u.id}" aria-label="Delete ${esc(u.name)}">×</button>`); }
    $$('[data-pid]', grid).forEach(t => t.setAttribute('aria-pressed', t.dataset.pid === activePreset && !presetDirty));
  };
}

/* ─── settings schema ──────────────────────────────────────────── */
PROPOSED.pillEq.vals = 'off · static · live · wave (mini visualizer) — static costs no frames at all';
const TABS = StudioCatalog.tabs.filter(tab => !tab.nativeOnly).map(tab => ({ ...tab, ic: `<path d="${tab.icon}"/>` }));
const pct = v => Math.round(v * 100) + '%';
const DIAG = {
  classic: '<rect x="4" y="5" width="15" height="15" rx="3" class="f"/><rect x="4" y="23" width="15" height="7" rx="3.5" class="o"/><path d="M24 10q3-4 6 0t6 0 6 0 6 0 6 0" class="s"/><rect x="24" y="17" width="36" height="1.6" rx=".8" class="f2"/><rect x="24" y="22" width="26" height="3" rx="1" class="f"/><rect x="24" y="28" width="16" height="2" rx="1" class="f2"/>',
  mirrored: '<rect x="45" y="5" width="15" height="15" rx="3" class="f"/><rect x="45" y="23" width="15" height="7" rx="3.5" class="o"/><path d="M4 10q3-4 6 0t6 0 6 0 6 0 6 0" class="s"/><rect x="4" y="17" width="36" height="1.6" rx=".8" class="f2"/><rect x="14" y="22" width="26" height="3" rx="1" class="f"/><rect x="24" y="28" width="16" height="2" rx="1" class="f2"/>',
  inline: '<rect x="4" y="5" width="24" height="26" rx="4" class="f"/><rect x="33" y="6" width="22" height="3" rx="1" class="f"/><rect x="33" y="11" width="14" height="2" rx="1" class="f2"/><path d="M33 19q2.5-4 5 0t5 0 5 0 5 0 5 0" class="s"/><rect x="33" y="27" width="14" height="1.6" rx=".8" class="f2"/><rect x="49" y="24.5" width="11" height="6" rx="3" class="o"/>',
  hero: '<path d="M6 11q4-8 8 0t8 0 8 0 8 0 8 0 8 0" class="s"/><rect x="6" y="19" width="52" height="1.6" rx=".8" class="f2"/><rect x="6" y="24" width="8" height="8" rx="2" class="f"/><rect x="17" y="25" width="20" height="2.6" rx="1" class="f"/><rect x="17" y="29" width="12" height="2" rx="1" class="f2"/><rect x="46" y="24.5" width="12" height="7" rx="3.5" class="o"/>',
  stacked: '<rect x="14" y="3" width="10" height="10" rx="2" class="f"/><rect x="27" y="4" width="22" height="3.4" rx="1" class="f"/><rect x="27" y="9.5" width="14" height="2" rx="1" class="f2"/><path d="M14 18q3-4 6 0t6 0 6 0 6 0 6 0" class="s"/><rect x="14" y="25" width="36" height="1.4" rx=".7" class="f2"/><rect x="26" y="28.5" width="12" height="5.5" rx="2.75" class="o"/>',
  strip: '<rect x="3" y="12" width="58" height="12" rx="6" class="o"/><circle cx="10" cy="18" r="3.6" class="f"/><rect x="16" y="15.5" width="14" height="2.4" rx="1" class="f"/><rect x="16" y="19.5" width="9" height="1.6" rx=".8" class="f2"/><path d="M33 18h2v-3h2v5h2v-6h2v5h2v-2h2v2h2" class="s" style="stroke-width:1"/><path d="m52 16 3 2-3 2z" class="f"/>',
  pill: '<rect x="1" y="11" width="62" height="14" rx="3" class="f2"/><rect x="14" y="13.5" width="36" height="9" rx="4.5" class="o" style="opacity:1"/><rect x="16.5" y="15" width="6" height="6" rx="1.5" class="f"/><rect x="25" y="16.8" width="14" height="2.4" rx="1" class="f"/><rect x="41" y="16.8" width="6" height="2.4" rx="1" class="f2"/>',
  pillicon: '<rect x="1" y="11" width="62" height="14" rx="3" class="f2"/><circle cx="32" cy="18" r="4.4" class="f"/><circle cx="32" cy="18" r="6" fill="none" stroke="var(--brand)" stroke-width="1.2" stroke-dasharray="24 40"/>',
  poster: '<path d="M8 27V21M12 27V15M16 27V19M20 27V12M24 27V17M28 27V14M32 27V20M36 27V13M40 27V18M44 27V16M48 27V21M52 27V17M56 27V22" class="s" style="opacity:.3;stroke-width:2.2"/><rect x="8" y="7" width="20" height="1.8" rx=".9" class="f2"/><rect x="8" y="11" width="42" height="7" rx="1.5" class="f"/><rect x="8" y="26" width="34" height="1.4" rx=".7" class="f2"/><rect x="46" y="24" width="10" height="4.4" rx="1" class="f"/>',
  orbit: '<circle cx="32" cy="14" r="5.5" class="f"/>' + Array.from({ length: 16 }, (_, i) => {
    const a = i / 16 * Math.PI * 2, l = 2 + (i * 7 % 5) * .7, p = r => `${(32 + Math.cos(a) * r).toFixed(1)} ${(14 + Math.sin(a) * r).toFixed(1)}`;
    return `<path d="M${p(8)}L${p(8 + l)}" class="s" style="stroke-width:1.2"/>`;
  }).join('') + '<rect x="24" y="28" width="16" height="2.4" rx="1" class="f"/><rect x="27" y="32" width="10" height="1.8" rx=".9" class="f2"/>',
  compact: '<path d="M16 10q2.5-4 5 0t5 0 5 0 5 0 5 0 5 0" class="s"/><rect x="16" y="17" width="32" height="1.6" rx=".8" class="f2"/><rect x="16" y="22" width="22" height="3" rx="1" class="f"/><rect x="16" y="28" width="14" height="2" rx="1" class="f2"/>',
  lyrics: '<rect x="10" y="6" width="44" height="2.4" rx="1" class="f2"/><rect x="10" y="13" width="36" height="3" rx="1.2" class="f"/><rect x="10" y="20" width="44" height="2.4" rx="1" class="f2"/><rect x="10" y="27" width="26" height="2" rx="1" class="f2"/>',
};
const diag = k => `<svg class="diag" viewBox="0 0 64 36" aria-hidden="true">${DIAG[k]}</svg>`;
const SWATCHES = ['#3daee9', '#a855f7', '#ff6fb0', '#f5b26b', '#d1e5bd', '#34d399', '#ffffff', '#1e241d'];
const BGSWATCHES = ['#0a0b10', '#1b1e21', '#231a33', '#10231d', '#2b1d14', '#f4f1ea'];
const notPill = s => !isPill(s);

function platformNote(topic) {
  const kde = env === 'kde';
  const who = kde ? 'On Plasma' : 'On Hyprland';
  const L = { y: '<span class="ok">works</span>', p: '<span class="warn">partly</span>', n: '<span class="no">not really</span>' };
  let body;
  if (topic === 'card') {
    const m = S.showBg ? S.surfaceStyle : 'none';
    if (m === 'glass') body = kde ? `Blur ${L.p}: KWin only blurs behind surfaces that ask for it. A <code>NoBackground</code> desktop widget gets none, so the widget would blur a copy of the wallpaper itself.` : `Blur ${L.y} with a blur layer rule on <code>audio-wave-visualizer</code>. On the Bottom layer every widget frame re-blurs the whole monitor (~3 W measured) — use a low frame rate.`;
    else if (m === 'liquid') body = kde ? `Refraction ${L.p}: on the desktop, sample the wallpaper image in a ShaderEffect — convincing with static wallpapers. Over windows or panels it needs a KWin effect plugin (C++).` : `Blur ${L.y} via layer rule; true refraction needs a Hyprland plugin shader. Rim light, specular and tint are plain QML and work everywhere.`;
    else if (m === 'art' || m === 'atmosphere' || m === 'solid' || m === 'color') body = `${L.y} — pure QML, identical on Plasma and Hyprland, no compositor help, cheapest option.`;
    else body = `No card: nothing to composite, ${L.y} everywhere.`;
  } else if (topic === 'pill') {
    body = kde ? `${L.y}: a <code>compactRepresentation</code> used when <code>formFactor</code> is a panel; clicking opens the full card as the popup, just like the AI-usage widget's panel slot.` : `${L.p}: Hyprland has no shared panel API. Either ship a small Quickshell bar module, or a <code>--waybar</code> mode printing JSON for a custom module (text + cover, no animation).`;
  } else {
    body = kde ? `Plasma places desktop widgets by dragging them in edit mode and panel widgets inside the panel, so these Hyprland-only options stay hidden there. The desktop settings page exposes placement options on Hyprland.` : `Uses the existing Hyprland shell keys (<code>monitor</code>, <code>verticalPosition</code>, <code>desktopLayer</code>, <code>pauseWhenCovered</code>) plus a proposed horizontal anchor. Click a spot on the screen.`;
  }
  return `<div class="note"><i>◇</i><div><b>${who}</b> — ${body}</div></div>`;
}

const SECTIONS = [
  { tab: 'presets', title: 'Looks', rows: [
    { id: 'pick', type: 'custom', full: true, isNew: true, label: 'Start from a look', desc: 'One click sets everything. Fine-tune in the other tabs afterwards — your placement is never touched.', render: renderPresetPicker },
  ] },
  { tab: 'saved', title: 'My presets', rows: [
    { id: 'mine', type: 'custom', full: true, isNew: true, label: 'Saved looks', desc: 'Save the current settings under a name, or share a look as a small JSON snippet.', render: renderUserPresets },
  ] },
  { tab: 'viz', title: 'Orbit around the cover', when: s => s.layoutMode === 'orbit', rows: [
    { k: 'orbitStyle', type: 'tiles', full: true, isNew: true, label: 'Ring style', desc: 'The cover is the centre point and the visualizer circles it. Colour mode, glow and bloom below still apply.', tw: 92,
      opts: ORBITS.map((l, i) => ({ v: l.toLowerCase(), label: l, pv: `<canvas class="orb" data-c="orbit" data-i="${i}" data-r=".36"></canvas><i class="art circle" style="--a:16px"></i>` })) },
    { k: 'orbitReach', type: 'range', isNew: true, label: 'Reach', desc: 'How far the ring extends from the cover.', min: .5, max: 1.3, step: .05, fmt: pct },
    { k: 'orbitRotate', type: 'switch', isNew: true, label: 'Slow rotation' },
    { k: 'orbitCoverPulse', type: 'switch', isNew: true, label: 'Cover breathes with the bass' },
  ] },
  { tab: 'viz', title: 'Style', rows: [
    { k: 'visualizerType', type: 'tiles', full: true, when: s => s.layoutMode !== 'orbit', label: 'Visualizer', desc: 'Previews react to your colour, line and bloom settings.', tw: 104, opts: VIZ.map((l, i) => ({ v: i, label: l, isNew: i >= 6, pv: `<canvas data-c="wave" data-i="${i}"></canvas>` })) },
    { k: 'vizDirection', type: 'seg', isNew: true, label: 'Direction', desc: 'Bars rise from the bottom today — or let them hang from the top edge.', opts: [['up', 'Rise from bottom'], ['down', 'Hang from top']], when: s => [1, 6, 7, 8].includes(s.visualizerType) && s.layoutMode !== 'orbit' },
    { k: 'ribbonCurvature', type: 'range', isNew: true, label: 'Ribbon curvature', desc: 'How far the mids bend the ribbon.', min: .5, max: 1.25, step: .05, fmt: pct, when: s => s.visualizerType === 15 },
    { k: 'ribbonFullness', type: 'range', isNew: true, label: 'Ribbon fullness', desc: 'How thick the bass makes it.', min: .6, max: 1.3, step: .05, fmt: pct, when: s => s.visualizerType === 15 },
    { k: 'lineWidth', type: 'range', label: 'Line weight', desc: 'Stroke width of lines and dot size.', min: 1, max: 8, step: .2, fmt: v => v.toFixed(1) },
    { k: 'fillWave', type: 'switch', label: 'Gradient fill', desc: 'Transparent fill under the wave and bars.' },
  ] },
  { tab: 'controls', title: 'Progress bar', rows: [
    { k: 'progressBarStyle', type: 'tiles', full: true, label: 'Style', desc: 'Click anywhere on it in the widget to seek.', tw: 104, opts: PBS.map((l, i) => ({ v: i, label: l, isNew: i >= 5,
      pv: i === 10 ? '<div class="artwrap" style="--a:32px"><div class="art" style="--a:32px"></div><i class="rg"></i></div>' : `<div class="pbwrap">${pbHTML(i, { showTimes: true, timeFormat: 'total' }, i === 0 || i === 2, 238, .58)}</div>` })) },
    { k: 'showTimes', type: 'switch', isNew: true, label: 'Time labels', desc: 'Elapsed and total time under the bar.' },
    { k: 'timeFormat', type: 'seg', isNew: true, label: 'Time format', opts: [['total', '1:31 · 3:58'], ['remaining', '1:31 · -2:27']], when: s => s.showTimes || s.progressBarStyle === 9 },
  ] },
  { tab: 'controls', title: 'Buttons', rows: [
    { k: 'dockStyle', type: 'tiles', full: true, isNew: true, label: 'Dock style', desc: 'The glass pill is today’s look.', tw: 118, opts: [
      { v: 'glass', label: 'Glass pill', pv: 'dock' }, { v: 'bare', label: 'Bare icons', isNew: true, pv: 'dock' },
      { v: 'accent', label: 'Accent play', isNew: true, pv: 'dock' }, { v: 'hover', label: 'On hover', isNew: true, pv: 'dock' }] },
    { k: 'showSkipButtons', type: 'switch', isNew: true, label: 'Previous & next' },
    { k: 'showShuffleRepeat', type: 'switch', isNew: true, label: 'Shuffle & repeat', desc: 'For players that support them.' },
  ] },
  { tab: 'layout', title: 'Arrangement', rows: [
    { k: 'layoutMode', type: 'tiles', full: true, label: 'Layout', desc: 'Pill layouts show up inside a panel on the stage.', tw: 104, opts: [
      { v: 'classic', label: 'Classic', pv: diag('classic') }, { v: 'mirrored', label: 'Mirrored', isNew: true, pv: diag('mirrored') },
      { v: 'inline', label: 'Inline', isNew: true, pv: diag('inline') }, { v: 'hero', label: 'Hero wave', isNew: true, pv: diag('hero') },
      { v: 'stacked', label: 'Stacked', isNew: true, pv: diag('stacked') }, { v: 'orbit', label: 'Orbit', isNew: true, pv: diag('orbit') }, { v: 'poster', label: 'Poster', isNew: true, pv: diag('poster') }, { v: 'strip', label: 'Slim strip', isNew: true, pv: diag('strip') },
      { v: 'lyrics', label: 'Lyrics only', isNew: true, pv: diag('lyrics') },
      { v: 'pill', label: 'Panel pill', isNew: true, pv: diag('pill') }, { v: 'pillicon', label: 'Panel icon', isNew: true, pv: diag('pillicon') },
      { v: 'compact', label: 'No art', pv: diag('compact') }] },
  ] },
  { tab: 'layout', title: 'Lyrics only', when: s => s.layoutMode === 'lyrics', rows: [
    { id: 'lyricsNote', type: 'note', full: true, label: '', html: () => '<div class="note"><i>◇</i><div><b>Sample verses</b> — the widget syncs real lines from LRCLIB; this browser demo just cycles the four sample lines above every 5 seconds.</div></div>' },
    { k: 'lyricsAlign', type: 'seg', isNew: true, label: 'Alignment', opts: [['left', 'Left'], ['center', 'Centre'], ['right', 'Right']] },
    { k: 'lyricsShowHeader', type: 'switch', isNew: true, label: 'Song title and artist' },
    { k: 'lyricsWidth', type: 'range', isNew: true, label: 'Preferred width', desc: 'Desktop hosts can override this by resizing the widget.', min: 240, max: 900, step: 10, fmt: v => v + ' px' },
    { k: 'lyricsHeight', type: 'range', isNew: true, label: 'Preferred height', min: 180, max: 800, step: 10, fmt: v => v + ' px' },
    { k: 'lyricsFontSize', type: 'range', isNew: true, label: 'Font size', min: 12, max: 48, step: 1, fmt: v => v + ' px' },
    { k: 'lyricsHighlight', type: 'seg', isNew: true, label: 'Current line colour', opts: [['text', 'Text'], ['accent', 'Accent'], ['custom', 'Custom']] },
    { k: 'lyricsHighlightColor', type: 'color', isNew: true, label: 'Highlight colour', swatches: SWATCHES, when: s => s.lyricsHighlight === 'custom' },
    { k: 'lyricsPastOpacity', type: 'range', isNew: true, label: 'Past lines', min: .1, max: 1, step: .05, fmt: pct },
    { k: 'lyricsFutureOpacity', type: 'range', isNew: true, label: 'Upcoming lines', min: .1, max: 1, step: .05, fmt: pct },
  ] },
  { tab: 'layout', title: 'Panel pill', when: isPill, rows: [
    { id: 'pillNote', type: 'note', full: true, label: '', html: () => platformNote('pill') },
    { k: 'pillContent', type: 'seg', isNew: true, label: 'Text', opts: [['title', 'Title'], ['title-artist', 'Title · Artist'], ['artist-title', 'Artist — Title']], when: s => s.layoutMode === 'pill' },
    { k: 'pillArt', type: 'switch', isNew: true, label: 'Cover thumbnail', when: s => s.layoutMode === 'pill' },
    { k: 'pillEq', type: 'seg', isNew: true, label: 'Motion', desc: 'Static bars cost no frames at all — the cleanest choice for a panel.', opts: [['off', 'Off'], ['static', 'Static'], ['live', 'Bouncing'], ['wave', 'Mini visualizer']] },
    { k: 'pillProgress', type: 'seg', isNew: true, label: 'Progress', opts: [['off', 'Off'], ['underline', 'Underline'], ['ring', 'Cover ring']] },
    { k: 'pillControls', type: 'seg', isNew: true, label: 'Buttons', opts: [['none', 'None'], ['play', 'Play'], ['all', 'All']], when: s => s.layoutMode === 'pill' },
    { k: 'pillMaxWidth', type: 'range', isNew: true, label: 'Maximum width', min: 140, max: 420, step: 10, fmt: v => v + ' px', when: s => s.layoutMode === 'pill' },
    { k: 'pillClick', type: 'seg', isNew: true, label: 'Click', opts: [['popup', 'Open card'], ['toggle', 'Play / pause']] },
    { k: 'autoPillInPanel', type: 'switch', isNew: true, label: 'Pill automatically in panels', desc: 'Plasma: the desktop keeps your card layout, panels get the pill.' },
  ] },
  { tab: 'layout', title: 'Poster', when: s => s.layoutMode === 'poster', rows: [
    { k: 'posterAlign', type: 'seg', isNew: true, label: 'Alignment', opts: [['left', 'Left'], ['center', 'Centre']] },
    { k: 'posterLines', type: 'seg', isNew: true, label: 'Title lines', desc: 'Let long titles wrap onto a second line.', opts: [[1, 'One'], [2, 'Two']] },
    { k: 'posterVizBehind', type: 'switch', isNew: true, label: 'Visualizer behind the title', desc: 'A soft texture under the text; style and direction follow the Visualizer tab.' },
    { k: 'posterVizOpacity', type: 'range', isNew: true, label: 'Texture strength', min: .1, max: .8, step: .05, fmt: pct, when: s => s.posterVizBehind },
    { k: 'posterClock', type: 'switch', isNew: true, label: 'Large clock', desc: 'Elapsed time set big beside the progress line.' },
    { k: 'showAlbum', type: 'switch', isNew: true, label: 'Album in the top line' },
  ] },
  { tab: 'layout', title: 'Track text', when: notPill, rows: [
    { k: 'titleSize', type: 'range', isNew: true, label: 'Text size', desc: 'Artist and album follow the title.', min: 9, max: 16, step: 1, fmt: v => v + ' px' },
    { k: 'textAlign', type: 'seg', isNew: true, label: 'Alignment', opts: [['left', 'Left'], ['center', 'Centre'], ['right', 'Right']] },
    { k: 'marquee', type: 'switch', isNew: true, label: 'Scroll long titles', desc: 'Try the Long title state.' },
  ] },
  { tab: 'art', title: 'Cover', rows: [
    { k: 'showArtThumb', type: 'switch', label: 'Show artwork', desc: 'Falls back to the player’s icon when a track has no cover.', disabled: s => s.layoutMode === 'compact' || s.layoutMode === 'lyrics' },
    { k: 'artShape', type: 'tiles', full: true, isNew: true, label: 'Shape', desc: 'Vinyl and CD spin while music plays.', tw: 84, opts: [
      { v: 'sharp', label: 'Sharp', isNew: true }, { v: 'rounded', label: 'Rounded' }, { v: 'squircle', label: 'Squircle', isNew: true },
      { v: 'circle', label: 'Circle', isNew: true }, { v: 'vinyl', label: 'Vinyl', isNew: true }, { v: 'cd', label: 'CD', isNew: true }].map(o => ({ ...o, pv: `<div class="art ${o.v} ${['vinyl', 'cd'].includes(o.v) ? 'spin' : ''}" style="--a:36px"></div>` })) },
    { k: 'artScale', type: 'range', isNew: true, label: 'Size', desc: 'Capped by the layout height.', min: 60, max: 130, step: 5, fmt: v => v + '%', when: notPill },
    { k: 'artBorder', type: 'seg', isNew: true, label: 'Border', opts: [['none', 'None'], ['subtle', 'Subtle'], ['accent', 'Accent']] },
  ] },
  { tab: 'art', title: 'Effects', rows: [
    { k: 'artGlow', type: 'switch', isNew: true, label: 'Colour glow', desc: 'A shadow tinted with the cover’s own colour.' },
    { k: 'artTilt', type: 'switch', isNew: true, label: '3D tilt on hover' },
    { k: 'artReflect', type: 'switch', isNew: true, label: 'Reflection', desc: 'A faint mirror image under the cover.', when: notPill },
    { k: 'artGrayPaused', type: 'switch', isNew: true, label: 'Greyscale while paused' },
  ] },
  { tab: 'art', title: 'When there is no cover', rows: [
    { k: 'artFallback', type: 'seg', isNew: true, label: 'Placeholder', desc: 'Try the “No metadata” state.', opts: [['icon', 'Player icon'], ['gradient', 'Gradient'], ['letters', 'Initials']] },
    { k: 'artClick', type: 'seg', isNew: true, label: 'Clicking the cover', opts: [['none', 'Nothing'], ['zoom', 'Show large'], ['raise', 'Open player']] },
  ] },
  { tab: 'info', title: 'On the card', rows: [
    { k: 'showAlbum', type: 'switch', isNew: true, label: 'Album name', desc: 'A quiet third line with album and year.', when: notPill },
    { k: 'showSource', type: 'switch', isNew: true, label: 'Player name', desc: 'Where the music is coming from.', when: notPill },
    { k: 'showPlayerSwitch', type: 'switch', isNew: true, label: 'Player switcher', desc: 'Pick which of several running players the widget follows.', when: notPill },
    { k: 'showLyrics', type: 'switch', isNew: true, label: 'Synced lyrics line', desc: 'Online lookup (LRCLIB), off by default. Sample lyrics here — for a full verse, choose the Lyrics only layout.' },
  ] },
  { tab: 'info', title: 'On hover', rows: [
    { k: 'hoverDetails', type: 'seg', isNew: true, label: 'Details', desc: 'Extra track information without making the card bigger.', opts: [['off', 'Off'], ['tooltip', 'Tooltip'], ['drawer', 'Drawer'], ['flip', 'Flip card']] },
    { k: 'detailFields', type: 'chips', full: true, isNew: true, label: 'Show', when: s => s.hoverDetails !== 'off',
      opts: [['album', 'Album & year'], ['track', 'Track number'], ['genre', 'Genre'], ['length', 'Length'], ['format', 'Audio format'], ['player', 'Player'], ['volume', 'Volume']] },
  ] },
  { tab: 'card', title: 'Background', rows: [
    { k: 'showBg', type: 'switch', label: 'Show a card', desc: 'Off: the widget floats directly on the wallpaper (current default).' },
    { k: 'surfaceStyle', type: 'tiles', full: true, label: 'Material', tw: 84, when: s => s.showBg, opts: [
      { v: 'color', label: 'Tint', pv: '<i class="sp sp-color"></i>' }, { v: 'art', label: 'Cover', pv: '<i class="sp sp-art"></i>' },
      { v: 'glass', label: 'Glass', isNew: true, pv: '<i class="sp sp-glass"></i>' }, { v: 'liquid', label: 'Liquid', isNew: true, pv: '<i class="sp sp-liquid"></i>', onbd: true },
      { v: 'solid', label: 'Solid', isNew: true, pv: '<i class="sp sp-solid"></i>' }, { v: 'atmosphere', label: 'Atmosphere', isNew: true, pv: '<i class="sp sp-atmosphere"></i>' }] },
    { id: 'cardNote', type: 'note', full: true, label: '', html: () => platformNote('card'), when: s => s.showBg },
    { k: 'bgColor', type: 'color', label: 'Tint colour', swatches: BGSWATCHES, when: s => s.showBg && s.surfaceStyle === 'color' },
    { k: 'artBgBlur', type: 'range', label: 'Cover blur', desc: '0 keeps the art crisp.', min: 0, max: 1, step: .02, fmt: pct, when: s => s.showBg && s.surfaceStyle === 'art' },
    { k: 'artBgDim', type: 'range', label: 'Cover darkness', desc: 'Keeps text readable on bright covers.', min: 0, max: 1, step: .02, fmt: pct, when: s => s.showBg && s.surfaceStyle === 'art' },
    { k: 'artBgKeepThumb', type: 'switch', label: 'Keep sharp thumbnail', when: s => s.showBg && s.surfaceStyle === 'art', disabled: s => !s.showArtThumb || s.layoutMode === 'compact' },
    { k: 'artBgTransparency', type: 'range', label: 'Card opacity', desc: 'Only the card fades; text and wave stay solid.', min: 0, max: 1, step: .02, fmt: pct, when: s => s.showBg },
    { k: 'bgRadius', type: 'range', label: 'Corner radius', min: 0, max: 30, step: 1, fmt: v => v + ' px', when: s => s.showBg && notPill(s) },
  ] },
  { tab: 'card', title: 'Liquid glass', when: s => s.showBg && s.surfaceStyle === 'liquid', rows: [
    { k: 'glassTint', type: 'seg', isNew: true, label: 'Tint', opts: [['clear', 'Clear'], ['frost', 'Frost'], ['cover', 'Cover colour']] },
    { k: 'glassRefraction', type: 'range', isNew: true, label: 'Refraction', desc: 'How strongly the edges bend what is behind (Chromium preview).', min: 0, max: 1, step: .05, fmt: pct },
    { k: 'glassSpecular', type: 'switch', isNew: true, label: 'Light follows pointer', desc: 'A soft specular highlight tracks the mouse.' },
  ] },
  { tab: 'card', title: 'Depth & finish', when: s => s.showBg, rows: [
    { k: 'cardShadow', type: 'seg', isNew: true, label: 'Shadow', opts: [['none', 'None'], ['soft', 'Soft'], ['lifted', 'Lifted']] },
    { k: 'edgeHighlight', type: 'switch', isNew: true, label: 'Edge highlight', desc: 'A thin line of light along the top edge.' },
    { k: 'grain', type: 'switch', isNew: true, label: 'Film grain', desc: 'Stops gradients from banding.' },
    { k: 'bassPulse', type: 'switch', isNew: true, label: 'Bass pulse', desc: 'The edge glows in the accent colour on every kick.' },
  ] },
  { tab: 'colors', title: 'Accent', rows: [
    { id: 'waveSrc', type: 'seg', label: 'Accent colour', desc: 'Drives the wave, progress and play button. System follows your desktop accent; the stage dots choose a custom colour.',
      opts: [['system', 'System'], ['art', 'From cover', true], ['custom', 'Custom']],
      get: s => s.accentFromArt ? 'art' : s.useSystemAccent ? 'system' : 'custom',
      set: v => ({ accentFromArt: v === 'art', useSystemAccent: v !== 'custom' }) },
    { k: 'customColor', type: 'color', label: 'Custom colour', swatches: SWATCHES, when: s => !s.accentFromArt && !s.useSystemAccent },
  ] },
  { tab: 'colors', title: 'Visualizer colour & light', rows: [
    { k: 'vizColorMode', type: 'seg', isNew: true, label: 'Colour mode', desc: 'Solid uses the accent selected above.', opts: [['solid', 'Solid'], ['gradient', 'Gradient', 1], ['cover', 'Cover', 1], ['palette', 'Palette', 1], ['rainbow', 'Rainbow', 1]] },
    { k: 'vizPalette', type: 'tiles', full: true, isNew: true, label: 'Palette', desc: 'Curated palettes with bounded hues, so they never turn muddy.', tw: 84, when: s => s.vizColorMode === 'palette',
      opts: Object.entries(PALETTES).map(([k, c]) => ({ v: k, label: k[0].toUpperCase() + k.slice(1), pv: `<i class="sp" style="border:0;background:linear-gradient(90deg,${c.join(',')})"></i>` })) },
    { k: 'hueReactive', type: 'switch', isNew: true, label: 'Music-reactive hue', desc: 'Colours drift slowly with the bass / treble balance.', when: s => !['solid', 'rainbow'].includes(s.vizColorMode) || true },
    { k: 'glowWave', type: 'switch', label: 'Glow', desc: 'Soft light around the visualizer.' },
    { k: 'bloom', type: 'range', isNew: true, label: 'Bloom', desc: 'How far the glow spreads.', min: 0, max: 1.5, step: .05, fmt: pct, when: s => s.glowWave },
  ] },
  { tab: 'colors', title: 'Text & controls', rows: [
    { id: 'textSrc', type: 'seg', label: 'Text colour', opts: [[true, 'System'], [false, 'Custom']], get: s => s.useSystemText, set: v => ({ useSystemText: v }) },
    { k: 'customTextColor', type: 'color', label: 'Custom text colour', swatches: SWATCHES, when: s => !s.useSystemText },
    { k: 'autoContrast', type: 'switch', isNew: true, label: 'Adapt to light cards', desc: 'Dark text and icons on the Solid material.', when: s => s.useSystemText || s.useSystemControls },
    { id: 'ctlSrc', type: 'seg', label: 'Controls colour', desc: 'Buttons, knob and playhead.', opts: [[true, 'System'], [false, 'Custom']], get: s => s.useSystemControls, set: v => ({ useSystemControls: v }) },
    { k: 'customControlColor', type: 'color', label: 'Custom controls colour', swatches: SWATCHES, when: s => !s.useSystemControls },
    { id: 'dockSrc', type: 'seg', label: 'Dock background', opts: [[true, 'Glass'], [false, 'Custom']], get: s => s.useSystemDockBg, set: v => ({ useSystemDockBg: v }) },
    { k: 'customDockBgColor', type: 'color', label: 'Custom dock colour', swatches: SWATCHES, when: s => !s.useSystemDockBg },
  ] },
  { tab: 'behavior', title: 'When nothing plays', rows: [
    { k: 'alwaysVisible', type: 'switch', label: 'Keep visible', desc: 'Off hides the widget until a player appears. Try the “Nothing playing” state.' },
    { k: 'idleText', type: 'switch', isNew: true, label: 'Friendly idle message', when: s => s.alwaysVisible },
    { k: 'idleAmbient', type: 'switch', isNew: true, label: 'Ambient idle wave', desc: 'A slow, quiet movement instead of a flat line.', when: s => s.alwaysVisible },
  ] },
  { tab: 'behavior', title: 'When paused', rows: [
    { k: 'dimWhenPaused', type: 'switch', isNew: true, label: 'Dim the widget' },
    { k: 'fadeVizWhenPaused', type: 'switch', isNew: true, label: 'Fade the visualizer' },
  ] },
  { tab: 'behavior', title: 'Interaction', rows: [
    { k: 'hoverLift', type: 'switch', isNew: true, label: 'Lift on hover' },
    { k: 'scrollVolume', type: 'switch', isNew: true, label: 'Scroll to change volume', desc: 'Sets the player’s own volume, not the system’s.' },
  ] },
  { tab: 'behavior', title: 'Comfort & power', rows: [
    { k: 'reducedMotion', type: 'switch', isNew: true, label: 'Reduced motion', desc: 'No ripples, sweeps, spins or scrolling text; the wave still reacts.' },
    { k: 'batterySaver', type: 'switch', isNew: true, label: 'Battery saver', desc: 'On battery: 20 Hz and no glow. Simulated here.' },
    { k: 'simpleRender', type: 'switch', isNew: true, label: 'Simple rendering', desc: 'Lightweight Canvas path — also the automatic fallback if shaders fail.' },
  ] },
  { tab: 'behavior', title: 'Position', when: () => env === 'hypr', rows: [
    { id: 'placeNote', type: 'note', full: true, label: '', html: () => platformNote('place') },
    { id: 'anchor', type: 'custom', full: true, isNew: true, isHypr: true, label: 'Screen position', render: renderAnchor, when: () => env === 'hypr' },
    { k: 'verticalPosition', type: 'range', isHypr: true, label: 'Vertical position', min: 0, max: 1, step: .01, fmt: pct, when: () => env === 'hypr' },
    { k: 'monitor', type: 'select', isHypr: true, label: 'Monitor', opts: [['', 'Primary'], ['all', 'Every monitor'], ['DP-1', 'DP-1'], ['eDP-1', 'eDP-1']], when: () => env === 'hypr' },
    { k: 'desktopLayer', type: 'seg', isHypr: true, label: 'Layer', opts: [[true, 'Behind windows'], [false, 'Above windows']], when: () => env === 'hypr' },
    { k: 'pauseWhenCovered', type: 'switch', isHypr: true, label: 'Pause when covered', desc: 'Stops drawing while a window hides the widget — saves real power.', when: s => env === 'hypr' && s.desktopLayer },
  ] },
  { tab: 'audio', title: 'Connection', rows: [
    { id: 'diag', type: 'custom', full: true, label: 'Status', isNew: true, render: renderDiag },
  ] },
  { tab: 'audio', title: 'Capture', rows: [
    { k: 'inputMethod', type: 'select', label: 'Audio input', desc: 'Auto-detect tries PipeWire, then PulseAudio, then ALSA.', opts: [['auto', 'Auto-detect'], ['pipewire', 'PipeWire'], ['pulse', 'PulseAudio'], ['alsa', 'ALSA (snd_aloop)']] },
    { k: 'numBars', type: 'range', label: 'Detail', desc: 'More bars look finer, fewer look bolder.', min: 8, max: 128, step: 2, fmt: v => v + ' bars' },
    { k: 'sensitivity', type: 'range', label: 'Sensitivity', desc: 'Raise it if quiet music barely moves the wave.', min: 10, max: 300, step: 5, fmt: v => v + '%' },
    { k: 'noiseReduction', type: 'range', label: 'Smoothing', desc: 'Higher glides gently; lower snaps to every beat.', min: 0, max: 1, step: .05, fmt: v => v.toFixed(2) },
    { k: 'framerate', type: 'range', label: 'Frame rate', desc: 'Lower saves power. 30 Hz already looks smooth.', min: 15, max: 144, step: 5, fmt: v => v + ' Hz' },
  ] },
];

function renderAnchor(el) {
  const spots = [];
  for (const v of [.08, .5, .92]) for (const h of ['left', 'center', 'right']) spots.push([h, v]);
  el.innerHTML = `<div class="monitor"><div class="anch">${spots.map(([h, v], i) => `<button data-i="${i}" aria-label="${h} ${v}"><span></span></button>`).join('')}</div></div>`;
  const btns = $$('button', el);
  btns.forEach(b => b.onclick = () => { const [h, v] = spots[b.dataset.i]; update({ hAnchor: h, verticalPosition: v }); });
  return s => btns.forEach(b => { const [h, v] = spots[b.dataset.i]; b.setAttribute('aria-pressed', s.hAnchor === h && Math.abs(s.verticalPosition - v) < .21); });
}
function renderDiag(el) {
  el.innerHTML = `<div class="status"><span class="livedot"></span><div><b>Capturing system audio</b><span>PipeWire monitor · <span data-hz>30</span> Hz · 0 dropped blocks · Spotify connected</span></div><button class="ghost" data-run>Run diagnostics</button></div><div class="diagcard" hidden></div>`;
  $('[data-run]', el).onclick = () => {
    const list = $('.diagcard', el); list.hidden = false; list.innerHTML = '';
    [['cava found', '/usr/bin/cava'], ['Audio input', 'pipewire · 48 kHz'], ['Media player', 'org.mpris.MediaPlayer2.spotify'], ['Renderer', 'shader (fallback: canvas)'], ['Audio blocks', '0 dropped · 0 expired']].forEach(([l, c], i) => {
      list.insertAdjacentHTML('beforeend', `<div class="check"><i>…</i>${l}<code>${c}</code></div>`);
      setTimeout(() => { const n = list.children[i]; if (n) { n.classList.add('ok'); n.firstChild.textContent = '✓'; } }, 300 + i * 280);
    });
  };
  return s => { $('[data-hz]', el).textContent = s.batterySaver ? Math.min(20, s.framerate) : s.framerate; };
}

/* ─── settings renderer ────────────────────────────────────────── */
let rows = [];
function buildRow(r) {
  const el = document.createElement('div');
  el.className = 'row' + (r.full ? ' full' : '');
  el.dataset.search = `${r.label} ${r.desc || ''} ${r.k || ''} ${(r.opts || []).map(o => o.label || o[1]).join(' ')}`.toLowerCase();
  const get = r.get || (s => s[r.k]);
  const set = r.set || (v => ({ [r.k]: v }));
  const badges = `${r.isNew ? '<span class="new">New</span>' : ''}${r.isHypr ? '<span class="new hypr">Hyprland</span>' : ''}`;
  const head = r.label ? `<div class="rh"><div class="rt">${r.label}${badges}</div>${r.desc ? `<div class="rd">${r.desc}</div>` : ''}</div>` : '';
  let sync = () => { };
  if (r.type === 'switch') {
    el.innerHTML = head + `<div class="rc"><input type="checkbox" class="switch" aria-label="${r.label}"></div>`;
    const inp = $('input', el);
    inp.onchange = () => update(set(inp.checked));
    sync = s => { inp.checked = !!get(s); };
  } else if (r.type === 'range') {
    el.innerHTML = head + `<div class="rc range"><input type="range" min="${r.min}" max="${r.max}" step="${r.step}" aria-label="${r.label}"><output></output></div>`;
    const inp = $('input', el), out = $('output', el);
    inp.oninput = () => update(set(Number(inp.value)));
    sync = s => { const v = get(s); if (document.activeElement !== inp) inp.value = v; out.textContent = r.fmt ? r.fmt(v) : v; inp.style.setProperty('--f', (v - r.min) / (r.max - r.min) * 100 + '%'); };
  } else if (r.type === 'seg') {
    el.innerHTML = head + `<div class="rc"><div class="seg" role="group" aria-label="${r.label}">${r.opts.map(([v, l, n], i) => `<button data-i="${i}">${l}${n ? '<span class="new">New</span>' : ''}</button>`).join('')}</div></div>`;
    const btns = $$('button', el);
    btns.forEach(b => b.onclick = () => update(set(r.opts[b.dataset.i][0])));
    sync = s => btns.forEach(b => b.setAttribute('aria-pressed', r.opts[b.dataset.i][0] === get(s)));
  } else if (r.type === 'chips') {
    el.innerHTML = head + `<div class="chips">${r.opts.map(([v, l]) => `<button data-v="${v}">${l}</button>`).join('')}</div>`;
    const btns = $$('button', el);
    btns.forEach(b => b.onclick = () => {
      const cur = get(S).split(',').filter(Boolean), v = b.dataset.v;
      const next = cur.includes(v) ? cur.filter(x => x !== v) : r.opts.map(o => o[0]).filter(x => cur.includes(x) || x === v);
      update(set(next.join(',')));
    });
    sync = s => { const cur = get(s).split(','); btns.forEach(b => b.setAttribute('aria-pressed', cur.includes(b.dataset.v))); };
  } else if (r.type === 'textarea') {
    el.innerHTML = head + `<div class="rc"><textarea class="sel" rows="2" aria-label="${r.label}"></textarea></div>`;
    const ta = $('textarea', el);
    ta.oninput = () => update(set(ta.value));
    sync = s => { if (document.activeElement !== ta) ta.value = get(s); };
  } else if (r.type === 'select') {
    el.innerHTML = head + `<div class="rc"><select class="sel" aria-label="${r.label}">${r.opts.map(([v, l]) => `<option value="${v}">${l}</option>`).join('')}</select></div>`;
    const sel = $('select', el);
    sel.onchange = () => update(set(sel.value));
    sync = s => { sel.value = get(s); };
  } else if (r.type === 'color') {
    el.innerHTML = head + `<div class="rc swatches">${r.swatches.map(c => `<button class="sw" data-c="${c}" style="background:${c}" aria-label="${c}"></button>`).join('')}<label class="swc" title="Pick any colour"><input type="color" aria-label="${r.label}"></label></div>`;
    const btns = $$('.sw', el), inp = $('input', el);
    btns.forEach(b => b.onclick = () => update(set(b.dataset.c)));
    inp.oninput = () => update(set(inp.value));
    sync = s => { const v = get(s).toLowerCase(); btns.forEach(b => b.setAttribute('aria-pressed', b.dataset.c === v)); if (document.activeElement !== inp) inp.value = v; };
  } else if (r.type === 'tiles') {
    el.innerHTML = head + `<div class="tiles" style="--tw:${r.tw || 112}px">${r.opts.map((o, i) => `<button class="tile" data-i="${i}"><span class="tpv ${o.onbd ? 'onbd' : ''}">${o.pv === 'dock' ? `<span class="dockpv" data-v="${o.v}"></span>` : o.pv}</span><span class="tl">${o.label}${o.isNew ? '<span class="new">New</span>' : ''}</span></button>`).join('')}</div>`;
    const btns = $$('.tile', el);
    btns.forEach(b => b.onclick = e => { if (!e.target.closest('[data-act]')) update(set(r.opts[b.dataset.i].v)); });
    $$('canvas[data-c]', el).forEach(c => {
      const ti = Number(c.closest('.tile').dataset.i);
      if (c.dataset.c === 'wave') registry.push({ el: c, kind: 'wave', key: 'tile-viz-' + ti, viz: ti, getS: () => S, getStatus: () => 'demo' });
      else if (c.dataset.c === 'orbit') registry.push({ el: c, kind: 'orbit', key: 'tile-orbit-' + ti, orbit: ti, getS: () => S, getStatus: () => 'demo' });
      else registry.push({ el: c, kind: 'seek', key: 'tile-seek-' + ti, pbs: ti, fixedP: .58, getS: () => S, getStatus: () => 'demo' });
    });
    sync = s => {
      btns.forEach(b => b.setAttribute('aria-pressed', r.opts[b.dataset.i].v === get(s)));
      $$('.dockpv', el).forEach(dp => { const html = dockHTML({ ...s, dockStyle: dp.dataset.v }, true); if (dp.innerHTML !== html) dp.innerHTML = html; });
    };
  } else if (r.type === 'note') {
    el.innerHTML = '<div class="nt"></div>';
    const box = $('.nt', el);
    sync = () => { const html = r.html(); if (box.innerHTML !== html) box.innerHTML = html; };
  } else if (r.type === 'custom') {
    el.innerHTML = head + '<div class="cust"></div>';
    sync = r.render($('.cust', el));
  }
  return { el, r, sync };
}

function renderSettings() {
  $('#tabs').innerHTML = TABS.map(t => `<button role="tab" data-tab="${t.id}" aria-selected="${t.id === activeTab}"><svg viewBox="0 0 24 24">${t.ic}</svg>${t.label}</button>`).join('');
  const body = $('#pbody');
  body.innerHTML = '';
  rows = [];
  for (const sec of SECTIONS) {
    const wrap = document.createElement('div');
    wrap.className = 'sec'; wrap.dataset.tab = sec.tab; wrap._sec = sec;
    wrap.innerHTML = `<h4>${sec.title}</h4><div class="card"></div>`;
    for (const r of sec.rows) { const row = buildRow(r); $('.card', wrap).appendChild(row.el); rows.push(row); }
    body.appendChild(wrap);
  }
  body.insertAdjacentHTML('beforeend', '<div class="empty-search" hidden>No settings match that search.</div>');
}
function syncSettings() {
  $$('[data-acc]').forEach(b => b.setAttribute('aria-pressed', !S.useSystemAccent && !S.accentFromArt && b.dataset.acc === S.customColor));
  const q = query.trim().toLowerCase();
  for (const row of rows) {
    const vis = row.r.when ? row.r.when(S) : true;
    row.el.hidden = !vis || (q && !row.el.dataset.search.includes(q));
    row.el.classList.toggle('disabled', !!(row.r.disabled && row.r.disabled(S)));
    if (!row.el.hidden) row.sync(S);
  }
  let any = false;
  $$('.sec', $('#pbody')).forEach(sec => {
    const inTab = q ? true : sec.dataset.tab === activeTab;
    const visRows = $$('.row', sec).filter(r => !r.hidden);
    sec.hidden = !inTab || !visRows.length || (sec._sec.when && !sec._sec.when(S));
    $$('.row', sec).forEach(r => r.classList.remove('first'));
    if (visRows[0]) visRows[0].classList.add('first');
    if (!sec.hidden) any = true;
  });
  $('.empty-search').hidden = any;
  $$('#tabs [data-tab]').forEach(b => b.setAttribute('aria-selected', !q && b.dataset.tab === activeTab));
}
$('#tabs').addEventListener('click', e => {
  const b = e.target.closest('[data-tab]'); if (!b) return;
  activeTab = b.dataset.tab; query = ''; $('#search').value = ''; syncSettings();
});
$('#search').addEventListener('input', e => { query = e.target.value; syncSettings(); });
document.addEventListener('keydown', e => {
  if (e.key === '/' && !/INPUT|SELECT|TEXTAREA/.test(document.activeElement.tagName)) { e.preventDefault(); $('#search').focus(); }
  if (e.key === 'Escape') $('#lightbox').hidden = true;
});

/* ─── config diff ──────────────────────────────────────────────── */
function configEntries() {
  const out = [];
  const eq = (a, b) => typeof a === 'number' ? Math.abs(a - b) < 1e-6 : a === b;
  for (const [k, def] of Object.entries(EXISTING)) {
    const v = k === 'showMpris' ? S.layoutMode !== 'compact' : k === 'artBg' ? S.surfaceStyle === 'art' : S[k];
    if (!eq(v, def)) out.push([k, v, '']);
  }
  for (const [k, def] of Object.entries(HYPR)) if (!eq(S[k], def)) out.push([k, S[k], 'ishypr']);
  for (const [k, { def }] of Object.entries(PROPOSED)) {
    let v = S[k];
    if (k === 'layoutMode' && v === 'compact') v = def;
    if (k === 'surfaceStyle' && v === 'art') v = def;
    if (!eq(v, def)) out.push([k, v, 'isnew']);
  }
  return out;
}
const fmtVal = v => typeof v === 'number' && !Number.isInteger(v) ? String(Math.round(v * 100) / 100) : String(v);
function renderConfig() {
  const list = configEntries();
  const preset = PRESETS.find(p => p.id === activePreset);
  $('#cfgTitle').innerHTML = `Changed settings <span>· ${list.length}${preset ? ` · based on ${preset.name}` : ''}</span>`;
  $('#cfg').innerHTML = list.length ? list.map(([k, v, c]) => `<span class="kv ${c}"><b>${k}</b>${esc(fmtVal(v))}</span>`).join('') : '<span class="none">Everything is at its default — this is the widget exactly as it ships today.</span>';
}
$('#copyCfg').onclick = async () => {
  const txt = '[General]\n' + configEntries().map(([k, v]) => `${k}=${fmtVal(v)}`).join('\n');
  try { await navigator.clipboard.writeText(txt); toast('Config copied'); } catch (e) { toast('Clipboard blocked — see the list above'); }
};
$('#resetAll').onclick = () => { S = structuredClone(DEFAULTS); activePreset = 'classic'; onChange(); renderPresets(); toast('Back to the shipped defaults'); };
$('#shuffle').onclick = () => {
  const pick = a => a[Math.floor(Math.random() * a.length)], coin = p => Math.random() < p;
  S = { ...DEFAULTS,
    layoutMode: pick(['classic', 'classic', 'mirrored', 'inline', 'hero', 'stacked', 'strip', 'pill', 'orbit', 'orbit', 'poster', 'lyrics']), vizDirection: pick(['up', 'up', 'down']), orbitStyle: pick(['bars', 'wave', 'dots', 'ribbon', 'sparks']), visualizerType: Math.floor(Math.random() * VIZ.length), progressBarStyle: Math.floor(Math.random() * PBS.length),
    showBg: coin(.8), surfaceStyle: pick(['color', 'art', 'glass', 'liquid', 'atmosphere', 'solid']), bgRadius: pick([10, 14, 18, 22, 26]),
    artShape: pick(['sharp', 'rounded', 'squircle', 'circle', 'vinyl', 'cd']), dockStyle: pick(['glass', 'bare', 'accent']),
    accentFromArt: coin(.5), vizColorMode: pick(['solid', 'gradient', 'cover', 'palette', 'rainbow']), vizPalette: pick(Object.keys(PALETTES)),
    fillWave: coin(.5), glowWave: coin(.6), cardShadow: pick(['none', 'soft', 'lifted']), edgeHighlight: coin(.5), artGlow: coin(.4),
    showSource: coin(.4), showAlbum: coin(.4), hoverDetails: pick(['off', 'tooltip', 'flip']), pillEq: pick(['static', 'live', 'wave']), pillProgress: pick(['off', 'underline', 'ring']) };
  activePreset = null; popupOpen = true; onChange(); renderPresets();
};

/* ─── gallery statistics ─── */
$('#stats').innerHTML = [[VIZ.length, 'visualizers'], [PBS.length, 'progress bars'], [Object.keys(SIZES).length + PILLS.length, 'layouts'], [PRESETS.length, 'presets']].map(([n, l]) => `<div><b>${n}</b>${l}</div>`).join('');

/* ─── glue ─────────────────────────────────────────────────────── */
let toastTimer;
function toast(msg) { const t = $('#toast'); t.textContent = msg; t.classList.add('on'); clearTimeout(toastTimer); toastTimer = setTimeout(() => t.classList.remove('on'), 1800); }
function update(patch) {
  Object.assign(S, patch);
  presetDirty = true;
  if (activePreset) { $$('.pcard.active').forEach(c => c.classList.remove('active')); $$('.pcard .use').forEach(b => b.textContent = 'Use'); }
  onChange();
}
function onChange() {
  save();
  document.body.classList.toggle('rm', S.reducedMotion);
  renderMain(); syncSettings(); renderConfig();
}
function renderPlayers() { playerRev++; renderMain(); renderPresets(); renderHero(); syncSettings(); }

renderSettings();
onChange();
renderPresets();
renderHero();
requestAnimationFrame(frame);
