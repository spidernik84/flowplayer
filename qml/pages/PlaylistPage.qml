import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0
import "dateandtime.js" as DT


Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool loaded: false
    property bool isqueue: false
    property bool startEditing: false

    readonly property bool isQueueList: currentPlaylist==="00000000000000000000"
    readonly property bool isFavorites: currentPlaylist==="00000000000000000001"
    // While a radio plays, queueList holds the station instead of the queue
    readonly property bool canEdit: !isFavorites && !(isQueueList && playingRadio)

    ListModel { id: playlistModel }

    onStatusChanged: {
        if (status===PageStatus.Activating && !loaded) {
            console.log("current list: " + currentPlaylist + " - clean queue: " + utils.cleanqueue)

            loaded = true
            if (startEditing && canEdit)
                songlist.editing = true
            if (isQueueList && queueList.count>0)
                return;

            playlistModel.clear()
            myplaylistmanager.loadPlaylist(currentPlaylist)
        }
        else if (status===PageStatus.Deactivating) {
            songlist.editing = false
        }
    }

    Connections {
        target: appWindow

        onAlbumMetadataChanged: {
            songlist.editing = false
            playlistModel.clear()
            myplaylistmanager.loadPlaylist(currentPlaylist)
        }
    }

    Connections {
        target: myplaylistmanager

        onAddItemToList: {
            if (currentPlaylist===list && currentPlaylist!=="00000000000000000000") {
                console.log("Adding to " + currentPlaylist + ": " + item.title)
                playlistModel.append({"artist":item.artist, "album":item.album, "title":item.title,
                                   "duration":item.duration, "url":item.url})
            }
        }
    }

    function listModel() {
        return isQueueList ? queueList : playlistModel
    }

    // Stores the list as shown, and brings the player in line when it is the queue
    function saveList() {
        var model = listModel()
        var rows = []
        for (var i=0; i<model.count; ++i) {
            var row = model.get(i)
            rows.push({"artist":row.artist, "album":row.album, "title":row.title,
                       "duration":row.duration, "url":row.url})
        }
        myplaylistmanager.saveListOrder(currentPlaylist, rows)

        if (isQueueList) {
            if (queueList.count===0) {
                player.stop()
                player.source = ""
                closeMiniplayer()
            } else {
                utils.setShuffle(queueList.count)
                nowPlayingPage.syncQueue()
            }
        }
    }

    // rows: indices in ascending order
    function removeRows(rows) {
        var model = listModel()
        for (var i=rows.length-1; i>=0; --i)
            model.remove(rows[i])
        saveList()
        myPlaylists.clear()
        myplaylistmanager.loadPlaylists()
    }

    // Moves the selected tracks right after the playing one, which stays put
    function playSelectedNext() {
        var source = decodeURIComponent(myPlayer.source)
        var playing = -1
        for (var i=0; source!=="" && i<queueList.count; ++i) {
            if (decodeURIComponent(queueList.get(i).url)===source) {
                playing = i
                break
            }
        }
        if (playing>=0 && songlist.isSelected(playing))
            songlist.setSelected(playing, false)
        if (songlist.selectedCount===0)
            return

        var position = 0
        for (i=0; i<=playing; ++i) {
            if (!songlist.isSelected(i))
                position++
        }
        songlist.moveSelectionTo(position)
        saveList()
    }

    RemorsePopup { id: remorse }

    ReorderableListView {
        id: songlist
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.bottom: editBar.top
        highlightFollowsCurrentItem: false
        clip: editing
        //clip: true

        // A pending removal points at rows by position, so moving rows cancels it
        onReordered: {
            remorse.cancel()
            saveList()
        }

        header: Header {
            title: isQueueList ? qsTr("Queue") :
                   isFavorites ? qsTr("Favorites") : currentPlaylist
            // Never empty: a header changing height moves the list off its top
            // position, and the pull-down menu only opens from there
            description: !songlist.editing ? " " :
                         songlist.selectedCount>0 ? qsTr("%n selected", "", songlist.selectedCount) :
                                                    qsTr("Drag the handle to move, tap to select")
        }

        PullDownMenu {
            MenuItem {
                visible: !songlist.editing && !isQueueList && !isFavorites
                text: qsTr("Rename playlist")
                onClicked: {
                    pageStack.push("NewPlaylist.qml", {"renamingPlaylist":true})
                }
            }
            MenuItem {
                visible: !songlist.editing
                text: qsTr("Clear playlist")
                onClicked: {
                    myplaylistmanager.clearList(currentPlaylist)
                    myPlaylists.clear()
                    playlistModel.clear()
                    myplaylistmanager.loadPlaylists()

                    if (isQueueList) {
                        queueList.clear()
                        player.stop()
                        player.source = ""
                        closeMiniplayer()
                    }
                }
            }
            MenuItem {
                visible: !songlist.editing && canEdit && songlist.count>0
                text: isQueueList ? qsTr("Edit queue") : qsTr("Edit playlist")
                // Changing which entries are visible while the menu is still
                // open breaks the menu's positioning, so wait until it closes
                onDelayedClick: songlist.editing = true
            }
            MenuItem {
                visible: songlist.editing
                text: songlist.selectedCount===songlist.count ? qsTr("Select none") : qsTr("Select all")
                onDelayedClick: {
                    if (songlist.selectedCount===songlist.count)
                        songlist.clearSelection()
                    else
                        songlist.selectAll()
                }
            }
            MenuItem {
                visible: songlist.editing
                text: qsTr("Done")
                onDelayedClick: songlist.editing = false
            }
        }

        model: isQueueList ? queueList : playlistModel

        delegate: AlbumDelegate {
            myData: model
            name: model.title
            desc: model.artist
            img: utils.thumbnail(model.artist, model.album)
            time: DT.getDuration(model.duration)
            cindex: index
            isplaying: decodeURIComponent(model.url) === decodeURIComponent(myPlayer.source)
            contentHeight: Theme.itemSizeSmall
            textSize: Theme.fontSizeExtraSmall*0.5
            showCover: true
            editing: songlist.editing
            selected: songlist.isSelected(index)
            dragged: songlist.isDragged(index)
            menu: songlist.editing || !canEdit && !isFavorites ? null : itemMenu

            function removeItem() {
                remorseAction(qsTr("Deleting"),
                function() {
                    if (isFavorites)
                    {
                        utils.favSong(model.url, false)
                        favRemoved()
                        playlistModel.remove(model.index)
                    }
                    else
                    {
                        removeRows([model.index])
                    }
                })
            }

            Component {
                id: itemMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Remove")
                        onClicked: {
                            removeItem()
                        }
                    }
                }
            }


            onClicked: {
                if (songlist.editing)
                {
                    songlist.toggleSelected(model.index)
                }
                // The queue still mirrors this list only if nothing was moved since
                else if (isqueue && model.index<queueList.count && queueList.get(model.index).url===model.url)
                {
                    nowPlayingPage.playSong(model.index)
                }
                else
                {
                    var cindex = model.index
                    if (!isQueueList) {
                        queueList.clear()
                        //myplaylistmanager.clearList("00000000000000000000")
                        myplaylistmanager.copyListToQueue(currentPlaylist)
                        myplaylistmanager.loadPlaylist("00000000000000000000")
                    }
                    myPlaylists.clear()
                    myplaylistmanager.loadPlaylists()
                    queueList.currentIndex = cindex
                    nowPlayingPage.playSong(cindex)
                    miniPlayer.open = true
                    isqueue = true
                }
            }

        }

        ViewPlaceholder {
            enabled: songlist.count==0
            flickable: songlist
            text: qsTr("Playlist is empty")
        }
    }

    Item {
        id: editBar
        anchors.bottom: parent.bottom
        width: parent.width
        height: songlist.editing ? Theme.itemSizeLarge : 0
        clip: true

        Behavior on height { NumberAnimation { duration: 150 } }

        Rectangle {
            anchors.fill: parent
            color: Theme.highlightDimmerColor
            opacity: 0.8
        }

        Row {
            id: editButtons
            anchors.fill: parent

            property real buttonWidth: width / (isQueueList ? 5 : 4)

            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-up"
                text: qsTr("Move to top")
                enabled: songlist.selectedCount>0
                onClicked: {
                    remorse.cancel()
                    songlist.moveSelectionTo(0)
                    saveList()
                }
            }
            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-down"
                text: qsTr("Move to bottom")
                enabled: songlist.selectedCount>0
                onClicked: {
                    remorse.cancel()
                    // Position counts the rows left once the selection is taken out
                    songlist.moveSelectionTo(songlist.count - songlist.selectedCount)
                    saveList()
                }
            }
            EditBarButton {
                visible: isQueueList
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-next"
                text: qsTr("Play next")
                enabled: songlist.selectedCount>0
                onClicked: {
                    remorse.cancel()
                    playSelectedNext()
                }
            }
            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-delete"
                text: qsTr("Remove")
                enabled: songlist.selectedCount>0
                onClicked: {
                    var rows = songlist.selectedIndices()
                    remorse.execute(qsTr("Deleting"), function() {
                        removeRows(rows)
                    })
                }
            }
            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-acknowledge"
                text: qsTr("Done")
                onClicked: songlist.editing = false
            }
        }
    }

}
