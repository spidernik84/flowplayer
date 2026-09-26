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

    // Snapshots of the list taken before each edit, oldest first. The first
    // one is the list as it was when editing began.
    property var undoStack: []
    property var dragStart: null        // snapshot taken when a drag begins
    // Going back while editing drops the session's changes: these hold what
    // to restore until the page is gone, and where it sat in the page stack
    property var revertTo: null
    property int stackDepth: 0

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
        else if (status===PageStatus.Active) {
            stackDepth = pageStack.depth
        }
        else if (status===PageStatus.Deactivating) {
            if (songlist.editing)
                revertTo = undoStack.length>0 ? undoStack[0] : null
            songlist.editing = false
        }
        // Only a page pushed on top keeps the page in the stack
        else if (status===PageStatus.Inactive && revertTo!==null) {
            if (pageStack.depth<stackDepth) {
                restoreSnapshot(revertTo)
                ibanner.displayMessage(isQueueList ? qsTr("Queue changes discarded")
                                                   : qsTr("Playlist changes discarded"), false)
            }
            revertTo = null
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

    function listRows() {
        var model = listModel()
        var rows = []
        for (var i=0; i<model.count; ++i) {
            var row = model.get(i)
            rows.push({"artist":row.artist, "album":row.album, "title":row.title,
                       "duration":row.duration, "url":row.url})
        }
        return rows
    }

    // Stores the list as shown, and brings the player in line when it is the queue
    function saveList() {
        myplaylistmanager.saveListOrder(currentPlaylist, listRows())

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

    function snapshot() {
        var rows = listRows()
        var selection = []
        for (var i=0; i<rows.length; ++i)
            selection.push(songlist.isSelected(i))
        return {"rows":rows, "selection":selection}
    }

    function sameRows(a, b) {
        if (a.rows.length!==b.rows.length)
            return false
        for (var i=0; i<a.rows.length; ++i) {
            if (a.rows[i].url!==b.rows[i].url)
                return false
        }
        return true
    }

    // Records `before` as an undo step if the list has changed since
    function pushUndo(before) {
        if (!songlist.editing || sameRows(before, snapshot()))
            return
        var stack = undoStack.slice()
        stack.push(before)
        // Keep the first snapshot: going back restores it
        if (stack.length>50)
            stack.splice(1, 1)
        undoStack = stack
    }

    function undo() {
        if (undoStack.length===0)
            return
        var stack = undoStack.slice()
        var snap = stack.pop()
        undoStack = stack
        restoreSnapshot(snap)
    }

    function restoreSnapshot(snap) {
        var model = listModel()
        var y = songlist.contentY
        model.clear()
        model.append(snap.rows)
        songlist.contentY = Math.max(songlist.originY,
                                     Math.min(y, songlist.originY + songlist.contentHeight - songlist.height))
        songlist.setSelection(snap.selection)
        saveList()
        myPlaylists.clear()
        myplaylistmanager.loadPlaylists()
    }

    // rows: indices in ascending order
    function removeRows(rows) {
        var before = snapshot()
        var model = listModel()
        for (var i=rows.length-1; i>=0; --i)
            model.remove(rows[i])
        pushUndo(before)
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
        var before = snapshot()
        songlist.moveSelectionTo(position)
        pushUndo(before)
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

        // A clear still counting down would empty the list mid-edit
        onEditingChanged: {
            remorse.cancel()
            undoStack = []
        }

        onReorderStarted: dragStart = snapshot()

        onReordered: {
            pushUndo(dragStart)
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
                    remorse.execute(qsTr("Clearing"), function() {
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
                    })
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
            MenuItem {
                visible: songlist.editing
                enabled: undoStack.length>0
                text: qsTr("Undo")
                onDelayedClick: undo()
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
                    var before = snapshot()
                    songlist.moveSelectionTo(0)
                    pushUndo(before)
                    saveList()
                }
            }
            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-down"
                text: qsTr("Move to bottom")
                enabled: songlist.selectedCount>0
                onClicked: {
                    var before = snapshot()
                    // Position counts the rows left once the selection is taken out
                    songlist.moveSelectionTo(songlist.count - songlist.selectedCount)
                    pushUndo(before)
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
                    playSelectedNext()
                }
            }
            EditBarButton {
                width: editButtons.buttonWidth
                icon: "image://theme/icon-m-delete"
                text: qsTr("Remove")
                enabled: songlist.selectedCount>0
                onClicked: removeRows(songlist.selectedIndices())
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
