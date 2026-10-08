import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Dialog {

    id: dialog

    allowedOrientations: appWindow.pagesOrientations

    property bool renamingPlaylist: false
    property string newListType: "NOTHING"
    // Tracks to store in the new playlist, for newListType "QUEUE"
    property var rows: []

    // Saving the queue must not overwrite or extend an existing playlist
    function nameTaken(name) {
        name = name.trim()
        for (var i=0; i<myPlaylists.count; ++i) {
            if (myPlaylists.get(i).name===name)
                return true
        }
        return false
    }

    onAccepted: {

        if (renamingPlaylist) {
            console.log("RENAMING PLAYLIST")
            myPlaylists.clear()
            myplaylistmanager.renameList(currentPlaylist, ren.text)
            myplaylistmanager.loadPlaylists()
            currentPlaylist = ren.text
        }

        else if (newListType=="SONGS") {
            currentPlaylist = ren.text
            myplaylistmanager.loadList(currentPlaylist)
            /*myplaylistmanager.addToList( currentPlaylist, filterArtist, filterAlbum,
                                       helperList2.currentItem.myData.title,
                                       decodeURIComponent(helperList2.currentItem.myData.url),
                                       helperList2.currentItem.myData.duration )
            myplaylistmanager.saveList(currentPlaylist)*/
            myplaylistmanager.addAlbumToList(currentPlaylist, filterArtist, filterAlbum, filterArtistCount, filterSong)
        }

        else if (newListType=="ALBUM") {
            currentPlaylist = ren.text
            myplaylistmanager.loadList(currentPlaylist)
            /*for ( var i=0; i<helperList2.count; ++i )
            {
                myplaylistmanager.addToList(helperList2.get(i).artist,
                                          helperList2.get(i).album,
                                          helperList2.get(i).title,
                                          helperList2.get(i).url,
                                          helperList2.get(i).duration )
            }
            myplaylistmanager.saveList(currentPlaylist)*/
            myplaylistmanager.addAlbumToList(currentPlaylist, filterArtist, filterAlbum, filterArtistCount, filterSong)
        }

        else if (newListType=="QUEUE") {
            // currentPlaylist stays the queue: the queue page is still open
            myplaylistmanager.saveListOrder(ren.text.trim(), rows)
            ibanner.displayMessage(qsTr("Queue saved as playlist"), true)
        }

        else if (newListType=="NOTHING") {
            currentPlaylist = ren.text
            myplaylistmanager.loadList(currentPlaylist)
            myplaylistmanager.saveList(currentPlaylist)
        }

        myPlaylists.clear()
        myplaylistmanager.loadPlaylists()
    }


    canAccept: ren.text.trim().length>0 && !(newListType=="QUEUE" && nameTaken(ren.text))

    DialogHeader {
        id: header
        acceptText: qsTr("Done")
        cancelText: qsTr("Cancel")
        spacing: 0
    }


    SilicaFlickable {
        anchors.top: parent.top
        anchors.topMargin: header.height
        width: parent.width
        height: parent.height
        contentHeight: col1.height+Theme.paddingLarge
        //color: "transparent"

        Column {
            id: col1
            width: parent.width
            spacing: Theme.paddingMedium

            PageHeader {
                id: header2
                title: renamingPlaylist ? qsTr("Rename playlist") : qsTr("New playlist")
                anchors.top: header.bottom
                width: parent.width
            }

            TextField {
                id: ren
                width: parent.width
                text: renamingPlaylist? currentPlaylist : ""
                placeholderText: qsTr("Playlist name")
                label: newListType=="QUEUE" && nameTaken(text) ? qsTr("A playlist with this name already exists")
                                                               : qsTr("Playlist name")
                errorHighlight: newListType=="QUEUE" && nameTaken(text)
                focus: true
                EnterKey.enabled: dialog.canAccept
                EnterKey.iconSource: "image://theme/icon-m-enter-accept"
                EnterKey.onClicked: dialog.accept()
            }

        }

    }

}
