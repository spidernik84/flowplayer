import QtQuick 2.0
import Sailfish.Silica 1.0
import org.nemomobile.systemsettings 1.0
import FlowPlayer 1.0

// Shown once, while no music folder is set: asks where the music is stored
Page {
    id: root

    allowedOrientations: appWindow.pagesOrientations

    // The start page behind would show an empty library: choose or skip
    backNavigation: false

    // Opens the folder browser on the music folder found inside base
    function pickFolder(base) {
        pageStack.push("AddFolder.qml", {"currentPath":utils.findMusicFolder(base),
                                         "firstStart":true,
                                         "acceptDestination":startPage,
                                         "acceptDestinationAction":PageStackAction.Pop})
    }

    SilicaFlickable {
        anchors.fill: parent
        contentHeight: col1.height + Theme.paddingLarge

        Column {
            id: col1
            width: parent.width

            // Keeps the icon clear of the display notch
            Item {
                width: parent.width
                height: Theme.paddingLarge*2 + (root.orientation===Orientation.Portrait ? Screen.topCutout.height : 0)
            }

            Image {
                anchors.horizontalCenter: parent.horizontalCenter
                width: Theme.iconSizeExtraLarge
                height: width
                source: "../../../icons/hicolor/172x172/apps/harbour-flowplayer-ng.png"
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("Welcome to FlowPlayer")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
                font.pixelSize: Theme.fontSizeExtraLarge
                font.family: Theme.fontFamilyHeading
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("A music player for Sailfish OS with lyrics, online radio and a 10-band equalizer.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge*2
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("Where is your music stored?")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.highlightColor
            }

            Item {
                width: parent.width
                height: Theme.paddingMedium
            }

            HomeDelegate {
                title: qsTr("Internal memory")
                subtitle: utils.findMusicFolder(StandardPaths.home)
                iconSource: "image://theme/icon-m-device"
                onClicked: pickFolder(StandardPaths.home)
            }

            Repeater {
                id: cards

                model: PartitionModel {
                    storageTypes: PartitionModel.External | PartitionModel.ExcludeParents
                }

                HomeDelegate {
                    property bool mounted: model.status===PartitionModel.Mounted
                    title: qsTr("SD card")
                    subtitle: mounted ? utils.findMusicFolder(model.mountPath) : qsTr("Not available")
                    iconSource: "image://theme/icon-m-sd-card"
                    enabled: mounted
                    opacity: enabled ? 1 : Theme.opacityLow
                    onClicked: pickFolder(model.mountPath)
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

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Label {
                x: Theme.horizontalPageMargin
                width: parent.width - Theme.horizontalPageMargin*2
                text: qsTr("You can add more music folders later in Settings.")
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignHCenter
                color: Theme.secondaryHighlightColor
                font.pixelSize: Theme.fontSizeSmall
            }

            Item {
                width: parent.width
                height: Theme.paddingLarge
            }

            Button {
                anchors.horizontalCenter: parent.horizontalCenter
                text: qsTr("Skip")
                onClicked: {
                    utils.setSettings("FirstStartDone", "yes")
                    pageStack.pop()
                }
            }
        }

        VerticalScrollDecorator {}
    }
}
