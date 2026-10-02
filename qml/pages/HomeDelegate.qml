import QtQuick 2.0
import Sailfish.Silica 1.0

// Row of the start page: tinted theme icon, title and an optional subtitle
ListItem {
    id: item

    property alias title: titleLabel.text
    property alias subtitle: subtitleLabel.text
    property alias iconSource: icon.source
    property color titleColor: Theme.primaryColor

    contentHeight: Theme.itemSizeLarge

    Rectangle {
        id: iconBackground
        x: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter
        width: Theme.iconSizeMedium + Theme.paddingMedium*2
        height: width
        radius: Theme.paddingMedium
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)

        HighlightImage {
            id: icon
            anchors.centerIn: parent
            width: Theme.iconSizeMedium
            height: width
            sourceSize.width: width
            sourceSize.height: height
            color: Theme.highlightColor
            highlighted: item.highlighted
        }
    }

    Column {
        anchors.left: iconBackground.right
        anchors.leftMargin: Theme.paddingLarge
        anchors.right: parent.right
        anchors.rightMargin: Theme.horizontalPageMargin
        anchors.verticalCenter: parent.verticalCenter

        Label {
            id: titleLabel
            width: parent.width
            font.pixelSize: Theme.fontSizeLarge
            color: item.highlighted ? Theme.highlightColor : item.titleColor
            truncationMode: TruncationMode.Fade
        }

        Label {
            id: subtitleLabel
            width: parent.width
            visible: text!==""
            font.pixelSize: Theme.fontSizeSmall
            color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            truncationMode: TruncationMode.Fade
        }
    }
}
