import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0
import QtGraphicalEffects 1.0
import "dateandtime.js" as DT

Page {
    id: root
    property bool loaded: false

    allowedOrientations: appWindow.pagesOrientations

    canNavigateForward: database.loaded

    onStatusChanged: {
        if (status===PageStatus.Active) {
            console.log("CURRENT: " + lastGroup)
            rememberPage(lastGroup)
        }
    }

    property bool showSearch: false
    property string searchValue: ""
    property string pendingSearch: ""

    signal searchOpened

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
        if (changed)
            misdatos.setFilter(searchValue)
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

    SilicaFlickable {
        id: mainPanel
        anchors.fill: parent

        PullDownMenu {
            visible: utils.viewmode!=="flow"
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

        Loader {
            id: loaderpage
            anchors.fill: parent
            sourceComponent: utils.viewmode=="list" ? viewmodeList :
                             utils.viewmode=="grid" ? viewmodeGrid : viewmodeFlow

        }

        ViewPlaceholder {
            enabled: misdatos.count===0 && database.loaded
            flickable: mainPanel
            text: searchValue.trim()!=="" ? qsTr("No results") : qsTr("No music")
        }

    }


    // Page title and search field of the list and grid views
    Component {
        id: libraryHeader

        Item {
            height: head.height + search.height
            width: parent.width

            Header {
                id: head
                title: lastGroup==="artists"? qsTr("Artists") : qsTr("Albums")
            }

            Item {
                id: search
                width: parent.width
                anchors.top: head.bottom
                height: showSearch? searchInput.height : 0
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad; property: "height" } }
                onHeightChanged: {
                    if (loaderpage.item)
                        loaderpage.item.positionViewAtBeginning()
                }
                clip: true

                SearchField {
                    id: searchInput
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
                            searchInput.text = searchValue
                    }
                }

                Connections {
                    target: root
                    onSearchOpened: searchInput.forceActiveFocus()
                    onShowSearchChanged: {
                        if (!showSearch) {
                            searchInput.focus = false
                            searchInput.text = ""
                        }
                    }
                }
            }
        }
    }

    Component {
        id: viewmodeList

        SilicaListView {
            id: listView

            anchors.fill: parent
            // A current item would take focus from the search field on every model reset
            currentIndex: -1

            enabled: database.loaded? 1 : 0
            opacity: enabled? 1 : 0
            Behavior on opacity { FadeAnimation {} }

            section.property: currentListOrder=="artist" && lastGroup==="albums"? "band" : "title"
            section.criteria: currentListOrder=="artist" && lastGroup==="albums"? ViewSection.FullString : ViewSection.FirstCharacter
            section.delegate: SectionHeader { text: section }

            model: misdatos

            header: libraryHeader

            delegate: AlbumDelegate {
                contentHeight: Theme.itemSizeMedium
                width: parent.width

                myData: model
                name: replaceText(model.title, searchValue.trim())
                desc: replaceText(lastGroup=="albums"? model.band : model.artist, searchValue.trim())
                img: model.coverart
                count: model.acount
                time: model.songs

                menu: lastGroup==="albums" ? listAlbumMenu : null

                Component {
                    id: listAlbumMenu
                    ContextMenu {
                        MenuItem {
                            text: qsTr("Play next")
                            onClicked: queueAlbum(model.artist, model.title, model.acount, true)
                        }
                        MenuItem {
                            text: qsTr("Add to queue")
                            onClicked: queueAlbum(model.artist, model.title, model.acount, false)
                        }
                    }
                }

                onClicked: {
                    if (lastGroup==="albums")
                        pageStack.push("SongListView.qml", {"artist":model.artist, "album":model.title, "artistcount":model.acount})
                    else
                        pageStack.push("AlbumListView.qml", {"artist":model.title})
                }
            }
        }
    }

    Component {
        id: viewmodeGrid

        SilicaGridView {
            id: gridView

            anchors.fill: parent
            // A current item would take focus from the search field on every model reset
            currentIndex: -1

            enabled: database.loaded? 1 : 0
            opacity: enabled? 1 : 0
            Behavior on opacity { FadeAnimation {} }

            cellWidth: appWindow._screenWidth<appWindow._screenHeight? appWindow._screenWidth/3 : appWindow._screenWidth/5
            cellHeight: cellWidth
            cacheBuffer: 3000

            model: misdatos

            header: libraryHeader

            // GridItem pushes the rows below down when its menu opens
            delegate: GridItem {
                width: gridView.cellWidth
                contentHeight: gridView.cellHeight

                menu: lastGroup==="albums" ? gridAlbumMenu : null

                CoverArtList {
                    id: cvl
                    anchors.fill: parent
                    enabled: false  // presses are handled by the GridItem
                    itemimg: model.coverart
                    text: model.title
                    artist: model.artist
                    album: model.title
                    textvisible: lastGroup==="artists"
                }

                Component {
                    id: gridAlbumMenu
                    ContextMenu {
                        MenuItem {
                            text: qsTr("Play next")
                            onClicked: queueAlbum(model.artist, model.title, model.acount, true)
                        }
                        MenuItem {
                            text: qsTr("Add to queue")
                            onClicked: queueAlbum(model.artist, model.title, model.acount, false)
                        }
                    }
                }

                onClicked: {
                    if (lastGroup==="albums")
                        pageStack.push("SongListView.qml", {"artist":model.artist, "album":model.title, "artistcount":model.acount})
                    else
                        pageStack.push("AlbumListView.qml", {"artist":model.title})
                }
            }
        }
    }


    Component {
        id: viewmodeFlow

        CoverFlow {
            id: view

            anchors.fill: parent
            enabled: database.loaded? 1 : 0
            opacity: enabled? 1 : 0
            Behavior on opacity { FadeAnimation {} }

            topMargin: root.isPortrait? Theme.paddingLarge*2 : Theme.paddingLarge*2

            model: misdatos
            clip: true
            currentIndex: 0

            Connections {
                target: misdatos

                onLoadChanged: {
                    if (misdatos.loaded && misdatos.count>0) {
                        console.log("LOAD CHANGED!!!!!!")
                        if (lastGroup=="albums") {
                            label1.text = currentItem.myData.acount==="1" ? currentItem.myData.artist : qsTr("Various artists")
                            label2.text = currentItem.myData.title
                        } else {
                            label1.text = currentItem.myData.title
                            label2.text = currentItem.myData.artist
                        }
                    }
                    view.resetIndex()
                }
            }

            delegate: Item {
                id: item
                property variant myData: model
                property string artist: model.artist
                property string album: model.title
                property string acount: model.acount

                x: 0
                z: PathView.z
                width: Theme.itemSizeExtraLarge*2
                height: root.isPortrait? width*2 : width*1.5
                scale: PathView.iconScale

                property real pathAngle: PathView.angle
                //property alias imageSource: dlgImg.source

                Column  {
                    id: delegate
                    y: view.topMargin
                    spacing: 0

                    Rectangle {
                        id: delegateImage

                        width: item.width
                        height: width
                        color: (dlgImg.status === Image.Ready) ? "black" : "transparent"

                        z: reflection.z + 1

                        CoverArtList {
                            //cache: false
                            id: dlgImg
                            itemimg: model.coverart==="loading" ? "" : model.coverart
                            itemwidth: item.width
                            itemheight: itemwidth
                            artist: model.artist
                            album: model.title
                            anchors.centerIn: parent
                            text: model.title
                            clip: true
                            showBorder: true
                            //fillMode: Image.Stretch
                        }
                    }

                    Item {
                        id: reflection
                        width: item.width
                        height: item.height

                        Rectangle {
                            id: mask
                            width: item.width
                            height: width
                            visible: false
                            gradient: Gradient {
                                GradientStop { position: 0.25; color: "transparent" }
                                GradientStop { position: 1.0; color: "black" }
                            }

                        }

                        CoverArtList {
                            id: imgtomask
                            itemwidth: item.width
                            itemheight: itemwidth
                            anchors.centerIn: parent
                            artist: model.artist
                            album: model.title
                            clip: true
                            itemimg: model.coverart==="loading" ? "" : model.coverart
                            text: model.title
                            visible: false
                            showBorder: true
                            //fillMode: Image.Stretch
                        }

                        OpacityMask {
                            anchors.fill: imgtomask
                            source: imgtomask
                            maskSource: mask
                            opacity: 0.75
                            transform : Rotation {
                                origin {
                                  x: item.width / 2
                                  y: root.isPortrait? item.width / 3.97 : item.width / 2.68
                                }

                                axis {x: 1; y: 0; z: 0}
                                angle: 180
                            }
                        }
                    }
                }


                transform: Rotation {
                    id: rotat
                    origin.x: item.width/2
                    origin.y: item.width/2
                    axis { x: 0; y: 1; z: 0 }
                    angle: item.pathAngle/1.5
                }

                states: [
                    State {
                        name: "scaled"
                        PropertyChanges {
                            target: delegateImage
                            scale: 1.8
                        }
                    }
                ]

                transitions: [
                    Transition {
                        from: ""
                        to: "scaled"
                        reversible: true
                        ParallelAnimation {
                            PropertyAnimation {
                                target: delegateImage
                                properties: "scale"
                                duration: 300
                            }
                        }
                    }
                ]

                MouseArea {
                    anchors.fill: parent
                    onClicked: {
                        view.currentIndex = model.index
                        if (lastGroup==="albums")
                            pageStack.push("SongListView.qml", {"artist":model.artist, "album":model.title, "artistcount":model.acount})
                        else
                            pageStack.push("AlbumListView.qml", {"artist":model.title})
                    }
                    onPressAndHold: {
                        if (lastGroup!=="albums")
                            return
                        view.currentIndex = model.index
                        flowAlbumMenu.open(model.artist, model.title, model.acount)
                    }

                }

            }
            pathItemCount: root.isPortrait? 5 : 7

            onCurrentIndexChanged: {
                if (lastGroup=="albums") {
                    label1.text = currentItem.myData.acount==="1" ? currentItem.myData.artist : qsTr("Various artists")
                    label2.text = currentItem.myData.title
                } else {
                    label1.text = currentItem.myData.title
                    label2.text = currentItem.myData.artist
                }
            }

            Column {
                anchors.bottom: parent.bottom
                anchors.bottomMargin: myPlayer.state>0 ? Theme.paddingMedium : Theme.paddingLarge
                width: parent.width
                spacing: myPlayer.state>0 ? 0 : Theme.paddingMedium

                Label {
                    id: label1
                    //text: view.currentItem.myData.acount==="1" ? view.currentItem.myData.artist : qsTr("Various artists")
                    width: parent.width - Theme.paddingLarge*2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.highlightColor
                    truncationMode: TruncationMode.Fade
                    horizontalAlignment: Text.AlignHCenter
                    visible: view.visible
                }
                Label {
                    id: label2
                    //text: view.currentItem.myData.title
                    font.pixelSize: Theme.fontSizeSmall
                    width: parent.width - Theme.paddingLarge*2
                    anchors.horizontalCenter: parent.horizontalCenter
                    color: Theme.primaryColor
                    elide: Text.ElideRight
                    horizontalAlignment: Text.AlignHCenter
                    visible: view.visible
                }

            }

            // Silica's ContextMenu needs a list item to attach to, which the
            // carousel doesn't have, so it gets a small menu of its own shown
            // over the album labels. Tapping anywhere else closes it.
            MouseArea {
                id: flowAlbumMenu
                property string artist
                property string album
                property string various

                function open(artist, album, various) {
                    flowAlbumMenu.artist = artist
                    flowAlbumMenu.album = album
                    flowAlbumMenu.various = various
                    opacity = 1
                }
                function close() {
                    opacity = 0
                }

                anchors.fill: parent
                visible: opacity > 0
                opacity: 0
                Behavior on opacity { FadeAnimation {} }
                onClicked: close()

                Rectangle {
                    anchors.fill: flowMenuItems
                    color: Theme.highlightDimmerColor
                    opacity: 0.9
                }

                Column {
                    id: flowMenuItems
                    width: parent.width
                    anchors.bottom: parent.bottom

                    BackgroundItem {
                        height: Theme.itemSizeSmall
                        onClicked: {
                            queueAlbum(flowAlbumMenu.artist, flowAlbumMenu.album, flowAlbumMenu.various, true)
                            flowAlbumMenu.close()
                        }
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("Play next")
                            color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                    BackgroundItem {
                        height: Theme.itemSizeSmall
                        onClicked: {
                            queueAlbum(flowAlbumMenu.artist, flowAlbumMenu.album, flowAlbumMenu.various, false)
                            flowAlbumMenu.close()
                        }
                        Label {
                            anchors.centerIn: parent
                            text: qsTr("Add to queue")
                            color: parent.highlighted ? Theme.highlightColor : Theme.primaryColor
                        }
                    }
                }
            }

        }
    }



}

