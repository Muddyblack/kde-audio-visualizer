<p align="center">
  <img src="./package/icon.png" width="200" alt="Plasma Audio Wave Visualizer Logo">
</p>

<h1 align="center">Plasma Audio Wave Visualizer</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2359422/">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store Download" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  <img src="https://img.shields.io/github/downloads/Muddyblack/kde-audio-visualizer/total?style=for-the-badge&logo=kdeplasma&logoColor=white&label=Downloads&color=blue" alt="Downloads" />
</p>

<p align="center">
  <img src="./readme/demo.svg" alt="Widget demo" width="680"/>
</p>

A glassy audio visualizer plasmoid for KDE Plasma 6. Renders mirrored waveform that reacts to whatever is playing system-wide (via [cava]), alongside MPRIS track metadata, album art, transport controls, and a seekable progress bar.

![Preview](readme/preview.png)

## Features

- **5 visualizer styles** — Smooth Wave, Rounded Bars, Mirror Bars, Tech Line, Floating Dots
- **4 progress bar styles** — Glassy Sleek, Ultra Minimal, Glowing Pulse, Bold Pill
- System-wide reactive waveform (PipeWire via cava — not tied to any single player)
- MPRIS2 track info: title, artist, album art
- Transport controls (prev / play-pause / next) with customizable color
- Seekable progress bar with elapsed/total time
- Honors the active Plasma accent color (or set a custom color)
- Optional waveform fill + neon glow effect
- Optional background card with configurable color, opacity (via alpha), and corner radius
- Custom text and controls colors
- Customizable dock background color (supports alpha via color picker)
- No panel background — sits cleanly on any panel

## Requirements

- KDE Plasma **6.0+**
- [`cava`][cava] (audio bar generator)
- `flock` (from `util-linux`) and `pkill` (from `procps`) — both standard on virtually every Linux distro

[cava]: https://github.com/karlstav/cava

## Install

### Manual install (any distro)

```bash
git clone https://github.com/muddyblack/plasma-audio-visualizer.git
cd plasma-audio-visualizer
kpackagetool6 -t Plasma/Applet -i package
# or, to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then add the widget from Plasma's "Add Widgets" panel.

To remove: `kpackagetool6 -t Plasma/Applet -r org.muddyblack.plasmaAudioVisualizer`

### NixOS (flake)

```nix
# flake.nix
{
  inputs.audio-wave.url = "github:muddyblack/plasma-audio-visualizer";

  outputs = { self, nixpkgs, audio-wave, ... }: {
    nixosConfigurations.mybox = nixpkgs.lib.nixosSystem {
      modules = [
        ({ pkgs, ... }: {
          environment.systemPackages = [
            audio-wave.packages.${pkgs.system}.default
            pkgs.cava
          ];
        })
      ];
    };
  }
}
```

### Package as `.plasmoid` (for KDE Store)

```bash
./pack.sh
# produces plasma-audio-visualizer-<version>.plasmoid
```

## How it works

For a detailed explanation of the architecture and data flow, see the [Architecture Documentation](docs/workflow.md).

In short: the widget uses a small shell helper (`feeder.sh`) to run `cava` in the background and atomically writes the latest bars to `$XDG_RUNTIME_DIR/audio-wave-widget/bars`. The QML side polls that file at ~30 fps.

## Configuration

All settings are available via the widget's right-click → Configure menu:

| Setting | Description |
|---|---|
| **Visualizer Style** | Smooth Wave / Rounded Bars / Mirror Bars / Tech Line / Floating Dots |
| **Progress Bar Style** | Glassy Sleek / Ultra Minimal / Glowing Pulse / Bold Pill |
| **Number of Bars** | How many frequency bars cava outputs (8–128) |
| **Framerate** | Target refresh rate in Hz |
| **Sensitivity** | Cava amplitude multiplier |
| **Smoothing** | Noise reduction factor (0–1) |
| **Wave Color** | System accent or custom color |
| **Wave Glow** | Neon glow shadow on the waveform |
| **Fill Wave** | Transparent gradient fill under the waveform |
| **Line Width** | Stroke width for line-based visualizers |
| **Text / Controls / Dock Colors** | Each independently customizable |
| **Background Card** | Optional frosted card with custom color+alpha and corner radius |
| **Show MPRIS info** | Toggle album art, track title, artist, and controls |