import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0
import "dateandtime.js" as DT

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    property bool loaded: false
    property bool isqueue: false

    property bool showSearch: false
    property string searchValue: ""
    property string pendingSearch: ""

    signal searchOpened

    onStatusChanged: {
        if (status===PageStatus.Active)
            rememberPage("tracks")
    }

    // Filters shortly after typing stops, as resetting the model rebuilds the view
    function queueSearch(text) {
        if (text===searchValue) {
            searchTimer.stop()
            return
        }
        pendingSearch = text
        searchTimer.restart()
    }

    function searchData(text) {
        // The filter ignores surrounding spaces, so adding one changes nothing
        var changed = text.trim()!==searchValue.trim()
        searchValue = text
        if (changed) {
            misdatos.setFilter(searchValue)
            isqueue = false
        }
    }

    function closeSearch() {
        searchTimer.stop()
        searchData("")
        showSearch = false
    }

    Timer {
        id: searchTimer
        interval: 300
        onTriggered: searchData(pendingSearch)
    }

    SilicaListView {
        id: songlist
        anchors.fill: parent
        clip: true
        // A current item would take focus from the search field on every model reset
        currentIndex: -1

        PullDownMenu {
            MenuItem {
                text: showSearch? qsTr("Hide search") : qsTr("Search")
                onClicked: {
                    if (showSearch)
                        closeSearch()
                    else
                        showSearch = true
                }
                // Focus can only be taken once the menu has closed
                onDelayedClick: {
                    if (showSearch)
                        searchOpened()
                }
            }
        }

        model: misdatos

        header: Item {
            height: head2.height + search2.height
            width: parent.width

            Header {
                id: head2
                title: qsTr("Tracks")
            }

            Item {
                id: search2
                width: parent.width
                anchors.top: head2.bottom
                height: showSearch? searchInput2.height : 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad; property: "height" } }
                onHeightChanged: songlist.positionViewAtBeginning()
                clip: true

                SearchField {
                    id: searchInput2
                    anchors.bottom: parent.bottom
                    width: parent.width
                    opacity: showSearch ? 1 : 0
                    Behavior on opacity { FadeAnimation { duration: 200 } }
                    onTextChanged: queueSearch(text)
                    EnterKey.iconSource: "image://theme/icon-m-enter-close"
                    EnterKey.onClicked: focus = false
                }

                Connections {
                    target: misdatos
                    // Don't overwrite what's still being typed
                    onLoadChanged: {
                        if (!searchTimer.running)
                            searchInput2.text = searchValue
                    }
                }

                Connections {
                    target: root
                    onSearchOpened: searchInput2.forceActiveFocus()
                    onShowSearchChanged: {
                        if (!showSearch) {
                            searchInput2.focus = false
                            searchInput2.text = ""
                        }
                    }
                }
            }
        }

        delegate: AlbumDelegate {
            myData: model
            name: replaceText(model.title, searchValue.trim())
            desc: replaceText(model.artist + " - " + model.album, searchValue.trim())
            img: ""
            time: DT.getDuration(model.duration)
            cindex: index
            isplaying: decodeURIComponent(model.url) === decodeURIComponent(myPlayer.source)
            contentHeight: Theme.itemSizeSmall

            menu: ContextMenu {
                MenuItem {
                    text: qsTr("Edit metadata")
                    onClicked: {
                        console.log("METADATA: " + model.url)
                        meta.setFile(model.url)
                        pageStack.push ("Metadata.qml", {"artist": model.artist,
                                            "album": model.album,
                                            "title": model.title
                                        })
                    }
                }
                MenuItem {
                    text: qsTr("Play next")
                    onClicked: queueTrack(model, true)
                }
                MenuItem {
                    text: qsTr("Add to queue")
                    onClicked: queueTrack(model, false)
                }
                MenuItem {
                    text: qsTr("Add to playlist")
                    onClicked: {
                        filterArtist = ""
                        filterAlbum = ""
                        filterSong = model.url
                        pageStack.push("SelectPlaylist.qml")
                    }
                }
                MenuItem {
                    text: model.fav==="1"? qsTr("Remove from favorites") : qsTr("Add to favorites")
                    onClicked: {
                        if (model.fav==="1")
                            favRemoved()
                        else
                            favAdded()
                        misdatos.setFav(model.url, model.fav)
                    }
                }
            }

            onClicked: {
                // The queue only mirrors this list until tracks get queued from elsewhere
                if (isqueue && model.index<queueList.count && queueList.get(model.index).url===model.url)
                {
                    nowPlayingPage.playSong(model.index)
                }
                else
                {
                    var cindex = model.index
                    queueList.clear()
                    myplaylistmanager.clearList("00000000000000000000")

                    if (searchValue.trim()==="")
                    {
                        myplaylistmanager.addAlbumToList("00000000000000000000", "ALL", "ALL", "ALL", "")
                    }
                    else
                    {
                        misdatos.addFilterToQueue()
                    }
                    myplaylistmanager.loadPlaylist("00000000000000000000")
                    queueList.currentIndex = cindex
                    nowPlayingPage.playSong(cindex)
                    isqueue = true
                }
                miniPlayer.open = true
            }

        }

        ViewPlaceholder {
            enabled: songlist.count===0
            flickable: songlist
            text: searchValue.trim()!=="" ? qsTr("No results") : qsTr("No music")
        }
    }


}
