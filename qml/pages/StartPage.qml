import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root
    property bool pageloaded: false
    property bool mainloaded: false
    property bool startup: true

    allowedOrientations: appWindow.pagesOrientations

    canNavigateForward: database.loaded


    onStatusChanged: {
        if (status===PageStatus.Activating) {
            if (!pageloaded) {
                console.log("Loaded: " + pageloaded + " - main: " + mainloaded)
                utils.removeAlbumArt()

                misdatos.startup()

                totals = misdatos.dataInfo()

                misdatos.clearList()

                lastGroup = "" //utils.readSettings("LastGroup", "albums")

                /*if (lastGroup=="albums")
                    misdatos.loadAlbums(utils.order)
                else if (lastGroup=="artists")
                    misdatos.loadArtists()
                else
                    misdatos.loadSongs(utils.readSettings("TrackOrder", "title"))*/

                pageloaded = true

                if (utils.cleanqueue==="yes")
                    myplaylistmanager.clearList("00000000000000000000")
            }

            // The queue and favorites counts shown here change on other pages
            myPlaylists.clear()
            myplaylistmanager.loadPlaylists()
            mainPanel.countGenres()

            /*if (!mainloaded) {
                mainloaded = true

                console.log("Pushing new attached: " + lastGroup)
                if (lastGroup==="artists" || lastGroup==="albums")
                    pageStack.pushAttached(mainPage)
                else
                    pageStack.pushAttached("SongsPage.qml")
            }*/

            if (radioModel.count===0) {
                radios.loadRadios()
            }
        }
        else if (status===PageStatus.Active) {
            if (startup) {
                startup = false
                if (!openStartupPage())
                    rememberPage("home")
            }
            else {
                rememberPage("home")
            }
        }
    }

    // Opens the page chosen in the settings, or the one open when the app
    // was last closed. Returns false when the start page stays on top.
    function openStartupPage() {
        var page = utils.readSettings("StartPage", "home")
        if (page==="last")
            page = utils.readSettings("LastPage", "home")
        console.log("Startup page: " + page)

        if (page==="artists" || page==="albums") {
            openGroup(page, true)
        } else if (page==="tracks") {
            openTracks(true)
        } else if (page==="queue") {
            openList("00000000000000000000", true)
        } else if (page==="favorites") {
            openList("00000000000000000001", true)
        } else if (page==="player") {
            // Nothing plays at startup: the queue is shown paused instead
            if (queueList.count===0)
                myplaylistmanager.loadPlaylist("00000000000000000000")
            if (queueList.count===0)
                return false
            var index = playbackIndex("00000000000000000000", queueList)
            if (index>=0) {
                var state = playbackState("00000000000000000000")
                // Loading the track must not overwrite its stored position
                savedUrl = state.url
                savedPosition = state.position
                nowPlayingPage.cueSong(index, state.position)
            } else {
                nowPlayingPage.cueSong(0)
            }
            pageStack.push(nowPlayingPage, {}, PageStackAction.Immediate)
        } else {
            return false
        }
        return true
    }

    // Track count of the queue or favorites, as stored in myPlaylists
    function listCount(name) {
        for (var i=0; i<myPlaylists.count; ++i) {
            if (myPlaylists.get(i).name===name)
                return myPlaylists.get(i).count || "0"
        }
        return "0"
    }

    function openList(name, immediate) {
        mainloaded = false
        currentPlaylist = name
        pageStack.push("PlaylistPage.qml", {}, immediate ? PageStackAction.Immediate : PageStackAction.Animated)
    }

    // Shows the artists or albums of the library
    function openGroup(group, immediate) {
        if (lastGroup!==group) {
            utils.setSettings("LastGroup", group)
            mainPage.searchValue = ""
            mainPage.showSearch = false
            mainPage.enableSearch = false
            misdatos.clearList()
            if (group==="artists")
                misdatos.loadArtists()
            else
                misdatos.loadAlbums(utils.order)
            console.log("Pushing attached: " + lastGroup)
            pageStack.pushAttached(mainPage)
            lastGroup = group
        }
        pageStack.navigateForward(immediate ? PageStackAction.Immediate : PageStackAction.Animated)
    }

    function openTracks(immediate) {
        if (lastGroup!=="songs") {
            utils.setSettings("LastGroup", "songs")
            lastGroup = "songs"
            misdatos.clearList()
            misdatos.loadSongs(utils.readSettings("TrackOrder", "number"))
            console.log("Pushing attached: " + lastGroup)
            //pageStack.popAttached()
            pageStack.pushAttached("SongsPage.qml")
        }
        pageStack.navigateForward(immediate ? PageStackAction.Immediate : PageStackAction.Animated)
    }

    // Replaces the queue with the whole library and plays it shuffled
    function shuffleAll() {
        queueList.clear()
        myplaylistmanager.clearList("00000000000000000000")
        myplaylistmanager.addAlbumToList("00000000000000000000", "ALL", "ALL", "ALL", "")
        myplaylistmanager.loadPlaylist("00000000000000000000")
        if (queueList.count===0)
            return
        shuffle = true
        var first = utils.getShuffleTrack(-1)
        queueList.currentIndex = first
        nowPlayingPage.playSong(first)
        miniPlayer.open = true
    }

    Connections {
        target: database
        onLoadChanged: {
            if (database.loaded) {
                totals = misdatos.dataInfo()
                mainPanel.countGenres()
                misdatos.clearList()

                if (lastGroup=="albums")
                    misdatos.loadAlbums(utils.order)
                else if (lastGroup=="artists")
                    misdatos.loadArtists()
                else
                    misdatos.loadSongs(utils.readSettings("TrackOrder", "number"))
            }
        }
    }


    Header {
        visible: !database.loaded
        title: "FlowPlayer"
    }


    Column {
        visible: !database.loaded
        anchors.centerIn: parent
        width: parent.width -Theme.paddingLarge*2
        spacing: Theme.paddingLarge


        ProgressCircleBase {
            anchors.horizontalCenter: parent.horizontalCenter
            width: colSpace.width + Theme.paddingLarge*3
            height: width
            value: parseInt(database.perc) /100
            borderWidth: 2
            progressColor: Theme.highlightColor
            backgroundColor: Theme.rgba(Theme.secondaryHighlightColor, 0.5)

            Column {
                id: colSpace
                width: Theme.itemSizeMedium
                anchors.centerIn: parent

                Text {
                    id: percent
                    color: Theme.highlightColor
                    font.pixelSize: Theme.fontSizeMedium
                    width: Theme.itemSizeMedium
                    anchors.horizontalCenter: parent.horizontalCenter
                    horizontalAlignment: Text.AlignHCenter
                    text: database.perc + "%"
                }
            }

        }

        Label {
            width: parent.width
            text: qsTr("Updating music collection")
            horizontalAlignment: Text.AlignHCenter
            color: Theme.highlightColor
        }

        Button {
            anchors.horizontalCenter: parent.horizontalCenter
            text: qsTr("Cancel")
            onClicked: database.cancelRead()
        }


    }

    SilicaFlickable {
        id: mainPanel
        anchors.fill: parent
        contentHeight: col1.height + Theme.paddingLarge
        visible: database.loaded

        property int albumsCount: parseInt(totals.split(",")[0]) || 0
        property int artistsCount: parseInt(totals.split(",")[1]) || 0
        property int tracksCount: parseInt(totals.split(",")[2]) || 0
        property int genresCount: 0

        // Tracks without a genre are listed too, but aren't a genre
        function countGenres() {
            var genres = myplaylistmanager.getGenres()
            var count = genres.length
            if (count>0 && genres[count-1].genre==="")
                count--
            genresCount = count
        }

        function tracksText(count) {
            count = parseInt(count) || 0
            return count===1 ? qsTr("1 track") : qsTr("%1 tracks").arg(count)
        }

        PullDownMenu {
            MenuItem {
                text: qsTr("Download album covers")
                onClicked: {
                    mainloaded = false
                    pageStack.push("FullAlbumSearch.qml")
                }
            }
            MenuItem {
                text: qsTr("Equalizer")
                onClicked: {
                    mainloaded = false
                    pageStack.push("Equalizer.qml")
                }
            }
            MenuItem {
                text: qsTr("Settings")
                onClicked: {
                    mainloaded = false
                    pageStack.push("Settings.qml")
                }
            }
            MenuItem {
                text: qsTr("Rescan library")
                onClicked: database.readMusic()
            }
        }

        Column {
            id: col1
            width: parent.width

            Header {
                title: "FlowPlayer"
            }

            HomeDelegate {
                title: qsTr("Artists")
                subtitle: mainPanel.artistsCount===1 ? qsTr("1 artist") : qsTr("%1 artists").arg(mainPanel.artistsCount)
                iconSource: "image://theme/icon-m-media-artists"
                onClicked: openGroup("artists")
            }

            HomeDelegate {
                title: qsTr("Albums")
                subtitle: mainPanel.albumsCount===1 ? qsTr("1 album") : qsTr("%1 albums").arg(mainPanel.albumsCount)
                iconSource: "image://theme/icon-m-media-albums"
                onClicked: openGroup("albums")
            }

            HomeDelegate {
                title: qsTr("Genres")
                subtitle: mainPanel.genresCount===1 ? qsTr("1 genre") : qsTr("%1 genres").arg(mainPanel.genresCount)
                iconSource: "image://theme/icon-m-sounds"
                onClicked: {
                    mainloaded = false
                    pageStack.push("GenresPage.qml")
                }
            }

            HomeDelegate {
                title: qsTr("Tracks")
                subtitle: mainPanel.tracksText(mainPanel.tracksCount)
                iconSource: "image://theme/icon-m-media-songs"
                onClicked: openTracks()
            }

            HomeDelegate {
                title: qsTr("Queue")
                subtitle: mainPanel.tracksText(listCount("00000000000000000000"))
                iconSource: "image://theme/icon-m-menu"
                onClicked: openList("00000000000000000000")
            }

            HomeDelegate {
                title: qsTr("Favorites")
                subtitle: mainPanel.tracksText(listCount("00000000000000000001"))
                iconSource: "image://theme/icon-m-favorite"
                onClicked: openList("00000000000000000001")
            }

            HomeDelegate {
                // Queue and favorites have their own entries
                property int playlistsCount: Math.max(0, myPlaylists.count - 2)
                title: qsTr("Playlists")
                subtitle: playlistsCount===1 ? qsTr("1 playlist") : qsTr("%1 playlists").arg(playlistsCount)
                iconSource: "image://theme/icon-m-media-playlists"
                onClicked: {
                    mainloaded = false
                    pageStack.push("Playlists.qml")
                }
            }

            HomeDelegate {
                title: qsTr("Radio stations")
                subtitle: radioModel.count===1 ? qsTr("1 station") : qsTr("%1 stations").arg(radioModel.count)
                iconSource: "image://theme/icon-m-media-radio"
                onClicked: {
                    mainloaded = false
                    pageStack.push("OnlineRadios.qml")
                }
            }

            // TODO: "Recently played" covers row. Nothing records play
            // history yet, so the section is left out for now.

            // Sets the actions apart from the library entries
            Item {
                width: parent.width
                height: Theme.paddingLarge*2

                Separator {
                    anchors.centerIn: parent
                    width: parent.width - Theme.horizontalPageMargin*2
                    color: Theme.primaryColor
                    horizontalAlignment: Qt.AlignHCenter
                }
            }

            HomeDelegate {
                title: qsTr("Search")
                titleColor: Theme.highlightColor
                iconSource: "image://theme/icon-m-search"
                onClicked: {
                    mainloaded = false
                    pageStack.push("SearchPage.qml")
                }
            }

            HomeDelegate {
                title: qsTr("Shuffle all")
                titleColor: Theme.highlightColor
                iconSource: "image://theme/icon-m-shuffle"
                enabled: mainPanel.tracksCount>0
                onClicked: shuffleAll()
            }
        }

        VerticalScrollDecorator {}
    }

}
