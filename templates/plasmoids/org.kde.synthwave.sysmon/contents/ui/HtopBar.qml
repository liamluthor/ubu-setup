/*
 * One htop-style bracketed bar: [|||||||       ] 32.4%
 *
 * The segments are individual Rectangles rather than a Canvas. A Canvas would
 * repaint the whole bar every tick; these only change colour, which Qt Quick
 * batches into the scene graph and updates cheaply. At 8 cores x 28 segments
 * that is 224 rectangles, which is nothing for the renderer and much less work
 * than 8 canvases redrawing twice a second.
 */
import QtQuick

Row {
    id: bar

    property string label: ""
    property real percent: 0
    property int segments: 28
    property color labelColor: "#7e63a8"
    property color valueText: "#00e5e5"
    /* When set, every filled segment uses this instead of the load gradient —
     * memory and swap are not "hotter" the fuller they get, so ramping them
     * cyan-to-magenta would imply an alarm that isn't there. */
    property color flatColor: "transparent"
    property string valueLabel: ""
    property int labelWidth: 30

    spacing: 0

    /* Cyan when idle through magenta when pinned: the palette's own two poles,
     * so a busy core reads as hot without introducing a colour from outside
     * the scheme. */
    function segmentColor(i) {
        if (flatColor != "transparent") {
            return flatColor;
        }
        const t = Math.pow(i / bar.segments, 0.85);
        return Qt.rgba((0 + (255 - 0) * t) / 255,
                       (229 + (59 - 229) * t) / 255,
                       (229 + (255 - 229) * t) / 255,
                       1.0);
    }

    Text {
        width: bar.labelWidth
        text: bar.label
        color: bar.labelColor
        font.family: "Hack"
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        height: parent.height
    }

    Text {
        text: "["
        color: bar.labelColor
        font.family: "Hack"
        font.pixelSize: 11
        verticalAlignment: Text.AlignVCenter
        height: parent.height
    }

    Row {
        spacing: 1
        height: parent.height

        Repeater {
            model: bar.segments

            Rectangle {
                required property int index

                readonly property bool lit:
                    index < Math.round(bar.segments * Math.min(100, Math.max(0, bar.percent)) / 100)

                width: 3
                height: lit ? 8 : 2
                anchors.verticalCenter: parent.verticalCenter
                color: lit ? bar.segmentColor(index) : "#1c1628"
            }
        }
    }

    Text {
        text: "]"
        color: bar.labelColor
        font.family: "Hack"
        font.pixelSize: 11
        leftPadding: 2
        verticalAlignment: Text.AlignVCenter
        height: parent.height
    }

    Text {
        text: bar.valueLabel
        color: bar.valueText
        font.family: "Hack"
        font.pixelSize: 11
        leftPadding: 6
        verticalAlignment: Text.AlignVCenter
        height: parent.height
    }
}
