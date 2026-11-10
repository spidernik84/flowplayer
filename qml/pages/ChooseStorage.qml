import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

// First step of adding a music folder from Settings: where is the music stored?
Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    // The page to return to once the folder is added
    property Item returnPage

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col1.height + Theme.paddingLarge

        Column {
            id: col1
            width: parent.width

            Header {
                title: qsTr("Add folder")
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
                onPicked: pageStack.push("AddFolder.qml",
                                         {"currentPath":utils.findMusicFolder(base),
                                          "acceptDestination":root.returnPage,
                                          "acceptDestinationAction":PageStackAction.Pop})
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("The folder browser opens on the music folder: go up or down to choose another one.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }
        }

        VerticalScrollDecorator {}
    }
}
