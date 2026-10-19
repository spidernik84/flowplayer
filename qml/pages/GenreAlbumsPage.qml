import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    // Empty for the tracks without a genre
    property string genre
    property int totalSongs: 0

    property bool loaded: false

    readonly property string genreName: genre==="" ? qsTr("Unknown genre") : genre

    ListModel { id: albumList }

    function loadAlbums() {
        albumList.clear()
        totalSongs = 0
        var albums = myplaylistmanager.getGenreAlbums(genre)
        for (var i=0; i<albums.length; ++i) {
            albumList.append(albums[i])
            totalSongs += parseInt(albums[i].songs)
        }
        loaded = true
    }

    onStatusChanged: {
        if (status===PageStatus.Activating && !loaded)
            loadAlbums()
    }

    // Genres edited from an album page further up the stack
    Connections {
        target: meta
        onGenreSaved: loaded = false
    }

    SilicaListView {
        id: albumView
        anchors.fill: parent
        clip: true

        PullDownMenu {
            MenuItem {
                text: qsTr("Add to playlist")
                onClicked: {
                    filterByGenre = true
                    filterGenre = genre
                    pageStack.push("SelectPlaylist.qml")
                }
            }
            MenuItem {
                text: qsTr("Add to queue")
                enabled: albumList.count>0
                onClicked: queueTracks(myplaylistmanager.getGenreTracks(genre), false)
            }
            MenuItem {
                text: qsTr("Play all")
                enabled: albumList.count>0
                onClicked: {
                    queueList.clear()
                    myplaylistmanager.clearList("00000000000000000000")
                    myplaylistmanager.addGenreToList("00000000000000000000", genre)
                    myplaylistmanager.loadPlaylist("00000000000000000000")
                    queueList.currentIndex = 0
                    nowPlayingPage.playSong(0)
                    miniPlayer.open = true
                }
            }
        }

        model: albumList

        header: Column {
            width: albumView.width

            Header {
                title: root.genreName
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                bottomPadding: Theme.paddingMedium
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                text: (albumView.count===1 ? qsTr("1 album") : qsTr("%1 albums").arg(albumView.count)) + " · " +
                      (totalSongs===1 ? qsTr("1 track") : qsTr("%1 tracks").arg(totalSongs))
            }
        }

        delegate: AlbumDelegate {
            myData: model
            name: model.album
            desc: model.acount==="1" ? model.artist : qsTr("Various artists")
            img: utils.thumbnail(model.artist, model.album, model.acount)
            cindex: index
            contentHeight: Theme.itemSizeMedium

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Play next")
                    onClicked: queueAlbum(model.artist, model.album, model.acount, true)
                }
                MenuItem {
                    text: qsTr("Add to queue")
                    onClicked: queueAlbum(model.artist, model.album, model.acount, false)
                }
                MenuItem {
                    text: qsTr("Add to playlist")
                    onClicked: {
                        filterArtist = model.artist
                        filterAlbum = model.album
                        filterArtistCount = model.acount
                        filterSong = ""
                        pageStack.push("SelectPlaylist.qml")
                    }
                }
            }

            onClicked: {
                pageStack.push("SongListView.qml", {"artist":model.artist, "album":model.album, "artistcount":model.acount})
            }
        }

        VerticalScrollDecorator {}
    }
}
