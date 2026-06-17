function logStep(message) {
    api.log.info("[Guitar Fingering Zeros] " + message)
}

function fail(message) {
    logStep("FAIL: " + message)
    api.interactive.info("Guitar Fingering Zeros", message)
}

function getScore() {
    return (api.engraving && api.engraving.curScore) || curScore || null
}

function getSelectionElements(score) {
    if (!score || !score.selection || !score.selection.elements) {
        return []
    }
    return score.selection.elements
}

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

function collectSelectedNotes(elements) {
    var notes = []
    var seen = {}

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

function addZeroText(cursor, note) {
    var chord = getChordForNote(note)
    if (!chord || !chord.fraction) {
        return false
    }

    cursor.track = note.track
    cursor.rewindToFraction(chord.fraction)

    if (!cursor.segment) {
        return false
    }

    var text = newElement(Element.STAFF_TEXT)
    text.text = "0"
    text.autoplace = true
    text.placement = placementForTrack(note.track)
    cursor.add(text)

    return true
}

function main() {
    logStep("Action invoked")

    var score = getScore()
    if (!score) {
        fail("No active score.")
        return
    }

    var elements = getSelectionElements(score)
    if (!elements.length) {
        fail("Select one or more notes first.")
        return
    }

    var notes = collectSelectedNotes(elements)
    logStep("Resolved " + notes.length + " selected note(s)")

    if (!notes.length) {
        fail("The current selection does not contain any notes.")
        return
    }

    var cursor = score.newCursor()
    var addedCount = 0

    score.startCmd("Add guitar fingering zeros")

    try {
        for (var i = 0; i < notes.length; ++i) {
            if (addZeroText(cursor, notes[i])) {
                addedCount++
            }
        }

        score.endCmd()
    } catch (error) {
        score.endCmd(true)
        fail("MuseScore could not add the text items: " + error)
        return
    }

    if (!addedCount) {
        fail("No text items were added.")
        return
    }

    logStep("Added " + addedCount + " text item(s)")
    api.interactive.info(
        "Guitar Fingering Zeros",
        "Added " + addedCount + " separate text item(s), each initialized to 0."
    )
}
