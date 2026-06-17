import QtQuick 2.15

import MuseApi.Extensions 1.0
import MuseApi.Controls 1.0

ExtensionBlank {
    id: root

    implicitWidth: 520
    implicitHeight: 260
    color: api.theme.backgroundPrimaryColor

    Component.onCompleted: {
        api.log.info("[Workflow Tools Tuplets][About] Form opened")
    }

    StyledTextLabel {
        id: titleLabel
        anchors.left: parent.left
        anchors.top: parent.top
        anchors.margins: 16
        text: "Workflow Tools Tuplets"
    }

    StyledTextLabel {
        anchors.left: titleLabel.left
        anchors.right: parent.right
        anchors.top: titleLabel.bottom
        anchors.topMargin: 12
        anchors.rightMargin: 16
        wrapMode: Text.WordWrap
        text: "This MuseScore 4 extension prototype adds Copy Tuplet and Paste Tuplet actions. It logs every useful step through api.log and uses an experimental clipboard stored on the global api object. The manifest also includes Meta+Shift+C and Meta+Shift+V shortcut hints, which still need in-app verification because bundled extensions do not document shortcut support."
    }
}
