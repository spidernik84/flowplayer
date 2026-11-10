import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool loaded: false

    // Set once a folder is added or removed: the collection is out of date
    property bool changed: false

    onStatusChanged: {
        if (status===PageStatus.Activating && !loaded) {
            foldersModel.clear()
            utils.getFolders()
            loaded = true
        }
    }

    ListModel { id: foldersModel }

    Connections {
        target: utils

        onAddFolder: {
            foldersModel.append({"name":name, "path":path})
        }

        onFoldersChanged: {
            root.changed = true
            foldersModel.clear()
            utils.getFolders()
        }
    }


    SilicaListView {
        id: flist
        anchors.fill: parent
        anchors.bottomMargin: rescanBar.visible ? rescanBar.height : 0
        clip: true

        model: foldersModel

        PullDownMenu {
            MenuItem {
                text: qsTr("Add folder")
                onClicked: pageStack.push("ChooseStorage.qml", {"returnPage":root})
            }
        }

        header: Header {
            title: qsTr("Manage folders")
        }

        delegate: ListItem {
            contentHeight: Theme.itemSizeSmall
            width: parent.width
            clip: true

            menu: contextMenu

            function removeItem() {
                remorseAction(qsTr("Deleting"),
                function() {
                    utils.removeFolder(model.path)
                    foldersModel.remove(model.index, 1)
                    root.changed = true
                })
            }

            Component {
                id: contextMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: {
                            removeItem()
                        }
                    }
                }
            }

            Image {
                id: licon
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter
                source: "image://theme/icon-m-folder"
            }

            Column {
                anchors.left: licon.right
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter

                Label
                {
                    width: parent.width
                    text: model.name
                    truncationMode: TruncationMode.Fade
                    color: Theme.primaryColor
                }

                Label
                {
                    width: parent.width
                    text: model.path
                    truncationMode: TruncationMode.Fade
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    opacity: 0.8
                }
            }
        }

        ViewPlaceholder {
            enabled: foldersModel.count===0
            flickable: flist
            text: qsTr("No folders")
        }

    }

    // Offers to update the collection with the folder changes
    Rectangle {
        id: rescanBar
        visible: root.changed
        anchors.bottom: parent.bottom
        width: parent.width
        height: rescanCol.height + Theme.paddingLarge*2
        color: Theme.rgba(Theme.highlightBackgroundColor, 0.15)

        Column {
            id: rescanCol
            anchors.centerIn: parent
            width: parent.width - Theme.horizontalPageMargin*2
            spacing: Theme.paddingMedium

            Label {
                width: parent.width
                text: qsTr("Folders changed. Rescan the collection to update it.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Rescan now")
                onClicked: {
                    database.readMusic()
                    // The start page shows the scan and its summary
                    pageStack.pop(startPage)
                }
            }
        }
    }
}
