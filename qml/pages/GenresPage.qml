import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool loaded: false

    ListModel { id: genreList }

    function loadGenres() {
        genreList.clear()
        var genres = myplaylistmanager.getGenres()
        for (var i=0; i<genres.length; ++i)
            genreList.append(genres[i])
        loaded = true
    }

    onStatusChanged: {
        if (status===PageStatus.Activating && !loaded)
            loadGenres()
    }

    // Genres edited from a track or album page further up the stack
    Connections {
        target: meta
        onGenreSaved: loaded = false
    }

    function genreName(genre) {
        return genre==="" ? qsTr("Unknown genre") : genre
    }

    SilicaListView {
        id: genreView
        anchors.fill: parent
        clip: true

        header: Header {
            title: qsTr("Genres")
        }

        model: genreList

        ViewPlaceholder {
            enabled: root.loaded && genreList.count===0
            text: qsTr("No music found")
        }

        delegate: ListItem {
            id: genreItem
            contentHeight: Theme.itemSizeMedium

            Column {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: genreName(model.genre)
                    color: genreItem.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    text: (model.albums===1 ? qsTr("1 album") : qsTr("%1 albums").arg(model.albums)) + " · " +
                          (model.songs===1 ? qsTr("1 track") : qsTr("%1 tracks").arg(model.songs))
                    font.pixelSize: Theme.fontSizeSmall
                    color: genreItem.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Play next")
                    onClicked: queueTracks(myplaylistmanager.getGenreTracks(model.genre), true)
                }
                MenuItem {
                    text: qsTr("Add to queue")
                    onClicked: queueTracks(myplaylistmanager.getGenreTracks(model.genre), false)
                }
                MenuItem {
                    text: qsTr("Add to playlist")
                    onClicked: {
                        filterByGenre = true
                        filterGenre = model.genre
                        pageStack.push("SelectPlaylist.qml")
                    }
                }
            }

            onClicked: pageStack.push("GenreAlbumsPage.qml", {"genre":model.genre})
        }

        VerticalScrollDecorator {}
    }
}
