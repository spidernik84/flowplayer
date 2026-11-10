import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.systemsettings 1.0
import FlowPlayer 1.0

// The places music can be stored, each showing the music folder found in it.
// Used by the first start page and when adding a folder in Settings.
Column {
    id: root
    width: parent.width

    // A storage was chosen: base is its root, to search for the music folder in
    signal picked(string base)

    // Folders already in the collection, to tell the user
    property var folders: utils.readSettings("Folders", "").split("<separator>")

    function subtitleFor(base) {
        var path = utils.findMusicFolder(base)
        return folders.indexOf(path)>=0 ? qsTr("%1 (already added)").arg(path) : path
    }

    HomeDelegate {
        title: qsTr("Internal memory")
        subtitle: root.subtitleFor(StandardPaths.home)
        iconSource: "image://theme/icon-m-device"
        onClicked: root.picked(StandardPaths.home)
    }

    Repeater {
        id: cards

        model: PartitionModel {
            storageTypes: PartitionModel.External | PartitionModel.ExcludeParents
        }

        HomeDelegate {
            property bool mounted: model.status===PartitionModel.Mounted
            title: qsTr("SD card")
            subtitle: mounted ? root.subtitleFor(model.mountPath) : qsTr("Not available")
            iconSource: "image://theme/icon-m-sd-card"
            enabled: mounted
            opacity: enabled ? 1 : Theme.opacityLow
            onClicked: root.picked(model.mountPath)
        }
    }

    HomeDelegate {
        visible: cards.count===0
        title: qsTr("SD card")
        subtitle: qsTr("No SD card found")
        iconSource: "image://theme/icon-m-sd-card"
        enabled: false
        opacity: Theme.opacityLow
    }
}
