import QtQuick
import QtQuick.Controls
import QtQuick.Layouts
import Quickshell

ShellRoot {
    id: sandboxRoot

    property string globalPasswordBuffer: ""
    property int passwordLength: 0

    Window {
        id: testWindow
        width: 1920
        height: 1080
        visible: true

        Rectangle {
            id: mainLayoutContainer
            anchors.fill: parent
            color: "#0c0c14" // Deep space background to make lingering glows pop
            focus: true

            // =========================================================================
            // SMOOTH BÉZIER CURVE PAINT-BRUSH RIBBON SYSTEM
            // =========================================================================
            Item {
                id: animationCanvas
                anchors.fill: parent

                width: mainLayoutContainer.width
                height: mainLayoutContainer.height

                property var activeFlares: []

                // AUTOMATED SPAWN TIMER: Spawns 1 new comet every single second
                Timer {
                    id: autoSpawner
                    interval: 1000
                    running: true
                    repeat: true
                    onTriggered: {
                        var currentList = [];
                        animationCanvas.activeFlares.forEach(function(f) {
                            currentList.push(f);
                        });

                        var newComet = {
                            posX: Math.random() * mainLayoutContainer.width,
                            posY: mainLayoutContainer.height - (Math.random() * 100),
                            baseSpeedX: (Math.random() * 3.0) - 1.5,
                            baseSpeedY: -(2.5 + (Math.random() * 3.0)),

                            wiggleSeed: Math.random() * 50.0,
                            wiggleSpeed: 0.08 + (Math.random() * 0.06),
                            wiggleIntensity: 4.0 + (Math.random() * 4.0),

                            currentRotation: Math.random() * 360,
                            spinSpeed: 3 + (Math.random() * 5),
                            spinDirection: Math.random() > 0.5 ? 1 : -1,

                            opacityVal: 1.0,
                            pathHistory: []
                        };

                        currentList.push(newComet);
                        animationCanvas.activeFlares = currentList;
                    }
                }

                // FRAME TICKER LOOP: Animates and shifts coordinates smoothly at 60 FPS
                Timer {
                    id: frameTicker
                    interval: 16
                    running: animationCanvas.activeFlares.length > 0
                    repeat: true
                    onTriggered: {
                        var updatedList = [];

                        for (var i = 0; i < animationCanvas.activeFlares.length; i++) {
                            var flare = animationCanvas.activeFlares[i];

                            flare.pathHistory.push({ x: flare.posX, y: flare.posY });

                            if (flare.pathHistory.length > 20) {
                                flare.pathHistory.shift();
                            }

                            flare.wiggleSeed = flare.wiggleSeed + flare.wiggleSpeed;

                            var waveOffset = Math.sin(flare.wiggleSeed) * flare.wiggleIntensity;
                            var crossOffset = Math.cos(flare.wiggleSeed) * (flare.wiggleIntensity * 0.4);

                            flare.posX = flare.posX + flare.baseSpeedX + waveOffset;
                            flare.posY = flare.posY + flare.baseSpeedY + crossOffset;

                            flare.currentRotation = flare.currentRotation + flare.spinSpeed;

                            flare.posX = flare.posX + (Math.random() * 1.0 - 0.5);
                            flare.posY = flare.posY + (Math.random() * 1.0 - 0.5);
                            flare.opacityVal = flare.opacityVal - 0.003;

                            if (flare.opacityVal > 0 && flare.posY > -50) {
                                updatedList.push(flare);
                            }
                        }

                        animationCanvas.activeFlares = updatedList;
                    }
                }

                Repeater {
                    model: animationCanvas.activeFlares

                    delegate: Item {
                        anchors.fill: parent

                        Canvas {
                            anchors.fill: parent
                            opacity: modelData.opacityVal

                            onPaint: {
                                var ctx = getContext("2d");
                                ctx.reset();

                                var history = modelData.pathHistory;
                                var len = history.length;
                                if (len < 3) return; // Requires at least 3 points to calculate a smooth curve

                                // --- FIX: SMOOTH BÉZIER PAINT-BRUSH TRAIL ---
                                // Calculates midpoints between snapshots to build a seamless curved path
                                for (var i = 1; i < len - 1; i++) {
                                    ctx.beginPath();

                                    // Midpoint between previous point and current point
                                    var xc = (history[i].x + history[i + 1].x) / 2;
                                    var yc = (history[i].y + history[i + 1].y) / 2;

                                    ctx.moveTo(history[i].x, history[i].y);

                                    // Automatically smooths the corner using the middle coordinate anchor point
                                    ctx.quadraticCurveTo(history[i].x, history[i].y, xc, yc);

                                    var ratio = i / len;
                                    ctx.lineWidth = ratio * 16; // Tapers beautifully from 16px down to 0

                                    var strokeGradient = ctx.createLinearGradient(history[i].x, history[i].y, xc, yc);
                                    strokeGradient.addColorStop(0.0, 'rgba(103, 93, 219, ' + (ratio * 0.15) + ')');
                                    strokeGradient.addColorStop(0.5, 'rgba(103, 93, 219, ' + (ratio * 0.35) + ')');
                                    strokeGradient.addColorStop(1.0, 'rgba(127, 167, 255, ' + (ratio * 0.75) + ')');

                                    ctx.strokeStyle = strokeGradient;
                                    ctx.lineCap = "round";
                                    ctx.lineJoin = "round";
                                    ctx.stroke();
                                }

                                // --- DRAW THE PRIMARY GLOWING CORE HEAD ---
                                ctx.save();
                                ctx.translate(modelData.posX, modelData.posY);

                                if (modelData.spinDirection === -1) {
                                    ctx.scale(-1, 1);
                                }

                                ctx.rotate(modelData.currentRotation * Math.PI / 180);

                                var headGradient = ctx.createRadialGradient(0, 0, 0, 0, 0, 18);
                                headGradient.addColorStop(0.0, 'rgba(255, 255, 255, 1.0)');
                                headGradient.addColorStop(0.3, 'rgba(127, 167, 255, 0.85)');
                                headGradient.addColorStop(1.0, 'rgba(103, 93, 219, 0.0)');

                                ctx.fillStyle = headGradient;
                                ctx.beginPath();
                                ctx.arc(0, 0, 18, 0, 2 * Math.PI);
                                ctx.fill();
                                ctx.restore();
                            }
                        }
                    }
                }
            }
            // --- STYLIZED PASSWORD CAPSULE WITH MULTI-LAYER BLOOM GLOW ---
            ColumnLayout {
                anchors.centerIn: parent
                spacing: 15

                TextField {
                    id: passwordField
                    placeholderText: "Watching smooth brush-stroke comets..."
                    width: 320
                    height: 50
                    color: "#cdd6f4"
                    focus: true
                    horizontalAlignment: TextInput.AlignHCenter

                    background: Item {
                        implicitWidth: 320
                        implicitHeight: 50

                        // Outer Glow Ring 2 (Farthest Out)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -12
                            color: "transparent"
                            radius: 14
                            border.color: "#675DDB"
                            border.width: 1
                            opacity: passwordField.activeFocus ? 0.15 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Outer Glow Ring 1 (Middle Layer)
                        Rectangle {
                            anchors.fill: parent
                            anchors.margins: -6
                            color: "transparent"
                            radius: 11
                            border.color: "#675DDB"
                            border.width: 2
                            opacity: passwordField.activeFocus ? 0.35 : 0.0
                            Behavior on opacity { NumberAnimation { duration: 150 } }
                        }

                        // Main Input Border Box (Core Box)
                        Rectangle {
                            id: inputBg
                            anchors.fill: parent
                            color: "#1e1e2e"
                            radius: 8
                            border.color: passwordField.activeFocus ? "#9db9ff" : "#45475a"
                            border.width: 2
                        }
                    }
                }
            }
        }
    }
}
