import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

import "dateandtime.js" as DT


ListItem
{
    id: itemcontainer
    property variant myData

    //signal clicked
    //signal pressAndHold
    //signal doubleClicked

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
    property int discnum: 0

    // Formats track number as "03"; prefixes disc as "2-03" when disc > 1.
    function formatTrack(t, d) {
        var n = parseInt(t)
        if (!n || n <= 0) return ""
        var s = n < 10 ? "0" + n : "" + n
        var disc = parseInt(d)
        if (disc && disc > 1) return disc + "-" + s
        return s
    }

    //height: 78
    width: parent.width
    clip: true

    CoverArtList {
        id: thumb
        x: Theme.paddingLarge
        width: itemimg!="" || showCover? parent.height /*- Theme.paddingMedium*/ : 0
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
        text: formatTrack(tracknum, discnum)
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
        anchors.right: parent.right
        anchors.rightMargin: Theme.paddingLarge
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


}
