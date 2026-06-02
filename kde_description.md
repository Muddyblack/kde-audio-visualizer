# Plasma Audio Visualizer

A modern, customizable audio visualizer widget for KDE Plasma 6. It renders a mirrored waveform reacting in real-time to whatever audio is playing system-wide, alongside complete MPRIS track info, album art, transport controls, and a seekable progress bar.

---

### Features
* **6 Visualizer Styles:** Smooth Wave, Rounded Bars, Mirror Bars, Tech Line, Floating Dots, and Floating Dots Bold.
* **5 Progress Bar Styles:** Glassy Sleek (default), Ultra Minimal (thin 1px), Glowing Pulse (neon accent), Bold Pill, and Waveform.
* **Album Art as Background:** Use the current cover as a blurred card backdrop, with independent Blur and Darkness sliders to tune the look from a bold crisp cover to a subtle frosted tint. The redundant thumbnail hides automatically.
* **Smart Background Card:** Optional frosted card with customizable color, transparency (via color picker alpha), and corner radius.
* **Smooth Motion:** Frame interpolation keeps the waveform gliding instead of snapping between updates.
* **High Contrast/Transparent Panel Friendly:** Visualizer styles adapt to work on transparent panels or over custom backgrounds.
* **System Accent Integration:** Automatically matches your Plasma system accent color and text colors (or set your own custom colors).
* **Robust MPRIS Integration:** Displays album art, track details, playback timer, and transport controls (Play/Pause, Previous, Next).
* **Fast & Lightweight:** Powered by `cava` in the background with lock management to prevent system lag.

---

### Requirements
To run this widget, you will need:
1. **cava** (console audio visualizer) — to generate the raw waveform bars.
2. **flock** (from `util-linux`) and **pkill** (from `procps`) — standard utilities pre-installed on virtually all Linux distributions.

---

### Quick Install (Terminal)

```bash
git clone https://github.com/muddyblack/plasma-audio-visualizer.git
cd plasma-audio-visualizer
kpackagetool6 -t Plasma/Applet -i package
```

To update an existing installation:
```bash
kpackagetool6 -t Plasma/Applet -u package
```

---

### Configuration
Right-click the widget and select "Configure Plasma Audio Visualizer" to customize:
* Visualizer type & styling
* Progress bar design
* Number of frequency bars ( 8 to 128 )
* Target framerate & smoothing factor
* Wave, Text, Controls, and Dock background colors (with alpha support)
* Background card visibility, radius, and color
* Album art as a blurred background, with Blur and Darkness sliders
