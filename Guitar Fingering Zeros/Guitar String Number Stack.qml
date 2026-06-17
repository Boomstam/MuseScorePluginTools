import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    title: "Guitar String Number Stack"
    description: "Adds a string number plus a stacked fingering text to each selected note."
    version: "1.0"
    categoryCode: "composing-arranging-tools"
    requiresScore: true

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

    function pushUniqueNote(note, notes, seen) {
        if (!note || note.type !== Element.NOTE) {
            return
        }

        var key = noteKey(note)
        if (seen[key]) {
            return
        }

        seen[key] = true
        notes.push(note)
    }

    function collectSelectedNotes() {
        var notes = []
        var seen = {}
        var elements = curScore.selection.elements

        for (var i = 0; i < elements.length; ++i) {
            var element = elements[i]

            if (!element) {
                continue
            }

            if (element.type === Element.NOTE) {
                pushUniqueNote(element, notes, seen)
                continue
            }

            if (element.type === Element.CHORD && element.notes) {
                for (var j = 0; j < element.notes.length; ++j) {
                    pushUniqueNote(element.notes[j], notes, seen)
                }
            }
        }

        return notes
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

    function addElement(cursor, note, element, placement, textValue, offsetYValue) {
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
        element.placement = placement
        if (offsetYValue !== null && offsetYValue !== undefined) {
            element.offsetY = offsetYValue
        }
        cursor.add(element)
        return element
    }

    function addStackedTexts(cursor, note) {
        var chord = getChordForNote(note)
        if (!chord || !chord.fraction) {
            return false
        }

        var placement = placementForTrack(note.track)

        var stringNumber = createStringNumberElement()
        stringNumber = addElement(cursor, note, stringNumber, placement, "0", null)
        if (!stringNumber) {
            return false
        }

        var fingering = createFingeringElement()
        fingering = addElement(cursor, note, fingering, placement, "0", fingeringLiftY)
        if (!fingering) {
            return false
        }

        return true
    }

    onRun: {
        if (!curScore || !curScore.selection || !curScore.selection.elements.length) {
            Qt.quit()
            return
        }

        var notes = collectSelectedNotes()
        if (!notes.length) {
            Qt.quit()
            return
        }

        var cursor = curScore.newCursor()
        curScore.startCmd("Add guitar string number stack")

        try {
            for (var i = 0; i < notes.length; ++i) {
                addStackedTexts(cursor, notes[i])
            }
            curScore.endCmd()
        } catch (error) {
            curScore.endCmd(true)
            console.log("Guitar String Number Stack error: " + error)
        }

        Qt.quit()
    }
}
