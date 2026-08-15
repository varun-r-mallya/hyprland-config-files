import QtQuick
import "../Theme"

Column {
    id: root
    spacing: 4
    property date now: new Date()

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 95
        font.weight: Font.Medium
        text: Qt.formatTime(root.now, "HH:mm")
    }

    Text {
        anchors.horizontalCenter: parent.horizontalCenter
        color: Theme.foreground
        font.family: Theme.fontFamily
        font.pixelSize: 35
        font.weight: Font.Light
        text: Qt.formatDate(root.now, "dd MMMM, yyyy")
    }

    Timer {
        interval: 1000
        running: true
        repeat: true
        onTriggered: root.now = new Date()
    }
}
