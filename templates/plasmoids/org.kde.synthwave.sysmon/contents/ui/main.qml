/*
 * Synthwave System Monitor — htop-shaped metrics for the desktop.
 *
 * Data comes from ksystemstats through the KSysGuard sensor API rather than by
 * shelling out to read /proc on a timer: the daemon is already running for
 * Plasma's own monitor widgets, sensors are push-updated, and there is no
 * process spawn per tick. Sensor ids were taken from the daemon's own
 * allSensors() output on this machine, not guessed.
 *
 * Colours are the values from templates/color-schemes/Synthwave.colors in
 * ubu-setup, so this matches Konsole, the window decoration and the icons.
 */
import QtQuick
import QtQuick.Layouts
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.ksysguard.sensors as Sensors

PlasmoidItem {
    id: root

    readonly property color cEdge:    "#2a1f3d"
    readonly property color cCyan:    "#00e5e5"
    readonly property color cMagenta: "#ff3bff"
    readonly property color cPurple:  "#7e63a8"
    readonly property color cDim:     "#4a3a5e"
    readonly property color cGreen:   "#3bff9e"
    readonly property color cYellow:  "#ffd866"

    readonly property int coreCount: 8

    /* The widget paints its own panel, so Plasma's theme background would just
     * be a second, wrong-coloured box behind it. */
    Plasmoid.backgroundHints: PlasmaCore.Types.NoBackground

    preferredRepresentation: fullRepresentation

    // ---- sensors -----------------------------------------------------------
    Sensors.Sensor { id: memPercent; sensorId: "memory/physical/usedPercent" }
    Sensors.Sensor { id: memUsed;    sensorId: "memory/physical/used" }
    Sensors.Sensor { id: swapPercent; sensorId: "memory/swap/usedPercent" }
    Sensors.Sensor { id: swapUsed;   sensorId: "memory/swap/used" }
    Sensors.Sensor { id: load1;      sensorId: "cpu/loadaverages/loadaverage1" }
    Sensors.Sensor { id: load5;      sensorId: "cpu/loadaverages/loadaverage5" }
    Sensors.Sensor { id: load15;     sensorId: "cpu/loadaverages/loadaverage15" }
    Sensors.Sensor { id: netDown;    sensorId: "network/all/download" }
    Sensors.Sensor { id: netUp;      sensorId: "network/all/upload" }
    Sensors.Sensor { id: uptime;     sensorId: "os/system/uptime" }
    Sensors.Sensor { id: hostname;   sensorId: "os/system/hostname" }

    function num(sensor) {
        return sensor.value === undefined || sensor.value === null ? 0 : Number(sensor.value);
    }

    function fmtLoad(sensor) {
        return num(sensor).toFixed(2);
    }

    /* Seconds -> H:MM. The sensor's own formattedValue spells out
     * "3 hours 14 minutes", which will not fit the panel. */
    function fmtUptime() {
        const s = num(uptime);
        const h = Math.floor(s / 3600);
        const m = Math.floor((s % 3600) / 60);
        return h + ":" + (m < 10 ? "0" : "") + m;
    }

    fullRepresentation: Item {
        /* 12 margin + 191 (widest left row, a CPU bar) + 18 gutter
         * + 176 (widest right row, the MEM bar) + 12 margin = 409.
         * Measured from Hack's 6.6px advance at 11px rather than guessed;
         * the first pass padded this to 540 and left a dead strip. */
        Layout.preferredWidth: 410
        Layout.preferredHeight: panel.implicitHeight
        Layout.minimumWidth: 360
        Layout.minimumHeight: panel.implicitHeight

        Rectangle {
            id: panel
            anchors.fill: parent
            implicitHeight: content.implicitHeight + 24
            radius: 3
            /* Flat black, fully opaque. The near-black #0c0c10 at 92% alpha
             * read as tinted, because the wallpaper showed through it and the
             * colour itself carries a blue cast. Pure black also matches the
             * terminal's own background (Colors:View is 0,0,0). */
            color: "#000000"
            border.color: root.cEdge
            border.width: 1

            ColumnLayout {
                id: content
                anchors.fill: parent
                anchors.margins: 12
                spacing: 4

                // ---- header ----
                RowLayout {
                    Layout.fillWidth: true
                    Text {
                        text: "SYSTEM"
                        color: root.cMagenta
                        font.family: "Hack"
                        font.bold: true
                        font.pixelSize: 11
                    }
                    Item { Layout.fillWidth: true }
                    Text {
                        text: hostname.value !== undefined ? String(hostname.value) : ""
                        color: root.cDim
                        font.family: "Hack"
                        font.pixelSize: 11
                    }
                }

                Rectangle {
                    Layout.fillWidth: true
                    Layout.topMargin: 2
                    Layout.bottomMargin: 4
                    height: 1
                    color: root.cEdge
                }

                /* Two columns: cores down the left, everything else down the
                 * right. The stacked single column ran ~270px tall; side by
                 * side it is roughly half that, which suits a corner of the
                 * desktop far better. */
                RowLayout {
                    Layout.fillWidth: true
                    spacing: 18

                    // ---- left: per-core CPU ----
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        spacing: 1

                        Repeater {
                            model: root.coreCount

                            HtopBar {
                                required property int index

                                /* One Sensor per delegate. Creating them here rather
                                 * than in a fixed list is what keeps this working on
                                 * a machine with a different core count. */
                                Sensors.Sensor {
                                    id: coreSensor
                                    sensorId: "cpu/cpu" + index + "/usage"
                                }

                                height: 13
                                labelWidth: 18
                                label: String(index + 1)
                                percent: root.num(coreSensor)
                                valueLabel: root.num(coreSensor).toFixed(1) + "%"
                                valueText: percent > 80 ? root.cMagenta : root.cCyan
                            }
                        }

                        /* Under the cores, and with both rate fields at a fixed
                         * width. formattedValue swings between "0 B/s" and
                         * "12.3 MiB/s", so letting these size to their content
                         * made the whole row shuffle on every tick. */
                        RowLayout {
                            Layout.topMargin: 6
                            spacing: 6
                            Text {
                                Layout.preferredWidth: 18
                                text: "NET"
                                color: root.cPurple
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Text {
                                text: "v"
                                color: root.cGreen
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Text {
                                Layout.preferredWidth: 66
                                horizontalAlignment: Text.AlignRight
                                text: netDown.formattedValue
                                color: root.cCyan
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Text {
                                text: "^"
                                color: root.cYellow
                                font.family: "Hack"; font.pixelSize: 11
                                leftPadding: 4
                            }
                            Text {
                                Layout.preferredWidth: 66
                                horizontalAlignment: Text.AlignRight
                                text: netUp.formattedValue
                                color: root.cCyan
                                font.family: "Hack"; font.pixelSize: 11
                            }
                        }
                    }

                    // ---- right: uptime, load, then the memory bars ----
                    ColumnLayout {
                        Layout.alignment: Qt.AlignTop
                        Layout.fillWidth: true
                        spacing: 1

                        RowLayout {
                            spacing: 6
                            Text {
                                Layout.preferredWidth: 38
                                text: "UP"
                                color: root.cPurple
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Text {
                                text: root.fmtUptime()
                                color: root.cCyan
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Item { Layout.fillWidth: true }
                        }

                        RowLayout {
                            spacing: 6
                            Text {
                                Layout.preferredWidth: 38
                                text: "LOAD"
                                color: root.cPurple
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Text {
                                text: root.fmtLoad(load1) + "  " + root.fmtLoad(load5) + "  " + root.fmtLoad(load15)
                                color: root.cCyan
                                font.family: "Hack"; font.pixelSize: 11
                            }
                            Item { Layout.fillWidth: true }
                        }

                        /* Fewer segments than the CPU bars: the right column is
                         * narrower, and these two carry a text value as well. */
                        HtopBar {
                            Layout.topMargin: 8
                            height: 13
                            labelWidth: 38
                            segments: 16
                            label: "MEM"
                            percent: root.num(memPercent)
                            flatColor: root.cCyan
                            valueLabel: memUsed.formattedValue
                        }

                        HtopBar {
                            height: 13
                            labelWidth: 38
                            segments: 16
                            label: "SWP"
                            percent: root.num(swapPercent)
                            flatColor: root.cPurple
                            valueLabel: swapUsed.formattedValue
                        }

                        Item { Layout.fillHeight: true }
                    }
                }
            }
        }
    }
}
