function logStep(message) {
    api.log.info("[Workflow Tools Tuplets][Copy] " + message)
}

function fail(message) {
    logStep("FAIL: " + message)
    api.interactive.info("Copy Tuplet", "Failed: " + message)
}

function getScore() {
    return (api.engraving && api.engraving.curScore) || curScore || null
}

function getSelection(score) {
    return score && score.selection ? score.selection : null
}

function getSelectionElements(selection) {
    if (!selection || !selection.elements) {
        return []
    }
    return selection.elements
}

function elementLabel(element) {
    if (!element) {
        return "null"
    }
    if (element.name !== undefined && element.name !== "") {
        return element.name
    }
    return "type:" + element.type
}

function normalizeChordRest(element) {
    if (!element) {
        return null
    }
    if (element.type === Element.NOTE) {
        element = element.parent
    }
    if (element.type === Element.CHORD && element.noteType !== NoteType.NORMAL) {
        element = element.parent
    }
    return element
}

function getTopTuplet(element) {
    var normalized = normalizeChordRest(element)
    if (!normalized) {
        return null
    }
    if (normalized.type === Element.TUPLET) {
        return normalized.topTuplet ? normalized.topTuplet : normalized
    }
    if (normalized.type === Element.CHORD || normalized.type === Element.REST) {
        return normalized.topTuplet ? normalized.topTuplet : null
    }
    return null
}

function summarizeElements(elements) {
    var counts = {}
    for (var i = 0; i < elements.length; ++i) {
        var label = elementLabel(elements[i])
        counts[label] = (counts[label] || 0) + 1
    }

    var parts = []
    for (var key in counts) {
        parts.push(counts[key] > 1 ? counts[key] + "x " + key : key)
    }
    return parts.join(", ")
}

function getTupletElements(tuplet) {
    var items = []
    if (!tuplet || !tuplet.elements) {
        return items
    }

    for (var i = 0; i < tuplet.elements.length; ++i) {
        var element = tuplet.elements[i]
        if (element.type === Element.TUPLET) {
            items.push(serializeTuplet(element))
        } else {
            items.push(serializeChordRest(element))
        }
    }
    return items
}

function serializeNotes(chord) {
    var notes = []
    if (!chord || chord.type !== Element.CHORD) {
        return notes
    }

    for (var i = 0; i < chord.notes.length; ++i) {
        var note = chord.notes[i]
        notes.push({
            pitch: note.pitch,
            tpc1: note.tpc1,
            tpc2: note.tpc2,
            accidentalType: note.accidentalType
        })
    }
    return notes
}

function serializeChordRest(element) {
    return {
        type: element.type,
        track: element.track,
        startTick: element.fraction ? element.fraction.ticks : null,
        durationNumerator: element.duration ? element.duration.numerator : null,
        durationDenominator: element.duration ? element.duration.denominator : null,
        actualTicks: element.actualDuration ? element.actualDuration.ticks : null,
        notes: serializeNotes(element)
    }
}

function serializeTuplet(tuplet) {
    return {
        type: Element.TUPLET,
        track: tuplet.track,
        startTick: tuplet.fraction ? tuplet.fraction.ticks : null,
        durationNumerator: tuplet.duration ? tuplet.duration.numerator : null,
        durationDenominator: tuplet.duration ? tuplet.duration.denominator : null,
        actualTicks: tuplet.actualDuration ? tuplet.actualDuration.ticks : null,
        actualNotes: tuplet.actualNotes,
        normalNotes: tuplet.normalNotes,
        elements: getTupletElements(tuplet)
    }
}

function findSingleTuplet(selectionElements) {
    var tuplet = null
    for (var i = 0; i < selectionElements.length; ++i) {
        var candidate = getTopTuplet(selectionElements[i])
        if (!candidate) {
            logStep("Ignoring non-tuplet element: " + elementLabel(selectionElements[i]))
            continue
        }

        if (!tuplet) {
            tuplet = candidate
            logStep("Using tuplet candidate at tick " + tuplet.fraction.ticks + " on track " + tuplet.track)
            continue
        }

        if (candidate !== tuplet) {
            return null
        }
    }
    return tuplet
}

function main() {
    logStep("Action invoked")

    var score = getScore()
    if (!score) {
        fail("No active score.")
        return
    }

    var selection = getSelection(score)
    var elements = getSelectionElements(selection)
    logStep("Selection contains " + elements.length + " element(s)")

    if (!elements.length) {
        fail("Select a tuplet or notes/rests inside one tuplet first.")
        return
    }

    logStep("Selection summary: " + summarizeElements(elements))

    var tuplet = findSingleTuplet(elements)
    if (!tuplet) {
        fail("Selection must resolve to exactly one top-level tuplet.")
        return
    }

    var payload = serializeTuplet(tuplet)
    payload.copiedAt = new Date().toISOString()
    payload.sourceSummary = "track " + tuplet.track + ", tick " + tuplet.fraction.ticks
    payload.slotCount = tuplet.elements ? tuplet.elements.length : 0

    api.workflowToolsTupletClipboard = payload

    logStep("Serialized tuplet ratio " + payload.actualNotes + ":" + payload.normalNotes)
    logStep("Serialized " + payload.slotCount + " direct child element(s)")
    logStep("Stored clipboard on api.workflowToolsTupletClipboard")

    api.interactive.info(
        "Copy Tuplet",
        "Captured tuplet " + payload.actualNotes + ":" + payload.normalNotes +
        " with " + payload.slotCount + " direct child element(s)." +
        "\n\nNext step: assign this action to Command+Shift+C if MuseScore exposes extension actions in shortcuts."
    )
}
