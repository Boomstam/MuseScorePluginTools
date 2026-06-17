function logStep(message) {
    api.log.info("[Workflow Tools Tuplets][Paste] " + message)
}

function fail(message) {
    logStep("FAIL: " + message)
    api.interactive.info("Paste Tuplet", "Failed: " + message)
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
            logStep("Using target tuplet candidate at tick " + tuplet.fraction.ticks + " on track " + tuplet.track)
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

    var clipboard = api.workflowToolsTupletClipboard
    if (!clipboard) {
        fail("No tuplet clipboard found on the extension API object. Copy first, then paste in the same MuseScore session.")
        return
    }

    logStep("Found clipboard copied at " + clipboard.copiedAt)
    logStep("Clipboard ratio is " + clipboard.actualNotes + ":" + clipboard.normalNotes)

    var score = getScore()
    if (!score) {
        fail("No active score.")
        return
    }

    var selection = getSelection(score)
    var elements = getSelectionElements(selection)
    logStep("Selection contains " + elements.length + " element(s)")

    if (!elements.length) {
        fail("Select a target tuplet or notes/rests inside one target tuplet first.")
        return
    }

    var targetTuplet = findSingleTuplet(elements)
    if (!targetTuplet) {
        fail("Selection must resolve to exactly one top-level target tuplet.")
        return
    }

    var targetSlotCount = targetTuplet.elements ? targetTuplet.elements.length : 0
    logStep("Target ratio is " + targetTuplet.actualNotes + ":" + targetTuplet.normalNotes)
    logStep("Target direct child count is " + targetSlotCount)

    if (targetTuplet.actualNotes !== clipboard.actualNotes || targetTuplet.normalNotes !== clipboard.normalNotes) {
        fail(
            "Ratio mismatch. Clipboard is " + clipboard.actualNotes + ":" + clipboard.normalNotes +
            ", target is " + targetTuplet.actualNotes + ":" + targetTuplet.normalNotes + "."
        )
        return
    }

    if (targetSlotCount !== clipboard.slotCount) {
        fail(
            "Slot-count mismatch. Clipboard has " + clipboard.slotCount +
            " direct child element(s), target has " + targetSlotCount + "."
        )
        return
    }

    logStep("Validation passed")
    logStep("Paste mutation is intentionally not implemented yet in this extension prototype")

    api.interactive.info(
        "Paste Tuplet",
        "Clipboard and target tuplet matched successfully." +
        "\n\nThis prototype currently stops after validation so we can verify action wiring, shortcut reachability, and clipboard persistence first."
    )
}
