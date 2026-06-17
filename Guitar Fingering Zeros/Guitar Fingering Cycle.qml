import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0

MuseScore {
    id: root

    title: "Guitar Fingering Cycle"
    description: "Type one digit per selected note and automatically advance."
    version: "1.0"
    categoryCode: "composing-arranging-tools"
    requiresScore: true
    pluginType: "dialog"
    width: 340
    height: 220

    property var notes: []
    property var textRefs: []
    property int currentIndex: -1
    property bool suppressTextHandler: false
    property string statusMessage: ""

    function getChordForNote(note) {
        if (!note) {
            return null
        }
        if (note.type === Element.CHORD) {
            return note
        }
        return note.parent || null
    }

    function getNoteIndex(note, chord) {
        if (!note || !chord || !chord.notes) {
            return 0
        }

        for (var i = 0; i < chord.notes.length; ++i) {
            if (chord.notes[i] === note) {
                return i
            }
        }

        return 0
    }

    function noteKey(note) {
        var chord = getChordForNote(note)
        var tick = chord && chord.fraction ? chord.fraction.ticks : "no-tick"
        var track = note && note.track !== undefined ? note.track : (chord ? chord.track : "no-track")
        var pitch = note && note.pitch !== undefined ? note.pitch : "no-pitch"
        var index = getNoteIndex(note, chord)

        return track + ":" + tick + ":" + pitch + ":" + index
    }

    function anchorKey(note) {
        var chord = getChordForNote(note)
        var tick = chord && chord.fraction ? chord.fraction.ticks : "no-tick"
        return note.track + ":" + tick
    }

    function pushUniqueNote(note, outNotes, seen) {
        if (!note || note.type !== Element.NOTE) {
            return
        }

        var key = noteKey(note)
        if (seen[key]) {
            return
        }

        seen[key] = true
        outNotes.push(note)
    }

    function compareNotes(a, b) {
        var chordA = getChordForNote(a)
        var chordB = getChordForNote(b)
        var tickA = chordA && chordA.fraction ? chordA.fraction.ticks : 0
        var tickB = chordB && chordB.fraction ? chordB.fraction.ticks : 0

        if (tickA !== tickB) {
            return tickA - tickB
        }
        if (a.track !== b.track) {
            return a.track - b.track
        }

        var indexA = getNoteIndex(a, chordA)
        var indexB = getNoteIndex(b, chordB)
        if (indexA !== indexB) {
            return indexA - indexB
        }

        return a.pitch - b.pitch
    }

    function collectSelectedNotes() {
        var outNotes = []
        var seen = {}
        var elements = curScore.selection.elements

        for (var i = 0; i < elements.length; ++i) {
            var element = elements[i]

            if (!element) {
                continue
            }

            if (element.type === Element.NOTE) {
                pushUniqueNote(element, outNotes, seen)
                continue
            }

            if (element.type === Element.CHORD && element.notes) {
                for (var j = 0; j < element.notes.length; ++j) {
                    pushUniqueNote(element.notes[j], outNotes, seen)
                }
            }
        }

        outNotes.sort(compareNotes)
        return outNotes
    }

    function placementForTrack(track) {
        var voice = track % 4
        return (voice === 1 || voice === 3) ? Placement.BELOW : Placement.ABOVE
    }

    function staffTextsFor(note) {
        var chord = getChordForNote(note)
        var texts = []
        if (!chord || !chord.parent || !chord.parent.annotations) {
            return texts
        }

        for (var i = 0; i < chord.parent.annotations.length; ++i) {
            var element = chord.parent.annotations[i]
            if (element.track === note.track && element.type === Element.STAFF_TEXT) {
                texts.push(element)
            }
        }

        return texts
    }

    function createStaffTextFor(cursor, note) {
        var chord = getChordForNote(note)
        if (!chord || !chord.fraction) {
            return null
        }

        cursor.track = note.track
        cursor.rewindToFraction(chord.fraction)
        if (!cursor.segment) {
            return null
        }

        var text = newElement(Element.STAFF_TEXT)
        text.text = "0"
        text.autoplace = true
        text.placement = placementForTrack(note.track)
        cursor.add(text)
        return text
    }

    function prepareSelection() {
        if (!curScore || !curScore.selection || !curScore.selection.elements.length) {
            statusMessage = "Select one or more notes first."
            notes = []
            textRefs = []
            currentIndex = -1
            return
        }

        var selectedNotes = collectSelectedNotes()
        if (!selectedNotes.length) {
            statusMessage = "The current selection does not contain any notes."
            notes = []
            textRefs = []
            currentIndex = -1
            return
        }

        var newTextRefs = []
        var groups = {}
        var cursor = curScore.newCursor()

        curScore.startCmd("Prepare guitar fingering cycle")
        try {
            for (var i = 0; i < selectedNotes.length; ++i) {
                var note = selectedNotes[i]
                var key = anchorKey(note)
                if (!groups[key]) {
                    groups[key] = {
                        texts: staffTextsFor(note),
                        used: 0
                    }
                }

                var group = groups[key]
                var textRef = null

                if (group.used < group.texts.length) {
                    textRef = group.texts[group.used]
                } else {
                    textRef = createStaffTextFor(cursor, note)
                    if (textRef) {
                        group.texts.push(textRef)
                    }
                }

                group.used++
                newTextRefs.push(textRef)
            }

            curScore.endCmd()
        } catch (error) {
            curScore.endCmd(true)
            statusMessage = "Could not prepare the selected notes."
            notes = []
            textRefs = []
            currentIndex = -1
            return
        }

        notes = selectedNotes
        textRefs = newTextRefs
        currentIndex = notes.length ? 0 : -1
        statusMessage = notes.length + " selected note(s) loaded."
        selectCurrentNote()
        focusInput()
    }

    function selectCurrentNote() {
        if (currentIndex < 0 || currentIndex >= notes.length) {
            return
        }

        curScore.selection.clear()
        curScore.selection.select(notes[currentIndex])
    }

    function progressText() {
        if (!notes.length) {
            return "No note cycle loaded."
        }
        if (currentIndex >= notes.length) {
            return "Done: " + notes.length + " / " + notes.length
        }
        return "Note " + (currentIndex + 1) + " / " + notes.length
    }

    function currentTextValue() {
        if (currentIndex < 0 || currentIndex >= textRefs.length) {
            return ""
        }

        var textRef = textRefs[currentIndex]
        return textRef && textRef.text !== undefined ? textRef.text : ""
    }

    function focusInput() {
        suppressTextHandler = true
        digitInput.text = ""
        suppressTextHandler = false
        digitInput.forceActiveFocus()
    }

    function applyDigit(digit) {
        if (currentIndex < 0 || currentIndex >= textRefs.length) {
            return
        }

        var textRef = textRefs[currentIndex]
        if (!textRef) {
            statusMessage = "This note has no text item to edit."
            focusInput()
            return
        }

        curScore.startCmd("Set guitar fingering")
        try {
            textRef.text = digit
            curScore.endCmd()
        } catch (error) {
            curScore.endCmd(true)
            statusMessage = "Could not update the current fingering."
            focusInput()
            return
        }

        currentIndex++
        if (currentIndex >= notes.length) {
            curScore.selection.clear()
            statusMessage = "Done."
            focusInput()
            return
        }

        statusMessage = "Set fingering to " + digit + "."
        selectCurrentNote()
        focusInput()
    }

    function goPrevious() {
        if (!notes.length) {
            return
        }

        if (currentIndex > 0) {
            currentIndex--
        } else if (currentIndex >= notes.length) {
            currentIndex = notes.length - 1
        }

        statusMessage = "Moved back."
        selectCurrentNote()
        focusInput()
    }

    onRun: {
        prepareSelection()
    }

    ColumnLayout {
        anchors.fill: parent
        anchors.margins: 12
        spacing: 10

        Label {
            Layout.fillWidth: true
            text: "Type one digit to set the current fingering."
            wrapMode: Text.WordWrap
        }

        Label {
            Layout.fillWidth: true
            text: root.progressText()
            font.bold: true
        }

        TextField {
            id: digitInput
            Layout.fillWidth: true
            enabled: root.notes.length > 0 && root.currentIndex < root.notes.length
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 1
            placeholderText: enabled ? "Type 0-9" : "Load a note selection"

            onTextChanged: {
                if (root.suppressTextHandler) {
                    return
                }
                if (!text.length) {
                    return
                }
                if (text < "0" || text > "9") {
                    root.focusInput()
                    return
                }
                root.applyDigit(text)
            }
        }

        Label {
            Layout.fillWidth: true
            text: root.notes.length && root.currentIndex < root.notes.length
                ? "Current text: " + root.currentTextValue()
                : root.statusMessage
            wrapMode: Text.WordWrap
        }

        RowLayout {
            Layout.fillWidth: true
            spacing: 8

            Button {
                text: "Reload Selection"
                onClicked: root.prepareSelection()
            }

            Button {
                text: "Previous"
                enabled: root.notes.length > 0
                onClicked: root.goPrevious()
            }

            Item {
                Layout.fillWidth: true
            }

            Button {
                text: "Close"
                onClicked: quit()
            }
        }
    }
}
