import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

import "dateandtime.js" as DT


ListItem
{
    id: itemcontainer
    property variant myData

    property string name
    property string desc
    property string time
    property string img
    property string count: "1"
    property int cindex
    property bool isplaying
    property bool selected
    property bool showCover: false
    property alias textSize: thumb.textSize
    property int tracknum: 0
    // Edit mode of a ReorderableListView: shows a drag handle, and
    // highlights the row when selected or when it marks where a drag lands
    property bool editing: false
    property bool dragged: false

    // Formats track number as "xx"
    function formatTrack(t) {
        var n = parseInt(t)
        if (!n || n <= 0) return ""
        return n < 10 ? "0" + n : "" + n
    }

    width: parent.width
    // Use contentHeight (not height) so ListItem can grow itself when the
    // context menu opens, and so the menu is placed below the whole item.
    contentHeight: Theme.itemSizeSmall
    highlighted: down || menuOpen || (editing && selected) || dragged

    Item {
        id: rowContainer
        width: parent.width
        height: Theme.itemSizeSmall

        CoverArtList {
            id: thumb
            x: Theme.paddingLarge
            width: itemimg!="" || showCover? parent.height : 0
            anchors.verticalCenter: parent.verticalCenter
            height: width
            itemimg: img
            artist: desc
            album: name
            text: qsTr("Not found")
        }

        Label
        {
            id: trackLabel
            text: formatTrack(tracknum)
            anchors.left: img!="" || showCover? thumb.right : parent.left
            anchors.leftMargin: img!="" || showCover? Theme.paddingMedium : Theme.paddingLarge
            anchors.verticalCenter: parent.verticalCenter
            width: Theme.fontSizeMedium * 2.5
            font.pixelSize: Theme.fontSizeMedium
            horizontalAlignment: Text.AlignRight
            truncationMode: TruncationMode.Fade
            color: isplaying? Theme.highlightColor : Theme.secondaryColor
        }

        Column {
            anchors.left: trackLabel.right
            anchors.leftMargin: Theme.paddingSmall
            anchors.right: editing ? dragHandle.left : parent.right
            anchors.rightMargin: editing ? 0 : Theme.paddingLarge
            anchors.verticalCenter: parent.verticalCenter
            spacing: parent.height===Theme.itemSizeSmall? 0 : Theme.paddingSmall

            Label
            {
                text: name
                font.pixelSize: Theme.fontSizeMedium
                color: isplaying? Theme.highlightColor : Theme.primaryColor
                textFormat: Text.RichText
                truncationMode: TruncationMode.Fade
                width: parent.width
            }

            Item {
                width: parent.width
                height: descText.height

                Label
                {
                    id: descText
                    text: desc
                    anchors.top: parent.top
                    anchors.left: parent.left
                    truncationMode: TruncationMode.Fade
                    width: parent.width -timeText.paintedWidth -Theme.paddingLarge
                    font.pixelSize: Theme.fontSizeExtraSmall
                    textFormat: Text.RichText
                    color: isplaying? Theme.secondaryHighlightColor : Theme.secondaryColor
                }

                Label
                {
                    id: timeText
                    text: time
                    anchors.right: parent.right
                    anchors.top: parent.top
                    horizontalAlignment: Text.AlignRight
                    width: parent.width
                    font.pixelSize: Theme.fontSizeExtraSmall
                    color: isplaying? Theme.secondaryHighlightColor : Theme.secondaryColor
                }
            }

        }
        Item {
            id: dragHandle
            visible: editing
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            width: editing ? Theme.itemSizeSmall : 0
            height: parent.height

            Column {
                anchors.centerIn: parent
                spacing: Theme.paddingSmall
                Repeater {
                    model: 3
                    Rectangle {
                        width: Theme.iconSizeSmall
                        height: Math.max(2, Theme.paddingSmall/2)
                        radius: height/2
                        color: handleArea.pressed ? Theme.highlightColor : Theme.secondaryColor
                    }
                }
            }

            MouseArea {
                id: handleArea
                anchors.fill: parent
                enabled: editing
                preventStealing: true
                onPressed: itemcontainer.ListView.view.startDrag(itemcontainer, index,
                                                                 handleArea.mapToItem(itemcontainer.ListView.view, mouse.x, mouse.y).y)
                onPositionChanged: itemcontainer.ListView.view.updateDrag(handleArea.mapToItem(itemcontainer.ListView.view, mouse.x, mouse.y).y)
                onReleased: itemcontainer.ListView.view.endDrag()
                onCanceled: itemcontainer.ListView.view.endDrag()
            }
        }
    }
}
