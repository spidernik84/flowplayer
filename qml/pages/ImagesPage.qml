import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    SilicaFlickable {
        id: flickArea
        anchors.fill: parent
        contentWidth: width
        contentHeight: column.height + Theme.paddingLarge
        clip: true

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingMedium

            Header {
                title: qsTr("Images")
            }

            SectionHeader {
                text: qsTr("Album covers")
            }

            ListItem {
                width: parent.width
                height: Theme.itemSizeSmall
                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingLarge
                    anchors.right: coversIcon.left
                    anchors.rightMargin: Theme.paddingLarge
                    anchors.verticalCenter: parent.verticalCenter
                    text: qsTr("Download missing album covers")
                }
                Image {
                    id: coversIcon
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingMedium
                    anchors.verticalCenter: parent.verticalCenter
                    source: "image://theme/icon-m-right"
                }
                onClicked: pageStack.push("FullAlbumSearch.qml")
            }

        }

    }

}
