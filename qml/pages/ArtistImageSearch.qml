import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    onStatusChanged: {
        if (status===PageStatus.Active) {
            missingArtists.loadData()
        }
        if (status===PageStatus.Deactivating) {
            missingArtists.clearList()
        }
    }

    SilicaListView {
        id: artistList
        anchors.fill: parent
        model: missingArtists
        clip: true

        PullDownMenu {
            enabled: artistList.count>0

            MenuItem {
                text: qsTr("Start downloading")
                visible: !missingArtists.running
                onClicked: missingArtists.startDownload()
            }
            MenuItem {
                text: qsTr("Stop downloading")
                visible: missingArtists.running
                onClicked: missingArtists.cancelAll()
            }
        }

        header: Header {
            title: qsTr("Download artist pictures")
            description: missingArtists.running || missingArtists.processed>0
                         ? qsTr("%1 of %2 found").arg(missingArtists.found).arg(missingArtists.processed)
                         : ""
        }

        delegate: DownloadingListDelegate {
            myData: model
            name: model.title
            desc: model.band
            img: model.coverart
            isSel: model.isSelected
            loadSel: model.loading
            emptyText: qsTr("No image")
            height: Theme.itemSizeMedium
            cindex: index
        }

        VerticalScrollDecorator {}

        ViewPlaceholder {
            enabled: artistList.count===0 && missingArtists.loaded
            Behavior on opacity { FadeAnimation {} }
            text: qsTr("There are no missing artist pictures in your music collection")
        }
    }

    BusyIndicator {
        anchors.centerIn: root
        size: BusyIndicatorSize.Large
        visible: !missingArtists.loaded
        running: visible
    }

}
