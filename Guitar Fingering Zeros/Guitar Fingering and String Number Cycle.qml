import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15
import MuseScore 3.0

MuseScore {
    id: root

    title: "Guitar Fingering and String Number Cycle"
    description: "Type a fingering digit and then a string number for each selected note."
    version: "1.0"
    categoryCode: "composing-arranging-tools"
    requiresScore: true
    pluginType: "dialog"
    width: 360
    height: 240

    property var notes: []
    property var fingeringRefs: []
    property var stringNumberRefs: []
    property int stepIndex: -1
    property bool suppressTextHandler: false
    property string statusMessage: ""
    property real fingeringLiftY: -2.5
    property int stringNumberSubStyle: 44

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

    function createElementOfType(typeValue) {
        try {
            return newElement(typeValue)
        } catch (error) {
            return null
        }
    }

    function createStringNumberElement() {
        var fingering = createElementOfType(Element.FINGERING)
        if (!fingering) {
            return null
        }

        fingering.subStyle = stringNumberSubStyle
        return fingering
    }

    function createFingeringElement() {
        return createElementOfType(Element.FINGERING)
    }

    function addElement(cursor, note, element, textValue, offsetYValue) {
        var chord = getChordForNote(note)
        if (!element || !chord || !chord.fraction) {
            return null
        }

        cursor.track = note.track
        cursor.rewindToFraction(chord.fraction)
        if (!cursor.segment) {
            return null
        }

        element.text = textValue
        element.autoplace = true
        element.placement = placementForTrack(note.track)
        if (offsetYValue !== null && offsetYValue !== undefined) {
            element.offsetY = offsetYValue
        }
        cursor.add(element)
        return element
    }

    function totalSteps() {
        return notes.length * 2
    }

    function hasActiveStep() {
        return stepIndex >= 0 && stepIndex < totalSteps()
    }

    function activeNoteIndex() {
        if (!hasActiveStep()) {
            return -1
        }
        return Math.floor(stepIndex / 2)
    }

    function isFingeringStep() {
        return hasActiveStep() && stepIndex % 2 === 0
    }

    function currentStepLabel() {
        return isFingeringStep() ? "fingering" : "string number"
    }

    function valueText(ref) {
        return ref && ref.text !== undefined ? ref.text : ""
    }

    function pairTextFor(noteIndex) {
        if (noteIndex < 0 || noteIndex >= notes.length) {
            return ""
        }

        return "Fingering: " + valueText(fingeringRefs[noteIndex])
            + " | String: " + valueText(stringNumberRefs[noteIndex])
    }

    function prepareSelection() {
        if (!curScore || !curScore.selection || !curScore.selection.elements.length) {
            statusMessage = "Select one or more notes first."
            notes = []
            fingeringRefs = []
            stringNumberRefs = []
            stepIndex = -1
            return
        }

        var selectedNotes = collectSelectedNotes()
        if (!selectedNotes.length) {
            statusMessage = "The current selection does not contain any notes."
            notes = []
            fingeringRefs = []
            stringNumberRefs = []
            stepIndex = -1
            return
        }

        var newFingeringRefs = []
        var newStringNumberRefs = []
        var cursor = curScore.newCursor()

        curScore.startCmd("Prepare guitar fingering/string cycle")
        try {
            for (var i = 0; i < selectedNotes.length; ++i) {
                var note = selectedNotes[i]

                var stringNumberRef = addElement(cursor, note, createStringNumberElement(), "0", null)
                var fingeringRef = addElement(cursor, note, createFingeringElement(), "0", fingeringLiftY)

                if (!stringNumberRef || !fingeringRef) {
                    throw new Error("Could not create stacked texts for note " + i)
                }

                newStringNumberRefs.push(stringNumberRef)
                newFingeringRefs.push(fingeringRef)
            }

            curScore.endCmd()
        } catch (error) {
            curScore.endCmd(true)
            statusMessage = "Could not prepare the selected notes."
            notes = []
            fingeringRefs = []
            stringNumberRefs = []
            stepIndex = -1
            console.log("Guitar Fingering and String Number Cycle error: " + error)
            return
        }

        notes = selectedNotes
        fingeringRefs = newFingeringRefs
        stringNumberRefs = newStringNumberRefs
        stepIndex = notes.length ? 0 : -1
        statusMessage = notes.length + " selected note(s) loaded."
        selectCurrentNote()
        focusInput()
    }

    function selectCurrentNote() {
        var noteIndex = activeNoteIndex()
        if (noteIndex < 0 || noteIndex >= notes.length) {
            return
        }

        curScore.selection.clear()
        curScore.selection.select(notes[noteIndex])
    }

    function progressText() {
        if (!notes.length) {
            return "No note cycle loaded."
        }
        if (stepIndex >= totalSteps()) {
            return "Done: " + notes.length + " / " + notes.length
        }
        return "Note " + (activeNoteIndex() + 1) + " / " + notes.length + " - " + currentStepLabel()
    }

    function focusInput() {
        suppressTextHandler = true
        digitInput.text = ""
        suppressTextHandler = false
        digitInput.forceActiveFocus()
    }

    function applyDigit(digit) {
        if (!hasActiveStep()) {
            return
        }

        var noteIndex = activeNoteIndex()
        var editingFingering = isFingeringStep()
        var textRef = editingFingering ? fingeringRefs[noteIndex] : stringNumberRefs[noteIndex]

        if (!textRef) {
            statusMessage = "This note has no text item to edit."
            focusInput()
            return
        }

        curScore.startCmd(editingFingering ? "Set guitar fingering" : "Set guitar string number")
        try {
            textRef.text = digit
            curScore.endCmd()
        } catch (error) {
            curScore.endCmd(true)
            statusMessage = editingFingering
                ? "Could not update the current fingering."
                : "Could not update the current string number."
            focusInput()
            return
        }

        stepIndex++
        if (stepIndex >= totalSteps()) {
            curScore.selection.clear()
            statusMessage = "Done."
            focusInput()
            return
        }

        statusMessage = editingFingering
            ? "Set fingering to " + digit + "."
            : "Set string number to " + digit + "."
        selectCurrentNote()
        focusInput()
    }

    function goPrevious() {
        if (!notes.length) {
            return
        }

        if (stepIndex > 0 && stepIndex <= totalSteps()) {
            stepIndex--
        } else if (stepIndex >= totalSteps()) {
            stepIndex = totalSteps() - 1
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
            text: "Type one fingering digit first, then the matching string number for each selected note."
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
            enabled: root.notes.length > 0 && root.stepIndex < root.totalSteps()
            inputMethodHints: Qt.ImhDigitsOnly
            maximumLength: 1
            placeholderText: enabled ? "Type 0-9 for " + root.currentStepLabel() : "Load a note selection"

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
            text: root.notes.length && root.hasActiveStep()
                ? root.pairTextFor(root.activeNoteIndex())
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
