import QtQuick 2.0
import Sailfish.Silica 1.0

// An icon with a caption, for the bar shown while editing a list
BackgroundItem {
    id: button

    property string icon
    property alias text: label.text

    height: parent.height
    opacity: enabled ? 1 : 0.4

    Column {
        anchors.centerIn: parent

        Image {
            anchors.horizontalCenter: parent.horizontalCenter
            source: button.icon + "?" + (button.highlighted ? Theme.highlightColor : Theme.primaryColor)
        }

        Label {
            id: label
            anchors.horizontalCenter: parent.horizontalCenter
            width: Math.min(implicitWidth, button.width - 2*Theme.paddingSmall)
            truncationMode: TruncationMode.Fade
            font.pixelSize: Theme.fontSizeTiny
            color: button.highlighted ? Theme.highlightColor : Theme.primaryColor
        }
    }
}
