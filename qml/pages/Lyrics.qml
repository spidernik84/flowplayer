import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0


Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool fetchingLyrics: false
    property bool fetchingInfo: false
    property string currentLyrics: ""

    property bool editmode: false
    property string editArtist
    property string editTitle
    property string editLyrics

    function clearLyrics() {
        currentLyrics = ""
    }

    function reloadLyrics() {
        console.log("=== Lyrics: reloadLyrics ->",
                    currentSongInfo.artist, "/", currentSongInfo.title)
        currentLyrics = ""
        utils.readLyrics(currentSongInfo.artist, currentSongInfo.title)
    }

    function reloadInfo() {
        fetchingInfo = true
        lfm.getBio(currentSongInfo.artist)
        thumb.source = lfm.offlineBioImg(currentSongInfo.artist)
        bioText.text = ""
        bioText.text = lfm.bioInfo()
    }

    Connections {
        target: lfm

        onBioChanged: {
            fetchingInfo = false

            if (thumb.source == "")
                thumb.source = lfm.bioImg()

            bioText.text = ""
            bioText.text = "<style type='text/css'>a:link {color:" + Theme.highlightColor + "; text-decoration:none} " +
                    "a:visited {color:" + Theme.secondaryHighlightColor + "; text-decoration:none}</style>" + lfm.bioInfoLarge()
        }
    }

    Connections {
        target: utils

        onLyricsChanged: {
            currentLyrics = utils.lyrics
            fetchingLyrics = false
            console.log("=== Lyrics: onLyricsChanged, online =", utils.lyricsonline,
                        "nolyrics =", utils.nolyrics, "autosearch =", utils.autosearch)
            if (!utils.lyricsonline && utils.nolyrics) {
                if (utils.autosearch!=="yes") {
                    console.log("=== Lyrics: skipped, autosearch is off")
                    return;
                }
                if (!utils.isOnline()) {
                    console.log("=== Lyrics: offline, not fetching")
                    return
                }
                console.log("=== Lyrics: triggering LRCLIB fetch")
                fetchingLyrics = true
                utils.getLyrics(currentSongInfo.artist, currentSongInfo.title,
                                currentSongInfo.album, currentSongInfo.duration)

            }
            if (utils.lyricsonline && !utils.nolyrics && utils.readSettings("SaveAfterSearch", "no")==="yes")
            {
                console.log("Saving lyrics automatically")
                utils.saveLyrics(currentSongInfo.artist, currentSongInfo.title, currentLyrics)
            }

        }
    }

    onStatusChanged: {
        if (status===PageStatus.Activating) {
            nppOpened = true
            console.log("=== Lyrics: Activating, artist =",
                        currentSongInfo ? currentSongInfo.artist : "NO INFO")
            if (currentSongInfo && currentSongInfo.artist !== undefined)
                reloadLyrics()
        }
    }

    BusyIndicator {
        id: busyIndicator
        size: BusyIndicatorSize.Large
        anchors.centerIn: parent
        visible: fetchingLyrics && flickArea.visible
        running: visible
    }

    property bool showLyrics: true

    SilicaFlickable {
        id: flickArea
        anchors.fill: parent
        contentHeight: column.height + Theme.paddingLarge
        opacity: showLyrics? 1 : 0
        visible: opacity >0
        Behavior on opacity { FadeAnimation {} }
        clip: true

        PullDownMenu {
            MenuItem {
                text: qsTr("Search lyrics")
                onClicked: {
                    fetchingLyrics = true
                    utils.getLyrics(currentSongInfo.artist, currentSongInfo.title,
                                    currentSongInfo.album, currentSongInfo.duration)
                }
            }
            MenuItem {
                text: qsTr("Save lyrics")
                visible: !utils.nolyrics && utils.lyricsonline
                onClicked: {
                    utils.saveLyrics(currentSongInfo.artist, currentSongInfo.title, currentLyrics)
                }
            }
        }


        Column {
            id: column
            x: Theme.paddingLarge
            spacing: Theme.paddingMedium
            width: parent.width - Theme.paddingLarge*2

            Item {
                height: lheader.height
                width: parent.width + Theme.paddingLarge

                Header {
                    id: lheader
                    title: qsTr("Lyrics")
                    width: parent.width -lBtn.width
                }

                IconButton {
                    id: lBtn
                    icon.source: "image://theme/icon-m-about"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingSmall
                    onClicked: showLyrics = !showLyrics
                }

            }

            Label {
                id: lTextT
                wrapMode: TextEdit.WordWrap
                textFormat: Text.RichText
                width: parent.width
                text: currentSongInfo!==[]? (editmode ? editTitle : currentSongInfo.title) : ""
                color: Theme.highlightColor
            }

            Label {
                id: lTextA
                wrapMode: TextEdit.WordWrap
                textFormat: Text.RichText
                width: parent.width
                font.pixelSize: Theme.fontSizeSmall
                text: currentSongInfo!==[]? (qsTr("by") + " <font color=\"" + Theme.primaryColor + "\">" +
                      (editmode? editArtist : currentSongInfo.artist ) + "</font>") : ""
                color: Theme.secondaryColor
            }

            // Synced lyrics: one Label per line, colored by playback time.
            // Falls back to the plain Label below when no LRC is available.
            Column {
                id: syncedColumn
                width: parent.width
                spacing: Theme.paddingSmall
                visible: !fetchingLyrics && !editmode &&
                         utils.syncedLyrics.length > 0

                Repeater {
                    model: utils.syncedLyrics

                    Label {
                        width: syncedColumn.width
                        wrapMode: TextEdit.WordWrap
                        textFormat: Text.PlainText
                        text: modelData.text
                        font.pixelSize: Theme.fontSizeSmall

                        // Anticipate the highlight by this many ms so the
                        // line lights up slightly before the timestamp hits.
                        // Compensates for the 1s position-update granularity
                        // and matches user perception of lyric timing.
                        readonly property int anticipation: 250

                        property bool active: {
                            var pos = myPlayer.position * 1000 + anticipation
                            var t = modelData.time
                            var next = (index + 1 < utils.syncedLyrics.length)
                                ? utils.syncedLyrics[index + 1].time
                                : 0x7fffffff
                            return pos >= t && pos < next
                        }

                        color: active ? Theme.highlightColor : Theme.secondaryColor
                        font.bold: active
                    }
                }
            }

            Label {
                id: lText
                x: Theme.paddingLarge
                visible: !fetchingLyrics && !editmode &&
                         currentSongInfo.artist!==[] &&
                         utils.syncedLyrics.length === 0
                wrapMode: TextEdit.WordWrap
                textFormat: Text.RichText
                width: parent.width - Theme.paddingLarge*2
                font.pixelSize: Theme.fontSizeSmall
                text: currentLyrics
                color: Theme.secondaryColor
            }
        }

    }

    SilicaFlickable {
        id: infoArea
        anchors.fill: parent
        contentHeight: column2.height + Theme.paddingLarge
        visible: opacity >0
        opacity: showLyrics? 0 : 1
        Behavior on opacity { FadeAnimation {} }
        clip: true

        PullDownMenu {
            MenuItem {
                text: qsTr("Reload picture")
                onClicked: {
                    lfm.removeImage(currentSongInfo.artist)
                    reloadInfo()
                }
            }
            MenuItem {
                text: qsTr("Reload info")
                onClicked: {
                    reloadInfo()
                }
            }
        }

        Column {
            id: column2
            x: Theme.paddingLarge
            spacing: Theme.paddingMedium
            width: parent.width - Theme.paddingLarge*2

            property real imageWidth

            Item {
                height: iheader.height
                width: parent.width + Theme.paddingLarge

                Header {
                    id: iheader
                    title: qsTr("Info")
                    width: parent.width -iBtn.width
                }

                IconButton {
                    id: iBtn
                    icon.source: "image://theme/icon-m-sounds"
                    anchors.verticalCenter: parent.verticalCenter
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingSmall
                    onClicked: showLyrics = !showLyrics
                }

            }

            Image {
                id: thumb
                anchors.horizontalCenter: parent.horizontalCenter
                width: parent.width
                fillMode: Image.PreserveAspectFit
                //visible: false
                //onWidthChanged: column2.imageWidth = parent.width / thumb.width
                cache: false
                smooth: true
            }

            Label {
                id: bioText
                anchors.left: parent.left
                wrapMode: TextEdit.WordWrap
                textFormat: Text.RichText
                width: parent.width
                font.pixelSize: Theme.fontSizeSmall
                color: Theme.secondaryColor
                onLinkActivated: Qt.openUrlExternally(link)
            }

            BusyIndicator {
                id: busyIndicator2
                size: BusyIndicatorSize.Medium
                anchors.horizontalCenter: parent.horizontalCenter
                visible: fetchingInfo
                running: visible
            }

        }

    }


}
