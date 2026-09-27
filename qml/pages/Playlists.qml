import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: foldersPage

    allowedOrientations: appWindow.pagesOrientations

    SilicaListView {
        id: songlist
        anchors.fill: parent

        model: myPlaylists

        PullDownMenu {
            MenuItem {
                text: qsTr("New playlist")
                onClicked: pageStack.push("NewPlaylist.qml", {"newListType":"NOTHING"})
            }
        }

        header: Header {
            title: qsTr("Playlists")
        }

        delegate: ListItem {
            // Queue and favorites stay in myPlaylists for the other pages,
            // but have their own entries on the start page
            readonly property bool builtIn: model.name==="00000000000000000000" || model.name==="00000000000000000001"
            visible: !builtIn
            contentHeight: builtIn ? 0 : Theme.itemSizeSmall
            width: parent.width
            clip: true

            menu: contextMenu

            function removeItem() {
                remorseAction(qsTr("Deleting"),
                function() {
                    myplaylistmanager.removeList(model.name)
                    myPlaylists.clear()
                    myplaylistmanager.loadPlaylists()
                })
            }

            Component {
                id: contextMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Rename")
                        onClicked: {
                            currentPlaylist = model.name
                            pageStack.push("NewPlaylist.qml", {"renamingPlaylist":true})
                        }
                    }
                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: {
                            removeItem()
                        }
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter

                Label
                {
                    width: parent.width
                    text: model.name
                    truncationMode: TruncationMode.Fade
                }

                Label
                {
                    width: parent.width
                    text: model.count==="0"? qsTr("No tracks") : model.count==="1"?
                                                 qsTr("1 track") : qsTr("%1 tracks").arg(model.count)
                    truncationMode: TruncationMode.Fade
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    opacity: 0.8
                }
            }


            onClicked: {
                currentPlaylist = model.name
                //pageStack.replaceAbove(mainPage, "PlaylistPage.qml")
                pageStack.push("PlaylistPage.qml")
            }


        }

        ViewPlaceholder {
            enabled: myPlaylists.count<=2
            text: qsTr("No playlists")
            hintText: qsTr("Pull down to create a new playlist")
        }

    }

}
