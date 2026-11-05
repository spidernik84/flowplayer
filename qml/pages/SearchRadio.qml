import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root
    property bool pageloaded: false

    allowedOrientations: appWindow.pagesOrientations

    property string searchValue: ""
    property bool enableSearch: false

    property bool loading: false

    property string selectedRadio: ""
    property string selectedRadioId: ""
    property string selectedRadioImage: ""

    ListModel { id: searchModel }

    // Stations saved from elsewhere may have no id, so also compare name and url
    function isSaved(name, url, radioid) {
        for (var i=0; i<radioModel.count; ++i) {
            var radio = radioModel.get(i)
            if ((radioid!=="" && radio.radioid===radioid) || (radio.name===name && radio.url===url))
                return true
        }
        return false
    }

    function saveStation(name, url, radioid, image) {
        radios.saveRadio(name, url, radioid, image)
        radioModel.clear()
        radios.loadRadios()
        ibanner.displayMessage(qsTr("Station saved"), true)
    }

    /*onStatusChanged: {
        if (status===PageStatus.Active) {
            if (!pageloaded) {
                radios.searchRadio("vorterix")


            }
        }
    }*/

    Connections {
        target: radios

        onAppendRadioSearch: {
            searchModel.append({"name":name, "genre":genre, "radioid":radioid, "url":url, "image":image})
        }

        onAppendRadioDone: loading = false

        onRadioInfoLoaded: {
            loading = false
            if (radiourl==="ERROR") {
                ibanner.displayMessage("Error loading radio", false)
                return;
            }

            playRadio(selectedRadio, radiourl, selectedRadioImage, selectedRadioId)

        }

    }

    SilicaListView {
        id: songlist
        anchors.fill: parent

        model: searchModel

        ViewPlaceholder {
            enabled: searchModel.count===0 && searchValue!=="" && !loading
            text: qsTr("No stations found")
        }

        header: Item {
            height: head2.height + search2.height
            width: parent.width

            Header {
                id: head2
                title: qsTr("Search station")
            }

            BusyIndicator {
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.verticalCenter: head2.verticalCenter
                size: BusyIndicatorSize.Small
                visible: loading
                running: visible
            }

            Item {
                id: search2
                width: parent.width
                anchors.top: head2.bottom
                height: searchInput2.height
                Behavior on height { NumberAnimation { duration: 200; easing.type: Easing.InOutQuad; property: "height" } }
                //onHeightChanged: listView.positionViewAtBeginning()
                clip: true

                TextField {
                    id: searchInput2
                    anchors.bottom: parent.bottom
                    width: parent.width - sbutton2.width
                    Behavior on opacity { FadeAnimation { duration: 200 } }
                    onTextChanged: enableSearch = searchInput2.text!==searchValue
                    EnterKey.enabled: searchInput2.text!=="" && !loading
                    EnterKey.onClicked: {
                        searchValue = searchInput2.text
                        enableSearch = false
                        loading = true
                        searchModel.clear()
                        radios.searchRadio(searchInput2.text)
                    }

                    // Open the keyboard straight away. Wait for the page to be
                    // active: focusing during the push transition is ignored.
                    Connections {
                        target: root
                        onStatusChanged: {
                            if (root.status===PageStatus.Active && searchInput2.text==="")
                                searchInput2.forceActiveFocus()
                        }
                    }
                }

                IconButton {
                    id: sbutton2
                    smooth: true
                    anchors.top: parent.top
                    anchors.right: parent.right
                    anchors.rightMargin: Theme.paddingMedium
                    height: Theme.itemSizeExtraSmall
                    width: height
                    icon.source: enableSearch && searchInput2.text!==""? "image://theme/icon-m-search" : "image://theme/icon-m-cancel"
                    icon.height: height -Theme.paddingMedium
                    icon.width: icon.height
                    enabled: searchInput2.text!=="" || searchValue!==""
                    onClicked: {
                        if (!enableSearch) {
                            searchInput2.text = ""
                        } else {
                            searchValue = searchInput2.text
                            enableSearch = false
                            loading = true
                            searchModel.clear()
                            radios.searchRadio(searchInput2.text)
                        }
                    }
                }
            }
        }

        delegate: ListItem {
            enabled: !loading
            contentHeight: Theme.itemSizeSmall
            width: parent.width
            clip: true

            menu: stationMenu

            Component {
                id: stationMenu
                ContextMenu {
                    MenuItem {
                        enabled: !isSaved(model.name, model.url, model.radioid)
                        text: qsTr("Save station")
                        onClicked: saveStation(model.name, model.url, model.radioid, model.image)
                    }
                }
            }

            Column {
                anchors.left: parent.left
                anchors.leftMargin: Theme.paddingLarge
                anchors.right: parent.right
                anchors.rightMargin: Theme.paddingLarge
                anchors.verticalCenter: parent.verticalCenter

                Label
                {
                    width: parent.width
                    text: model.name
                    truncationMode: TruncationMode.Fade
                    color: Theme.primaryColor
                }

                Label
                {
                    width: parent.width
                    text: model.genre
                    truncationMode: TruncationMode.Fade
                    color: Theme.secondaryColor
                    font.pixelSize: Theme.fontSizeExtraSmall
                    opacity: 0.8
                }
            }

            onClicked: {
                currentPlaylist = model.name
                loading = true
                selectedRadio = model.name
                selectedRadioId = model.radioid
                selectedRadioImage = model.image
                radios.getRadioInfo(model.radioid)
                //pageStack.push("PlaylistPage.qml")
            }

        }

    }



}
