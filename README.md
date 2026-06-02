<p align="center">
  <img src="./package/icon.png" width="180" alt="Plasma Audio Wave Visualizer Logo">
</p>

<h1 align="center">Plasma Audio Wave Visualizer</h1>

<p align="center">
  <a href="https://www.opendesktop.org/p/2359422/">
    <img src="https://img.shields.io/badge/KDE_Store-Download-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Store Download" />
  </a>
  <img src="https://img.shields.io/badge/KDE_Plasma-6.0%2B-1d99f3?style=for-the-badge&logo=kde&logoColor=white" alt="KDE Plasma 6.0+" />
  <img src="https://img.shields.io/badge/License-MIT-yellow?style=for-the-badge" alt="License: MIT" />
  <a href="https://www.opendesktop.org/p/2359422/">
    <img src="https://img.shields.io/badge/dynamic/json?url=https%3A%2F%2Fapi.pling.com%2Focs%2Fv1%2Fcontent%2Fdata%2F2359422%3Fformat%3Djson&query=%24.data%5B0%5D.downloads&label=Downloads&style=for-the-badge&color=1d99f3&logo=kde&logoColor=white" alt="KDE Store Downloads" />
  </a>
  <a href="https://github.com/Muddyblack/kde-audio-visualizer/releases">
    <img src="https://img.shields.io/github/downloads/Muddyblack/kde-audio-visualizer/total?style=for-the-badge&logo=github&logoColor=white&label=GitHub%20Downloads&color=blue" alt="GitHub Downloads" />
  </a>
</p>

<p align="center">
  <img src="./readme/demo.svg?v=1.1.3" alt="Widget demo" width="680"/>
</p>

<p align="center">
  <a href="#features">Features</a> ·
  <a href="#gallery">Gallery</a> ·
  <a href="#requirements">Requirements</a> ·
  <a href="#install">Install</a> ·
  <a href="#configuration">Configuration</a> ·
  <a href="#how-it-works">How it works</a>
</p>

---

A glassy audio visualizer plasmoid for KDE Plasma 6. Renders a mirrored waveform that reacts to whatever is playing system-wide (via [cava]), alongside MPRIS track metadata, album art, transport controls, and a seekable progress bar.

<p align="center">
  <img src="./readme/preview.png" alt="Preview" width="680"/>
</p>

## Features

- **6 visualizer styles** — Smooth Wave, Rounded Bars, Mirror Bars, Tech Line, Floating Dots, Floating Dots Bold
- **5 progress bar styles** — Glassy Sleek, Ultra Minimal, Glowing Pulse, Bold Pill, Waveform
- System-wide reactive waveform (PipeWire via cava — not tied to any single player)
- Smooth frame interpolation so the waveform glides instead of snapping
- MPRIS2 track info: title, artist, album art
- Transport controls (prev / play-pause / next) with customizable color
- Seekable progress bar with elapsed/total time
- Honors the active Plasma accent color (or set a custom color)
- Optional waveform fill + neon glow effect
- **Album art as background** — use the current cover as a blurred backdrop with independent Blur and Darkness sliders; the redundant thumbnail hides automatically
- Optional background card with configurable color, opacity (via alpha), and corner radius
- Custom text and controls colors
- Customizable dock background color (supports alpha via color picker)
- No panel background — sits cleanly on any panel

## Gallery

<details open>
  <summary><b>Smooth Wave / Lines</b></summary>
  <br/>
  <img src="./readme/lines.png" alt="Line-style visualizer" width="680"/>
</details>

<details>
  <summary><b>Bars</b></summary>
  <br/>
  <img src="./readme/bars.png" alt="Bar-style visualizer" width="680"/>
</details>

<details>
  <summary><b>Dotted</b></summary>
  <br/>
  <img src="./readme/dotted.png" alt="Floating-dots visualizer" width="680"/>
</details>

<details>
  <summary><b>Album art as background</b></summary>
  <br/>
  Turn the current track's cover into a blurred backdrop. The album-art thumbnail
  hides automatically (it'd be redundant), and the <b>Blur</b> and <b>Darkness</b>
  sliders dial the look from a crisp bold cover to a subtle frosted tint — all
  while keeping the waveform and text readable.
  <br/><br/>
  <img src="./readme/art_as_background.png" alt="Album art as background" width="680"/>
</details>

<details>
  <summary><b>Settings</b></summary>
  <br/>
  <img src="./readme/settings.png" alt="Configuration dialog" width="680"/>
</details>

## Requirements

- KDE Plasma **6.0+**
- [`cava`][cava] — the audio bar generator
- `flock` (from `util-linux`) and `pkill` (from `procps`) — standard on virtually every Linux distro

[cava]: https://github.com/karlstav/cava

## Install

<details open>
  <summary><b>Manual (any distro)</b></summary>

```bash
git clone https://github.com/muddyblack/plasma-audio-visualizer.git
cd plasma-audio-visualizer
kpackagetool6 -t Plasma/Applet -i package
# or, to update an existing install:
kpackagetool6 -t Plasma/Applet -u package
```

Then add the widget from Plasma's **Add Widgets** panel.

To remove:

```bash
kpackagetool6 -t Plasma/Applet -r org.muddyblack.plasmaAudioVisualizer
```

</details>

<details>
  <summary><b>NixOS (flake)</b></summary>

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

</details>

<details>
  <summary><b>Package as <code>.plasmoid</code> (for the KDE Store)</b></summary>

```bash
./pack.sh
# produces plasma-audio-visualizer-<version>.plasmoid
```

</details>

## Configuration

All settings are available via the widget's right-click → Configure menu:

| Setting | Description |
|---|---|
| **Visualizer Style** | Smooth Wave / Rounded Bars / Mirror Bars / Tech Line / Floating Dots / Floating Dots Bold |
| **Progress Bar Style** | Glassy Sleek / Ultra Minimal / Glowing Pulse / Bold Pill / Waveform |
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
| **Art Background** | Use the album cover as a blurred card background |
| **Art Blur / Art Darkness** | Independent sliders to tune how blurred and how dark the art background is |
| **Show MPRIS info** | Toggle album art, track title, artist, and controls |

## How it works

For a detailed explanation of the architecture and data flow, see the [Architecture Documentation](docs/workflow.md).

In short: the widget uses a small shell helper (`feeder.sh`) to run `cava` in the background and atomically writes the latest bars to `$XDG_RUNTIME_DIR/audio-wave-widget/bars`. The QML side polls that file at ~30 fps.