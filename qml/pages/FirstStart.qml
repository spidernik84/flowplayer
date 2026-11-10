import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

// Shown once, while no music folder is set: asks where the music is stored
Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    // The start page behind would show an empty library: choose or skip
    backNavigation: false

    // Opens the folder browser on the music folder found inside base
    function pickFolder(base) {
        pageStack.push("AddFolder.qml", {"currentPath":utils.findMusicFolder(base),
                                         "firstStart":true,
                                         "acceptDestination":startPage,
                                         "acceptDestinationAction":PageStackAction.Pop})
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col1.height + Theme.paddingLarge

        Column {
            id: col1
            width: parent.width

            // Keeps the icon clear of the display notch
            Item {
                width: parent.width
                height: Theme.paddingLarge*2 + (root.orientation===Orientation.Portrait ? Screen.topCutout.height : 0)
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeExtraLarge
                height: width
                source: "../../../icons/hicolor/172x172/apps/harbour-flowplayer-ng.png"
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("Welcome to FlowPlayer")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("A music player for Sailfish OS with lyrics, online radio and a 10-band equalizer.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge*2
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("Where is your music stored?")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            StorageList {
                onPicked: pickFolder(base)
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("You can add more music folders later in Settings.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Skip")
                onClicked: {
                    utils.setSettings("FirstStartDone", "yes")
                    pageStack.pop()
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
