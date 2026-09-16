import QtQuick
import ".."
import "Theme.js" as Theme
import "Schema.js" as Schema
import "Diagrams.js" as Diagrams

// Live previews inside settings tiles (docs/redesign-plan.md §9.2).
Item {
    id: preview
    required property string kind
    property var value
    required property var studio
    property color ink: Theme.muted
    readonly property var draft: studio.draft

    Loader {
        anchors.fill: parent
        sourceComponent: ({
                viz: vizComponent,
                orbit: orbitComponent,
                progress: progressComponent,
                dock: dockComponent,
                diagram: diagramComponent,
                material: materialComponent,
                shape: shapeComponent,
                palette: paletteComponent
            })[preview.kind] ?? null
    }

    Component {
        id: vizComponent
        Item {
            Waveform {
                anchors.centerIn: parent
                width: parent.width * 0.88
                height: 36
                bars: preview.studio.backend.bars
                numBars: preview.studio.backend.numBars
                maxRange: preview.studio.backend.maxRange
                hasAudio: true
                visualFrameTime: preview.studio.backend.frameTimeMs
                bass: preview.studio.backend.bass
                mid: preview.studio.backend.mid
                high: preview.studio.backend.high
                waveColor: preview.studio.accent
                textColor: Theme.text
                visualizerType: preview.value
                lineWidth: preview.draft.lineWidth ?? 1.8
                fillWave: preview.draft.fillWave ?? false
                glowWave: preview.draft.glowWave ?? true
                bloom: preview.draft.bloom ?? 1
                vizDirection: [1, 6, 7, 8].indexOf(preview.value) !== -1 ? (preview.draft.vizDirection ?? "up") : "up"
                vizColorMode: preview.draft.vizColorMode ?? "solid"
                vizPalette: preview.draft.vizPalette ?? "aurora"
                hueReactive: preview.draft.hueReactive ?? false
                reducedMotion: preview.draft.reducedMotion ?? false
                simpleRender: preview.draft.simpleRender ?? false
            }
        }
    }

    Component {
        id: orbitComponent
        Item {
            OrbitView {
                simpleRender: preview.draft.simpleRender ?? false
                anchors.centerIn: parent
                width: 48
                height: 48
                coverRatio: 0.36
                orbitStyle: preview.value
                bars: preview.studio.backend.bars
                numBars: preview.studio.backend.numBars
                maxRange: preview.studio.backend.maxRange
                hasAudio: true
                visualFrameTime: preview.studio.backend.frameTimeMs
                high: preview.studio.backend.high
                waveColor: preview.studio.accent
                vizColorMode: preview.draft.vizColorMode ?? "solid"
                vizPalette: preview.draft.vizPalette ?? "aurora"
                hueReactive: preview.draft.hueReactive ?? false
                lineWidth: 1
                glowWave: preview.draft.glowWave ?? true
                bloom: preview.draft.bloom ?? 1
                reducedMotion: preview.draft.reducedMotion ?? false
            }
            Rectangle {
                anchors.centerIn: parent
                width: 16
                height: 16
                radius: 8
                color: "#0dffffff"
                border.color: "#2effffff"
            }
        }
    }

    Component {
        id: progressComponent
        Item {
            ProgressBar {
                visible: preview.value !== 10
                anchors.centerIn: parent
                width: parent.width * 0.82
                height: implicitHeight
                player: preview.studio.samplePlayer
                isPlaying: preview.value === 0 || preview.value === 2
                hasAudio: true
                style: preview.value
                track: preview.studio.samplePlayer.track
                artist: preview.studio.samplePlayer.artist
                textColor: Theme.text
                waveColor: preview.studio.accent
                controlColor: "#ffffff"
                pgStartColor: preview.studio.accent
                pgEndColor: "#ffffff"
                positionUnitsPerSecond: 1
                visualFrameTime: preview.studio.backend.frameTimeMs
            }
            Rectangle {
                visible: preview.value === 10
                anchors.centerIn: parent
                width: 32
                height: 32
                radius: 10
                color: "#0dffffff"
                border.color: "#2effffff"
                CoverRing {
                    anchors.fill: parent
                    anchors.margins: -4
                    player: preview.studio.samplePlayer
                    positionUnitsPerSecond: 1
                    accentColor: preview.studio.accent
                }
            }
        }
    }

    Component {
        id: dockComponent
        Item {
            TransportDock {
                anchors.centerIn: parent
                opacity: preview.value === "hover" ? 0.55 : 1
                configuration: Object.assign({}, preview.draft, {
                    dockStyle: preview.value === "hover" ? "glass" : preview.value
                })
                isPlaying: true
                controlColor: "#ffffff"
                accentColor: preview.studio.accent
            }
        }
    }

    Component {
        id: diagramComponent
        Item {
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.7
                height: width * 36 / 64
                readonly property var signature: [preview.value, preview.ink, width]
                onSignatureChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    ctx.scale(width / 64, height / 36);
                    for (const shape of Diagrams.shapes[preview.value] || []) {
                        ctx.save();
                        ctx.beginPath();
                        if (shape.tag === "rect") {
                            const r = Number(shape.rx || 0);
                            ctx.roundedRect(Number(shape.x), Number(shape.y), Number(shape.width), Number(shape.height), r, r);
                        } else if (shape.tag === "circle") {
                            ctx.arc(Number(shape.cx), Number(shape.cy), Number(shape.r), 0, Math.PI * 2);
                        } else {
                            ctx.path = shape.d;
                        }
                        ctx.lineCap = "round";
                        if (shape.cls === "f" || shape.cls === "f2") {
                            ctx.globalAlpha = shape.opacity ?? (shape.cls === "f" ? 0.85 : 0.35);
                            ctx.fillStyle = preview.ink;
                            ctx.fill();
                        } else if (shape.cls === "o") {
                            ctx.globalAlpha = shape.opacity ?? 0.6;
                            ctx.strokeStyle = preview.ink;
                            ctx.lineWidth = 1.2;
                            ctx.stroke();
                        } else if (shape.cls === "s" || shape.stroke) {
                            ctx.globalAlpha = shape.opacity ?? 1;
                            ctx.strokeStyle = Theme.brand;
                            ctx.lineWidth = Number(shape.stroke_width || 1.6);
                            ctx.stroke();
                        }
                        ctx.restore();
                    }
                }
            }
        }
    }

    Component {
        id: materialComponent
        Item {
            Rectangle {
                anchors.fill: parent
                visible: preview.value === "liquid"
                gradient: Gradient {
                    orientation: Gradient.Horizontal
                    GradientStop {
                        position: 0
                        color: "#5b1d6e"
                    }
                    GradientStop {
                        position: 1
                        color: "#b3628a"
                    }
                }
            }
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.74
                height: 34
                readonly property var signature: [preview.value, width]
                onSignatureChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const w = width, h = height;
                    const diagonal = stops => {
                        const g = ctx.createLinearGradient(0, 0, w, h);
                        for (const s of stops)
                            g.addColorStop(s[0], s[1]);
                        ctx.fillStyle = g;
                        ctx.fillRect(0, 0, w, h);
                    };
                    ctx.save();
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, w, h, 9, 9);
                    ctx.clip();
                    switch (preview.value) {
                    case "color":
                        ctx.fillStyle = "#e60a0b10";
                        ctx.fillRect(0, 0, w, h);
                        break;
                    case "art":
                        diagonal([[0, "#7a3cff"], [1, "#ff4fb8"]]);
                        ctx.fillStyle = "#55000000";
                        ctx.fillRect(0, 0, w, h);
                        break;
                    case "glass":
                        diagonal([[0, "#30ffffff"], [0.6, "#08ffffff"], [1, "#14ffffff"]]);
                        ctx.fillStyle = "#30ffffff";
                        ctx.fillRect(0, 0, w, 1);
                        break;
                    case "liquid":
                        diagonal([[0, "#22ffffff"], [0.5, "#05ffffff"], [1, "#18ffffff"]]);
                        ctx.fillStyle = "#aaffffff";
                        ctx.fillRect(0, 0, w, 1);
                        ctx.fillStyle = "#40ffffff";
                        ctx.fillRect(0, h - 1, w, 1);
                        break;
                    case "solid":
                        diagonal([[0, "#eeeee4"], [1, "#d9dfcf"]]);
                        break;
                    case "atmosphere":
                        ctx.fillStyle = "#120b2e";
                        ctx.fillRect(0, 0, w, h);
                        for (const spot of [[w, 0, "#aaff3d8b"], [0, h, "#aa5b2cff"]]) {
                            const g = ctx.createRadialGradient(spot[0], spot[1], 0, spot[0], spot[1], w * 0.8);
                            g.addColorStop(0, spot[2]);
                            g.addColorStop(1, "transparent");
                            ctx.fillStyle = g;
                            ctx.fillRect(0, 0, w, h);
                        }
                        break;
                    }
                    ctx.restore();
                    if (preview.value !== "liquid") {
                        ctx.strokeStyle = "#1fffffff";
                        ctx.lineWidth = 1;
                        ctx.beginPath();
                        ctx.roundedRect(0.5, 0.5, w - 1, h - 1, 8.5, 8.5);
                        ctx.stroke();
                    }
                }
            }
        }
    }

    Component {
        id: shapeComponent
        Item {
            QtObject {
                id: sampleView
                property var configuration: ({
                        artShape: preview.value
                    })
                property string displayTrack: ""
                property bool isPlaying: preview.value === "vinyl" || preview.value === "cd"
                property bool hasPlayer: true
                property bool cardHovered: false
                property bool zoomOpen: false
                property var player: null
                property color textColor: Theme.text
                property color waveColor: preview.studio.accent
                property color coverColor1: preview.studio.accent
                property real visualFrameTime: preview.studio.backend.frameTimeMs
            }
            ArtView {
                anchors.centerIn: parent
                width: 36
                height: 36
                view: sampleView
                artUrl: preview.studio.samplePlayer.artUrl
            }
        }
    }

    Component {
        id: paletteComponent
        Item {
            Canvas {
                anchors.centerIn: parent
                width: parent.width * 0.74
                height: 34
                readonly property var signature: [preview.value, width]
                onSignatureChanged: requestPaint()
                onPaint: {
                    const ctx = getContext("2d");
                    ctx.reset();
                    const colors = Schema.PALETTES[preview.value] || [];
                    const g = ctx.createLinearGradient(0, 0, width, 0);
                    colors.forEach((c, i) => g.addColorStop(colors.length > 1 ? i / (colors.length - 1) : 0, c));
                    ctx.fillStyle = g;
                    ctx.beginPath();
                    ctx.roundedRect(0, 0, width, height, 9, 9);
                    ctx.fill();
                }
            }
        }
    }
}
