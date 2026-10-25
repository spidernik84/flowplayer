import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0
import "dateandtime.js" as DT

// Searches artists, albums, tracks, playlists and radio stations at once,
// with results grouped by type
Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool focused: false

    // Values of the "Search in" entries, in menu order
    readonly property var scopes: ["all", "artists", "albums", "tracks", "playlists", "radios"]
    // Results per type
    readonly property int maxResults: 50

    onStatusChanged: {
        if (status===PageStatus.Active && !focused) {
            focused = true
            searchField.forceActiveFocus()
        }
    }

    ListModel { id: results }

    function sectionTitle(kind) {
        if (kind==="artists") return qsTr("Artists")
        if (kind==="albums") return qsTr("Albums")
        if (kind==="tracks") return qsTr("Tracks")
        if (kind==="playlists") return qsTr("Playlists")
        return qsTr("Radio stations")
    }

    // Every row has the same roles, as ListModel expects
    function addResult(kind, row) {
        results.append({"kind":kind, "title":row.title || "", "subtitle":row.subtitle || "",
                        "artist":row.artist || "", "album":row.album || "", "acount":row.acount || "1",
                        "duration":row.duration || "", "url":row.url || "", "image":row.image || "",
                        "radioid":row.radioid || ""})
    }

    function search() {
        results.clear()
        var text = searchField.text.trim()
        if (text==="")
            return
        var lower = text.toLowerCase()
        var scope = scopes[scopeMenu.currentIndex]
        var i, rows

        if (scope==="all" || scope==="artists") {
            rows = myplaylistmanager.searchLibrary(text, "artists", maxResults)
            for (i=0; i<rows.length; ++i) {
                addResult("artists", {"title":rows[i].artist, "artist":rows[i].artist,
                              "subtitle":rows[i].albums==="1" ? qsTr("1 album") : qsTr("%1 albums").arg(rows[i].albums)})
            }
        }

        if (scope==="all" || scope==="albums") {
            rows = myplaylistmanager.searchLibrary(text, "albums", maxResults)
            for (i=0; i<rows.length; ++i) {
                addResult("albums", {"title":rows[i].album, "subtitle":rows[i].band, "artist":rows[i].artist,
                              "album":rows[i].album, "acount":rows[i].acount})
            }
        }

        if (scope==="all" || scope==="tracks") {
            rows = myplaylistmanager.searchLibrary(text, "tracks", maxResults)
            for (i=0; i<rows.length; ++i) {
                addResult("tracks", {"title":rows[i].title, "subtitle":rows[i].artist + " - " + rows[i].album,
                              "artist":rows[i].artist, "album":rows[i].album, "duration":rows[i].duration,
                              "url":rows[i].url})
            }
        }

        if (scope==="all" || scope==="playlists") {
            for (i=0; i<myPlaylists.count; ++i) {
                var list = myPlaylists.get(i)
                // The queue and favorites have fixed ids, not names
                if (list.name==="00000000000000000000" || list.name==="00000000000000000001")
                    continue
                if (list.name.toLowerCase().indexOf(lower)>=0) {
                    var count = parseInt(list.count) || 0
                    addResult("playlists", {"title":list.name,
                                  "subtitle":count===1 ? qsTr("1 track") : qsTr("%1 tracks").arg(count)})
                }
            }
        }

        if (scope==="all" || scope==="radios") {
            for (i=0; i<radioModel.count; ++i) {
                var radio = radioModel.get(i)
                if (radio.name.toLowerCase().indexOf(lower)>=0) {
                    addResult("radios", {"title":radio.name, "subtitle":radio.url, "url":radio.url,
                                  "image":radio.image, "radioid":radio.radioid})
                }
            }
        }
    }

    // Replaces the queue with the tracks found and plays the chosen one
    function playTrack(url) {
        var urls = []
        var index = 0
        for (var i=0; i<results.count; ++i) {
            var row = results.get(i)
            if (row.kind!=="tracks")
                continue
            if (row.url===url)
                index = urls.length
            urls.push(row.url)
        }

        queueList.clear()
        myplaylistmanager.clearList("00000000000000000000")
        myplaylistmanager.insertIntoQueue(urls, -1)
        myplaylistmanager.loadPlaylist("00000000000000000000")
        queueList.currentIndex = index
        nowPlayingPage.playSong(index)
        miniPlayer.open = true
    }

    Timer {
        id: searchTimer
        interval: 300
        onTriggered: search()
    }

    Column {
        id: searchBar
        width: parent.width

        // Keep the search field clear of the display notch
        Item {
            width: parent.width
            height: root.orientation === Orientation.Portrait ? Screen.topCutout.height : 0
        }

        SearchField {
            id: searchField
            width: parent.width
            placeholderText: qsTr("Search")
            onTextChanged: searchTimer.restart()
            EnterKey.iconSource: "image://theme/icon-m-enter-close"
            EnterKey.onClicked: focus = false
        }

        ComboBox {
            id: scopeMenu
            label: qsTr("Search in")
            menu: ContextMenu {
                MenuItem { text: qsTr("Everything") }
                MenuItem { text: qsTr("Artists") }
                MenuItem { text: qsTr("Albums") }
                MenuItem { text: qsTr("Tracks") }
                MenuItem { text: qsTr("Playlists") }
                MenuItem { text: qsTr("Radio stations") }
            }
            onCurrentIndexChanged: search()
        }
    }

    SilicaListView {
        id: resultsList
        anchors.top: searchBar.bottom
        anchors.bottom: parent.bottom
        width: parent.width
        clip: true

        model: results

        section.property: "kind"
        section.delegate: SectionHeader {
            text: sectionTitle(section)
        }

        delegate: ListItem {
            id: item
            contentHeight: Theme.itemSizeMedium

            menu: model.kind==="tracks" ? trackMenu : model.kind==="albums" ? albumMenu : null

            Component {
                id: trackMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Play next")
                        onClicked: queueTrack(model, true)
                    }
                    MenuItem {
                        text: qsTr("Add to queue")
                        onClicked: queueTrack(model, false)
                    }
                }
            }

            Component {
                id: albumMenu
                ContextMenu {
                    MenuItem {
                        text: qsTr("Play next")
                        onClicked: queueAlbum(model.artist, model.album, model.acount, true)
                    }
                    MenuItem {
                        text: qsTr("Add to queue")
                        onClicked: queueAlbum(model.artist, model.album, model.acount, false)
                    }
                }
            }

            CoverArtList {
                id: thumb
                x: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                width: Theme.itemSizeMedium - Theme.paddingMedium*2
                height: width
                enabled: false
                text: ""
                itemimg: model.kind==="artists" ? utils.thumbnailArtist(model.artist) :
                         model.kind==="albums" ? utils.thumbnail(model.artist, model.album, model.acount) :
                         model.kind==="tracks" ? utils.thumbnail(model.artist, model.album) :
                         model.kind==="radios" ? model.image : ""
            }

            HighlightImage {
                anchors.centerIn: thumb
                visible: thumb.status!==Image.Ready
                color: Theme.highlightColor
                highlighted: item.highlighted
                source: model.kind==="artists" ? "image://theme/icon-m-media-artists" :
                        model.kind==="albums" ? "image://theme/icon-m-media-albums" :
                        model.kind==="tracks" ? "image://theme/icon-m-media-songs" :
                        model.kind==="playlists" ? "image://theme/icon-m-media-playlists" :
                                                   "image://theme/icon-m-media-radio"
            }

            Column {
                anchors.left: thumb.right
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: durationLabel.left
                anchors.rightMargin: Theme.paddingSmall
                anchors.verticalCenter: parent.verticalCenter

                Label {
                    width: parent.width
                    text: replaceText(model.title, searchField.text.trim())
                    textFormat: Text.StyledText
                    color: item.highlighted ? Theme.highlightColor : Theme.primaryColor
                    truncationMode: TruncationMode.Fade
                }

                Label {
                    width: parent.width
                    visible: text!==""
                    text: model.subtitle
                    font.pixelSize: Theme.fontSizeSmall
                    color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
                    truncationMode: TruncationMode.Fade
                }
            }

            Label {
                id: durationLabel
                anchors.right: parent.right
                anchors.rightMargin: Theme.horizontalPageMargin
                anchors.verticalCenter: parent.verticalCenter
                text: model.kind==="tracks" ? DT.getDuration(model.duration) : ""
                font.pixelSize: Theme.fontSizeExtraSmall
                color: item.highlighted ? Theme.secondaryHighlightColor : Theme.secondaryColor
            }

            onClicked: {
                if (model.kind==="artists") {
                    pageStack.push("AlbumListView.qml", {"artist":model.artist})
                } else if (model.kind==="albums") {
                    pageStack.push("SongListView.qml", {"artist":model.artist, "album":model.album,
                                       "artistcount":model.acount})
                } else if (model.kind==="tracks") {
                    playTrack(model.url)
                } else if (model.kind==="playlists") {
                    currentPlaylist = model.title
                    pageStack.push("PlaylistPage.qml")
                } else {
                    playRadio(model.title, model.url, model.image, model.radioid)
                }
            }
        }

        ViewPlaceholder {
            enabled: results.count===0 && !searchTimer.running
            text: searchField.text.trim()==="" ? qsTr("Search your music, playlists and radio stations")
                                              : qsTr("No results")
        }

        VerticalScrollDecorator {}
    }
}
