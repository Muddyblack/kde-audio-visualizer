[h1]Plasma Audio Visualizer[/h1]

A modern, customizable audio visualizer widget for KDE Plasma 6. It renders a mirrored waveform reacting in real-time to whatever audio is playing system-wide, alongside complete MPRIS track info, album art, transport controls, and a seekable progress bar.

---

[b]Features[/b]
[list]
[*] [b]6 Visualizer Styles:[/b] Smooth Wave, Rounded Bars, Mirror Bars, Tech Line, Floating Dots, and Floating Dots Bold.
[*] [b]5 Progress Bar Styles:[/b] Glassy Sleek (default), Ultra Minimal (thin 1px), Glowing Pulse (neon accent), Bold Pill, and Waveform.
[*] [b]Album Art as Background:[/b] Use the current cover as a blurred card backdrop, with independent Blur and Darkness sliders to tune the look from a bold crisp cover to a subtle frosted tint. The redundant thumbnail hides automatically.
[*] [b]Smart Background Card:[/b] Optional frosted card with customizable color, transparency (via color picker alpha), and corner radius.
[*] [b]Smooth Motion:[/b] Frame interpolation keeps the waveform gliding instead of snapping between updates.
[*] [b]High Contrast/Transparent Panel Friendly:[/b] Visualizer styles adapt to work on transparent panels or over custom backgrounds.
[*] [b]System Accent Integration:[/b] Automatically matches your Plasma system accent color and text colors (or set your own custom colors).
[*] [b]Robust MPRIS Integration:[/b] Displays album art, track details, playback timer, and transport controls (Play/Pause, Previous, Next).
[*] [b]Fast & Lightweight:[/b] Powered by cava in the background with lock management to prevent system lag.
[/list]

---

[b]Requirements[/b]
To run this widget, you will need:
[list]
[*] [b]cava[/b] (console audio visualizer) — to generate the raw waveform bars.
[*] [b]flock[/b] (from util-linux) and [b]pkill[/b] (from procps) — standard utilities pre-installed on virtually all Linux distributions.
[/list]

---

[b]Quick Install (Terminal)[/b]

[code]
git clone https://github.com/muddyblack/plasma-audio-visualizer.git
cd plasma-audio-visualizer
kpackagetool6 -t Plasma/Applet -i package
[/code]

To update an existing installation:
[code]
kpackagetool6 -t Plasma/Applet -u package
[/code]

---

[b]Configuration[/b]
Right-click the widget and select "Configure Plasma Audio Visualizer" to customize:
[list]
[*] Visualizer type & styling
[*] Progress bar design
[*] Number of frequency bars ( 8 to 128 )
[*] Target framerate & smoothing factor
[*] Wave, Text, Controls, and Dock background colors (with alpha support)
[*] Background card visibility, radius, and color
[*] Album art as a blurred background, with Blur and Darkness sliders
[/list]
