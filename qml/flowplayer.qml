import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0
//import QtMultimedia 5.0
import Nemo.DBus 2.0
import Amber.Mpris 1.0
import com.jolla.mediaplayer 1.0
import "pages"

ApplicationWindow
{
    cover: CoverPage { id: coverPage }

    id: appWindow
    initialPage: startPage

    onApplicationActiveChanged: {
        if (appWindow.applicationActive) {
            startPage.startTimers()
        } else {
            startPage.stopTimers()
        }
    }

    property int lastArtistItem
    property int lastAlbumItem

    property string savedorientation: utils.readSettings("Orientation", "auto")

    property int pagesOrientations: savedorientation==="auto"? (Orientation.All) :
                                    (savedorientation==="landscape"? Orientation.Landscape : Orientation.Portrait)


    property string currentPlaylist

    property bool playingRadio: false
    property bool shuffle: false
    property bool repeat: false

    property bool showPrevCover: utils.readSettings("ShowPreviousButton", "no")==="yes"
    property bool showBigCover: utils.readSettings("BigCoverBackground", "no")==="yes"

    signal setLanguage(string langval)

    signal playerDurationChanged(int duration)
    signal playerPositionChanged(int position)
    signal playerSourceChanged(string source)

    property string totals;
    property string artistsCovers;
    property string albumsCovers;
    ListModel { id: artistsCoversModel }
    ListModel { id: albumsCoversModel }


    function favAdded() {
        if (myPlaylists.count>1) {
            var val = myPlaylists.get(1).count
            if (val==="") val = 1
            else val = parseInt(val) +1
            myPlaylists.setProperty(1, "count", val.toString())
        }
    }

    function favRemoved() {
        if (myPlaylists.count>1) {
            var val = myPlaylists.get(1).count
            if (val==="1") val = ""
            else val = parseInt(val) -1
            myPlaylists.setProperty(1, "count", val.toString())
        }
    }

    // Adds a track to the queue. With playNext the track goes right after
    // the one playing (it is moved there if already queued); otherwise it is
    // appended, unless it is already in the queue.
    function queueTrack(track, playNext) {
        queueTracks([track], playNext)
    }

    // Adds all tracks of an album to the queue, like queueTrack()
    function queueAlbum(artist, album, various, playNext) {
        queueTracks(myplaylistmanager.getAlbumTracks(artist, album, various), playNext)
    }

    function queueTracks(tracks, playNext) {
        var added = []
        var i, j

        if (playingRadio) {
            // queueList holds the radio station: only update the stored queue
            for (i=0; i<tracks.length; ++i) {
                if (playNext || !myplaylistmanager.isInQueue(tracks[i].url))
                    added.push(tracks[i].url)
            }
            if (added.length===0) {
                ibanner.displayMessage(qsTr("Already in queue"), false)
                return
            }
            myplaylistmanager.insertIntoQueue(added, playNext ? 0 : -1)
            ibanner.displayMessage(playNext ? qsTr("Playing next") : qsTr("Added to queue"), true)
            return
        }

        if (queueList.count===0)
            myplaylistmanager.loadPlaylist("00000000000000000000")

        // Index of the playing track, or -1 when nothing from the queue is playing
        var source = decodeURIComponent(myPlayer.source)
        var current = -1
        if (source!=="" && queueList.currentIndex>=0 && queueList.currentIndex<queueList.count &&
                decodeURIComponent(queueList.get(queueList.currentIndex).url)===source) {
            current = queueList.currentIndex
        } else if (source!=="") {
            for (i=0; i<queueList.count; ++i) {
                if (decodeURIComponent(queueList.get(i).url)===source) {
                    current = i
                    break
                }
            }
        }
        var currentUrl = current>=0 ? queueList.get(current).url : ""

        // The playing track stays where it is. With playNext, queued copies
        // of the other tracks are moved; otherwise they are left alone.
        var toAdd = []
        for (i=0; i<tracks.length; ++i) {
            if (tracks[i].url===currentUrl)
                continue
            var queued = false
            for (j=queueList.count-1; j>=0; --j) {
                if (queueList.get(j).url===tracks[i].url) {
                    queued = true
                    if (!playNext) break
                    queueList.remove(j)
                    if (j<current) current--
                }
            }
            if (playNext || !queued)
                toAdd.push(tracks[i])
        }

        if (toAdd.length===0) {
            ibanner.displayMessage(tracks.length===1 && tracks[0].url===currentUrl ?
                                       qsTr("Already playing") : qsTr("Already in queue"), false)
            return
        }

        var position = playNext ? current+1 : queueList.count
        for (i=0; i<toAdd.length; ++i) {
            queueList.insert(position+i, {"artist":toAdd[i].artist, "album":toAdd[i].album, "title":toAdd[i].title,
                                          "duration":toAdd[i].duration, "url":toAdd[i].url})
            added.push(toAdd[i].url)
        }
        if (current>=0)
            queueList.currentIndex = current

        myplaylistmanager.insertIntoQueue(added, position)
        utils.setShuffle(queueList.count)

        // The player preloads the following track for gapless playback
        if (current>=0)
            myPlayer.setNextSource(nowPlayingPage.getNextSong(), false)

        ibanner.displayMessage(playNext ? qsTr("Playing next") : qsTr("Added to queue"), true)
    }

    // Manual fallback: restarts mpris-proxy so it re-elects FlowPlayer.
    // Not called automatically any more — the direct BlueZ registration
    // through BluetoothMediaPlayer below should make this unnecessary on
    // current Sailfish versions. Kept for emergencies.
    function nudgeMprisProxy() {
        systemdUser.call("RestartUnit", ["mpris-proxy.service", "replace"])
    }


    //signal metadataChanged(string artist, string album)
    signal albumMetadataChanged(string artistold, string artistnew,
                                string albumold, string albumnew,
                                string titleold, string titlenew)

    property variant currentSongInfo: []

    property string currentListOrder: utils.order

    property string lastGroup


    property string filterArtist
    property string filterAlbum
    property string filterArtistCount
    property string filterSong

    property bool gaplessPlayback: utils.readSettings("GaplessPlayback", "no")==="yes"

    Player {
        id: myPlayer

        onSourceChanged: {
            playerSourceChanged(myPlayer.source)
        }

        onStateChanged: {
            if (myPlayer.state===0) {
                if (queueList.count==1)
                    nowPlayingPage.changeSong()
                else
                    nowPlayingPage.nextSong()
            }
        }

        onDurationChanged: {
            playerDurationChanged(myPlayer.duration)
        }

        onPositionChanged: {
            mprisPlayer.position = myPlayer.position * 1000
            playerPositionChanged(myPlayer.position)
        }

        onStreamMetadataChanged: {
            if (!playingRadio || myPlayer.streamTitle==="")
                return

            // ICY titles are usually "Artist - Title"
            var artist = ""
            var title = myPlayer.streamTitle
            var sep = title.indexOf(" - ")
            if (sep>0) {
                artist = title.substring(0, sep).trim()
                title = title.substring(sep+3).trim()
            }

            currentSongInfo = {name:currentSongInfo.name, url:currentSongInfo.url, radioid:currentSongInfo.radioid,
                imageurl:currentSongInfo.imageurl, coverurl:myPlayer.streamCover,
                artist:artist, album:"", title:title}
        }

        /*onAboutToFinish: {
            if (gaplessPlayback) {
                var next = nowPlayingPage.getNextSong()
                myPlayer.setSource(next, false)
            }
        }*/

    }


    /*Audio {
        id: player
        source: ""
        property int stat: playbackState
        property int stat2: player.status

        onDurationChanged: {
            playerDurationChanged(player.source, duration)
        }
        onPositionChanged: {
            mprisPlayer.position = position *1000
            playerPositionChanged(player.source, position)
        }

        onStatusChanged: {
            if (status == Audio.EndOfMedia) {
                if (queueList.count==1)
                    nowPlayingPage.changeSong()
                else
                    nowPlayingPage.nextSong()
            }
        }

        onSourceChanged: {
            playerSourceChanged(source)
        }

    }*/

    onCurrentSongInfoChanged: {
        var metadata
        if (currentSongInfo!==[]) {
            metadata = {
                'url'       : currentSongInfo.url,
                'title'     : currentSongInfo.title!==""? currentSongInfo.title : qsTr("(radio)"),
                'artist'    : currentSongInfo.artist!==""? currentSongInfo.artist : currentSongInfo.name,
                'album'     : currentSongInfo.album,
                'genre'     : "",
                'track'     : queueList.currentIndex,
                'trackCount': queueList.count,
                'duration'  : currentSongInfo.duration * 1000
            }
        }
        mprisPlayer.localMetadata = metadata
        bluetoothMediaPlayer.metadata = metadata
    }


    StartPage { id: startPage }
    MainPage { id: mainPage }

    Database { id: database }
    Meta { id: meta }
    Utils { id: utils }
    CoverSearch { id: coversearch }
    MyPlaylistManager { id: myplaylistmanager }
    Missing { id: missing }
    Datos { id: misdatos } //NOSPARQL
    LFM { id: lfm }
    Radios { id: radios }

    DBusInterface {
        id: systemdUser
        bus: DBus.SessionBus
        service: "org.freedesktop.systemd1"
        path: "/org/freedesktop/systemd1"
        iface: "org.freedesktop.systemd1.Manager"
    }


    /*Connections {
        target: missing
        onAlbumCoverChanged: {
            console.log("Updated cover for " + coverpath)
            misdatos.reloadItem(coverpath)
        }
    }*/


    ListModel {
        id: queueList
        property int currentIndex
    }

    ListModel {
        id: helperList
        property int currentIndex
    }

    ListModel {
        id: helperList2
        property int currentIndex
    }

    ListModel {
        id: myPlaylists
    }

    ListModel {
        id: radioModel
    }

    Banner { id: ibanner }

    Connections {
        target: myplaylistmanager

        onAddPlaylist: {
            //console.log("Adding playlist: " + list.name + " - " + list.count + " - " + list.type)
            myPlaylists.append({"name":list.name, "count":list.count, "type":list.type})
        }

        onAddItemToList: {
            if (list==="00000000000000000000") {
                //console.log("Adding to queue: " + item.title)
                queueList.append({"artist":item.artist, "album":item.album, "title":item.title,
                                   "duration":item.duration, "url":item.url})

            }
        }

        onAddItemToListDone: {
            if (list==="00000000000000000000")
                utils.setShuffle(queueList.count)
        }

    }

    Connections {
        target: radios

        onAppendRadio: {
            radioModel.append({"name":name, "url":genre, "radioid":radioid, "image":image})
        }
    }

    NowPlaying {
        id: nowPlayingPage

        onStatusChanged: {
            if (status===PageStatus.Activating)
                miniPlayer.open = false
            else if (status===PageStatus.Deactivating)
                miniPlayer.open = true
        }

    }

    Lyrics {
        id: lyricsPage
    }

    //property real miniPlayerSize: appWindow.height -miniPlayer.y

    bottomMargin: miniPlayer.visibleSize

    property bool playerOpened: miniPlayer.open || nowPlayingPage.status===PageStatus.Active

    function closeMiniplayer() {
        miniPlayer.open = false
    }

    property bool nppOpened: false

    DockedPanel {
        id: miniPlayer
        dock: Dock.Bottom
        width: parent.width
        height: Theme.itemSizeExtraLarge
        opacity: open && !Qt.inputMethod.visible? 1 : 0
        Behavior on opacity { FadeAnimation {} }
        open: false
        contentHeight: height
        flickableDirection: Flickable.VerticalFlick
        //z: 1

        onOpenChanged: {
            if (!open && nowPlayingPage.status===PageStatus.Inactive) {
                myPlayer.stop()
                myPlayer.setSource("")
                utils.removeAlbumArt()
                currentSongInfo = []
            }
        }

        Image {
            anchors.fill: parent
            fillMode: Image.PreserveAspectFit
            source: "image://theme/graphic-gradient-edge"
        }

        Item {
            id: miniPlayerControls
            anchors.fill: parent

            CoverArtList {
                id: thumb
                x: 0
                width: parent.height
                height: width
                itemimg: playingRadio? (currentSongInfo.coverurl? currentSongInfo.coverurl : currentSongInfo.imageurl) : utils.thumbnail(currentSongInfo.artist, currentSongInfo.album)
                text: qsTr("Cover not found")
                onClicked: {
                    if (nppOpened)
                        pageStack.navigateBack()
                    else
                        pageStack.push(nowPlayingPage)
                }
            }

            Column {
                spacing: Theme.paddingSmall
                anchors.left: thumb.right
                width: parent.width - thumb.width
                anchors.verticalCenter: parent.verticalCenter


                Label {
                    anchors.left: parent.left
                    anchors.leftMargin: Theme.paddingLarge
                    width: parent.width - Theme.paddingLarge*2
                    text: playingRadio? "<font color=\"" + Theme.highlightColor + "\">" + (currentSongInfo.artist!==""?
                                        currentSongInfo.artist : currentSongInfo.name) + "</font> " + currentSongInfo.title :
                          "<font color=\"" + Theme.highlightColor + "\">" + currentSongInfo.artist + "</font> " + currentSongInfo.title
                    font.pixelSize: Theme.fontSizeSmall
                    truncationMode: TruncationMode.Fade
                    textFormat: Text.RichText
                    //onTextChanged: console.log("NEW TEXT: " + text)
                    //horizontalAlignment: Text.AlignHCenter
                }


                Row {
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: parent.width/7

                    IconButton {
                        icon.source: "image://theme/icon-m-previous"
                        enabled: queueList.count>1
                        onClicked: {
                            nowPlayingPage.prevSong()
                            //nowPlayingPage.changeSong()
                        }
                    }

                    IconButton {
                        icon.source: myPlayer.state===2? "image://theme/icon-m-play" : "image://theme/icon-m-pause"
                        onClicked: {
                            if (myPlayer.state===2)
                                myPlayer.resume()
                            else
                                myPlayer.pause()
                        }

                    }

                    IconButton {
                        icon.source: "image://theme/icon-m-next"
                        enabled: queueList.count>1
                        onClicked: {
                            nowPlayingPage.nextSong()
                            //nowPlayingPage.changeSong()
                        }

                    }

                }

            }

        }

        PushUpMenu {
            // Shuffle and repeat mean nothing for a radio stream
            visible: !playingRadio
            Row {
                width: parent.width

                Switch {
                    id: shuffleMenu
                    width: parent.width * 0.5
                    icon.source: "image://theme/icon-m-shuffle"
                    checked: shuffle
                    onClicked: shuffle = !shuffle
                }

                Switch {
                    id: repeatMenu
                    width: parent.width * 0.5
                    icon.source: "image://theme/icon-m-repeat"
                    checked: repeat
                    onClicked: repeat = !repeat
                }
            }
        }

    }


    // Amber.Mpris is the MPRIS library the SailfishOS lockscreen and
    // notification area are built on. Its times are in milliseconds.
    MprisPlayer {
        id: mprisPlayer

        property var localMetadata

        function emitSeeked() {
            seeked(myPlayer.position * 1000)
        }

        serviceName: "flowplayer"

        // Mpris2 Root Interface
        identity: "FlowPlayer"
        desktopEntry: "flowplayer"
        supportedUriSchemes: ["file", "http", "https"]
        supportedMimeTypes: ["audio/x-wav", "audio/mp4", "audio/mpeg", "audio/x-vorbis+ogg", "audio/ogg", "audio/opus"]

        // Mpris2 Player Interface
        // CanControl must stay true: MPRIS clients read it once and, while it
        // is false, treat every other can* property as false too (the
        // lockscreen then hides its buttons for good).
        canControl: true
        canGoNext: queueList.count>1
        canGoPrevious: queueList.count>1
        canPause: queueList.count>0
        canPlay: queueList.count>0
        canSeek: queueList.count>0 && myPlayer.state>0 && !playingRadio

        playbackStatus: {
            if (myPlayer.state===2) {
                return Mpris.Paused
            } else if (myPlayer.state===1) {
                return Mpris.Playing
            } else {
                return Mpris.Stopped
            }
        }
        shuffle: false
        volume: 1

        onPauseRequested: myPlayer.pause()
        onPlayRequested: myPlayer.resume()

        onPlayPauseRequested: {
            console.log("=== FLOWPLAYER MPRIS: PlayPause")
            if (myPlayer.state===2) myPlayer.resume()
            else myPlayer.pause()
        }
        onStopRequested: myPlayer.stop()

        // This will start playback in any case. Mpris says to keep
        // paused/stopped if we were before but I suppose this is just
        // our general behavior decision here.
        onNextRequested: nowPlayingPage.nextSong()
        onPreviousRequested: nowPlayingPage.prevSong()

        onPositionRequested: position = myPlayer.position * 1000

        onSeekRequested: {
            var position = myPlayer.position + Math.round(offset / 1000)
            myPlayer.seek(position < 0 ? 0 : position)
            emitSeeked()
        }
        onSetPositionRequested: {
            myPlayer.seek(Math.round(position / 1000))
            emitSeeked()
        }

        onLocalMetadataChanged: {
            if (!localMetadata || !localMetadata.url)
                return

            var art
            if (playingRadio)
                art = currentSongInfo.coverurl? currentSongInfo.coverurl : currentSongInfo.imageurl
            else
                art = "file://" + utils.thumbnail(localMetadata.artist, localMetadata.album)

            metaData.trackId = "/org/flowplayer/track/" + Qt.md5(localMetadata.url.toString())
            metaData.url = localMetadata.url
            metaData.title = localMetadata.title
            // xesam:artist is a list of strings in the MPRIS spec
            metaData.contributingArtist = localMetadata.artist? [localMetadata.artist] : undefined
            metaData.albumTitle = localMetadata.album
            // Radio streams have no duration
            metaData.duration = isFinite(localMetadata.duration)? localMetadata.duration : undefined
            metaData.trackNumber = localMetadata.track
            metaData.artUrl = art? art : undefined
        }
    }

    MyMediaKeys {
        id: mediaKeys
    }

    // Direct BlueZ MediaPlayer registration. BlueZ prefers players that
    // register with it directly over those it sees through mpris-proxy,
    // which is why the default media player always wins BT button routing
    // without this component present.
    BluetoothMediaPlayer {
        id: bluetoothMediaPlayer

        status: {
            if (myPlayer.state===1) {
                return BluetoothMediaPlayer.Playing
            } else if (myPlayer.state===2) {
                return BluetoothMediaPlayer.Paused
            } else {
                return BluetoothMediaPlayer.Stopped
            }
        }

        onStatusChanged: console.log("BT PLAYBACK STATUS: " + status + " - Player state: " + myPlayer.state)

        repeat: appWindow.repeat
                    ? BluetoothMediaPlayer.RepeatAllTracks
                    : BluetoothMediaPlayer.RepeatOff

        shuffle: appWindow.shuffle
                    ? BluetoothMediaPlayer.ShuffleAllTracks
                    : BluetoothMediaPlayer.ShuffleOff

        position: myPlayer.position

        metadata: (currentSongInfo && currentSongInfo.url !== undefined)
            ? {
                "title":    currentSongInfo.title,
                "artist":   currentSongInfo.artist,
                "album":    currentSongInfo.album,
                "duration": currentSongInfo.duration * 1000
              }
            : ({})

        onPlayRequested: {
            console.log("=== BT MEDIA: Play")
            myPlayer.resume()
        }
        onPauseRequested: {
            console.log("=== BT MEDIA: Pause")
            myPlayer.pause()
        }
        onNextRequested: {
            console.log("=== BT MEDIA: Next")
            nowPlayingPage.nextSong()
        }
        onPreviousRequested: {
            console.log("=== BT MEDIA: Previous")
            nowPlayingPage.prevSong()
        }

        onChangeRepeat: {
            if (repeat == BluetoothMediaPlayer.RepeatOff) {
                appWindow.repeat = false
            } else if (repeat == BluetoothMediaPlayer.RepeatAllTracks) {
                appWindow.repeat = true
            }
        }

        onChangeShuffle: {
            if (shuffle == BluetoothMediaPlayer.ShuffleOff) {
                appWindow.shuffle = false
            } else if (shuffle == BluetoothMediaPlayer.ShuffleAllTracks) {
                appWindow.shuffle = true
            }
        }
    }


    function replaceText(text, str) {
        var ltext = text.toLowerCase()
        var lstr = str.toLowerCase()
        var ind = ltext.indexOf(lstr)
        if (ind<0 || str==="") return text
        var txt = text.substring(0,ind)
        var ntext = txt + "<font color=" + Theme.highlightColor + ">" +
                    text.slice(ind, ind+str.length)  + "</font>" +
                    text.slice(ind+str.length, text.length);
        return ntext;
    }

}
