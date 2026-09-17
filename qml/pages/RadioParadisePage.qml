import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root
    allowedOrientations: appWindow.pagesOrientations

    // Radio Paradise Main Mix endpoints
    readonly property string streamUrl: "http://stream.radioparadise.com/flac"
    readonly property string fallbackStreamUrl: "http://stream.radioparadise.com/aac-320"
    readonly property string apiUrl: "https://api.radioparadise.com/api/now_playing"

    // Metadata properties
    property string trackTitle: ""
    property string trackArtist: ""
    property string trackAlbum: ""
    property string coverUrl: ""
    property int secondsRemaining: 30

    // Timer to refresh metadata
    Timer {
        id: metadataTimer
        interval: Math.max(10, secondsRemaining) * 1000   // wait at least 10 s
        repeat: false
        running: false
        onTriggered: fetchNowPlaying()
    }

    // Fetch metadata from Radio Paradise API
    function fetchNowPlaying() {
        if (myPlayer.playbackState !== MediaPlayer.PlayingState) {
            return
        }
        var xhr = new XMLHttpRequest();
        xhr.open("GET", apiUrl);
        xhr.onreadystatechange = function() {
            if (xhr.readyState === XMLHttpRequest.DONE) {
                if (xhr.status === 200) {
                    try {
                        var data = JSON.parse(xhr.responseText);
                        trackTitle  = data.title  || ""
                        trackArtist = data.artist || ""
                        trackAlbum  = data.album  || ""
                        coverUrl    = data.cover_med || data.cover || ""
                        secondsRemaining = data.time || 30
                        metadataTimer.interval = Math.max(10, secondsRemaining) * 1000
                    } catch (e) {
                        console.log("Radio Paradise JSON parse error:", e)
                    }
                } else {
                    console.log("Radio Paradise API error, status:", xhr.status)
                }
                metadataTimer.start()
            }
        }
        xhr.send()
    }

    // Start playback and metadata polling
    function startPlayback() {
        myPlayer.setSource(streamUrl)
        myPlayer.play()
        fetchNowPlaying()
        metadataTimer.start()
    }

    // Stop playback and metadata polling

    function stopPlayback() {
        myPlayer.pause()
        metadataTimer.stop()
    }

    // Stop playback when leaving page (optional)
    onStatusChanged: {
        if (status === PageStatus.Inactive) {
            metadataTimer.stop()
        }
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge

        Column {
            id: column
            width: parent.width
            spacing: Theme.paddingLarge

            PageHeader {
                title: qsTr("Radio Paradise – Main Mix")
            }

            // Cover art
            Image {
                id: coverImage
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.itemSizeHuge * 2
                height: width
                source: coverUrl
                fillMode: Image.PreserveAspectFit
                asynchronous: true
                cache: true
                visible: coverUrl !== ""

                // Placeholder when no cover is available
                Rectangle {
                    anchors.fill: parent
                    color: Theme.overlayBackgroundColor
                    visible: parent.status !== Image.Ready
                    Label {
                        anchors.centerIn: parent
                        text: qsTr("No cover")
                        color: Theme.secondaryColor
                    }
                }
            }

            // Track information
            Label {
                id: titleLabel
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                text: trackTitle || qsTr("Loading…")
                font.pixelSize: Theme.fontSizeLarge
                color: Theme.primaryColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                id: artistLabel
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                text: trackArtist || ""
                font.pixelSize: Theme.fontSizeMedium
                color: Theme.secondaryColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

            Label {
                id: albumLabel
                width: parent.width - 2 * Theme.paddingLarge
                anchors.horizontalCenter: parent.horizontalCenter
                text: trackAlbum || ""
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryHighlightColor
                horizontalAlignment: Text.AlignHCenter
                wrapMode: Text.Wrap
            }

        }
    }

    // Automatically start playback when page is opened
    Component.onCompleted: {
        startPlayback()
    }
}
