import QtQuick 2.0
import MuseScore 3.0

MuseScore {
    title: "Range Text to Fingering"
    description: "Converts single-digit text elements in the selected range into fingerings."
    version: "1.0"
    categoryCode: "composing-arranging-tools"
    requiresScore: true

    function getRangeSelection() {
        if (!curScore || !curScore.selection || !curScore.selection.isRange) {
            return null
        }

        if (!curScore.selection.elements || !curScore.selection.elements.length) {
            return null
        }

        var SELECTION_START = 1
        var SELECTION_END = 2
        var cursor = curScore.newCursor()

        cursor.rewind(SELECTION_START)
        if (!cursor.segment) {
            return null
        }

        var startStaff = cursor.staffIdx
        var startTick = cursor.tick

        cursor.rewind(SELECTION_END)

        return {
            startStaff: startStaff,
            endStaff: cursor.staffIdx,
            startTick: startTick,
            endTick: cursor.tick === 0 ? curScore.lastSegment.tick + 1 : cursor.tick
        }
    }

    function placementForTrack(track) {
        var voice = track % 4
        return (voice === 1 || voice === 3) ? Placement.BELOW : Placement.ABOVE
    }

    function plainTextValue(text) {
        if (text === undefined || text === null) {
            return ""
        }

        return String(text)
            .replace(/<[^>]*>/g, "")
            .replace(/\s+/g, "")
    }

    function extractConvertibleDigit(element) {
        if (!element || element.type === Element.FINGERING) {
            return null
        }

        if (element.text === undefined || element.text === null) {
            return null
        }

        var normalized = plainTextValue(element.text)
        return /^[0-5]$/.test(normalized) ? normalized : null
    }

    function createFingeringFrom(source, digit) {
        var fingering = newElement(Element.FINGERING)
        fingering.text = digit
        fingering.autoplace = source.autoplace !== undefined ? source.autoplace : true
        fingering.placement = source.placement !== undefined ? source.placement : placementForTrack(source.track)

        if (source.offsetX !== undefined) {
            fingering.offsetX = source.offsetX
        }
        if (source.offsetY !== undefined) {
            fingering.offsetY = source.offsetY
        }
        if (source.visible !== undefined) {
            fingering.visible = source.visible
        }

        return fingering
    }

    function targetsForTrack(segment, track) {
        var targets = []
        if (!segment || !segment.annotations) {
            return targets
        }

        for (var i = 0; i < segment.annotations.length; ++i) {
            var annotation = segment.annotations[i]
            if (!annotation || annotation.track !== track) {
                continue
            }

            var digit = extractConvertibleDigit(annotation)
            if (!digit) {
                continue
            }

            targets.push({
                source: annotation,
                digit: digit
            })
        }

        return targets
    }

    function convertTargetsAtCursor(cursor, track) {
        var converted = 0
        var targets = targetsForTrack(cursor.segment, track)

        for (var i = 0; i < targets.length; ++i) {
            var target = targets[i]
            var fingering = createFingeringFrom(target.source, target.digit)
            cursor.add(fingering)
            removeElement(target.source)
            converted++
        }

        return converted
    }

    function convertRange(range) {
        var SELECTION_START = 1
        var cursor = curScore.newCursor()
        var converted = 0

        for (var staff = range.startStaff; staff <= range.endStaff; ++staff) {
            for (var voice = 0; voice < 4; ++voice) {
                var track = (staff * 4) + voice
                cursor.rewind(SELECTION_START)
                cursor.voice = voice
                cursor.staffIdx = staff

                while (cursor.segment && cursor.tick < range.endTick) {
                    converted += convertTargetsAtCursor(cursor, track)
                    cursor.next()
                }
            }
        }

        return converted
    }

    onRun: {
        if (!curScore) {
            Qt.quit()
            return
        }

        var range = getRangeSelection()
        if (!range) {
            console.log("Range Text to Fingering: make a range selection first.")
            Qt.quit()
            return
        }

        var converted = 0

        curScore.startCmd("Convert range text to fingering")
        try {
            converted = convertRange(range)
            if (converted) {
                curScore.endCmd()
            } else {
                curScore.endCmd(true)
            }
        } catch (error) {
            curScore.endCmd(true)
            console.log("Range Text to Fingering error: " + error)
        }

        Qt.quit()
    }
}
