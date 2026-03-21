import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0

MuseScore {
    id: root

    pluginType: "dialog"
    title: "Workflow Tools"
    width: 520
    height: 360

    // ── Logging ──────────────────────────────────────────────────────────────

    property var logLines: []

    function log(msg) {
        var now = new Date()
        var hh  = String(now.getHours()).padStart(2, "0")
        var mm  = String(now.getMinutes()).padStart(2, "0")
        var ss  = String(now.getSeconds()).padStart(2, "0")
        var ts  = "[" + hh + ":" + mm + ":" + ss + "] "
        logLines.push(ts + msg)
        debugOutput.text = logLines.join("\n")
        debugOutput.cursorPosition = debugOutput.length
    }

    // ── Selection snapshot ────────────────────────────────────────────────────

    function describeSelection() {
        if (!curScore) {
            return "No score open"
        }

        var sel = curScore.selection
        if (!sel) {
            return "No selection object"
        }

        var elements = sel.elements
        if (!elements || elements.length === 0) {
            return "Nothing selected"
        }

        // Collect unique element type names
        var counts = {}
        for (var i = 0; i < elements.length; i++) {
            var e = elements[i]
            var name = e.name !== undefined ? e.name : ("type:" + e.type)
            counts[name] = (counts[name] || 0) + 1
        }

        var parts = []
        for (var key in counts) {
            parts.push(counts[key] > 1 ? counts[key] + "× " + key : key)
        }

        return elements.length + " element(s): " + parts.join(", ")
    }

    // ── Polling timer ─────────────────────────────────────────────────────────

    property int pollCount: 0

    Timer {
        id: pollTimer
        interval: 100
        repeat: true
        running: false

        onTriggered: {
            root.pollCount++
            if (root.pollCount % 10 === 0) {
                root.log("Selection — " + root.describeSelection())
            }
        }
    }

    // ── Lifecycle ────────────────────────────────────────────────────────────

    Component.onCompleted: {
        log("Window opened")
        pollTimer.running = true
    }

    Component.onDestruction: {
        pollTimer.running = false
        log("Window closed")
    }

    // ── UI ───────────────────────────────────────────────────────────────────

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 10
        spacing: 6

        Label {
            text: "Debug Log"
            font.bold: true
            font.pixelSize: 13
        }

        ScrollView {
            Layout.fillWidth: true
            Layout.fillHeight: true
            clip: true

            TextArea {
                id: debugOutput
                readOnly: true
                wrapMode: TextEdit.Wrap
                font.family: "Monospace"
                font.pixelSize: 11
                background: Rectangle {
                    color: "#1e1e1e"
                    radius: 4
                }
                color: "#d4d4d4"
                leftPadding: 8
                rightPadding: 8
                topPadding: 6
                bottomPadding: 6
            }
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Clear"
                onClicked: {
                    root.logLines = []
                    debugOutput.text = ""
                }
            }

            Button {
                text: "Copy"
                onClicked: {
                    debugOutput.selectAll()
                    debugOutput.copy()
                    debugOutput.deselect()
                }
            }

            Item { Layout.fillWidth: true }

            Button {
                text: "Close"
                onClicked: {
                    pollTimer.running = false
                    log("Window closed")
                    quit()
                }
            }
        }
    }
}
