import QtQuick 2.0
import Sailfish.Silica 1.0
import FlowPlayer 1.0

import "dateandtime.js" as DT


Item
{
    id: itemcontainer
    property variant myData

    signal clicked
    signal pressAndHold
    signal doubleClicked

    property string name
    property string desc
    property string time
    property string img
    property string count
    property int cindex
    property string isplaying
    property bool isSel
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

    width: parent.width
    clip: true

    BorderImage
    {
        id: background
        anchors.fill: itemcontainer
        anchors.bottomMargin: itemcontainer.height==71 ? 1 : 0
        visible:  mouseArea.pressed || isSel
        source: "image://theme/meegotouch-list-fullwidth" + (theme.inverted ? "-inverted" : "") + "-background-pressed-center"
    }

    Image {
        height: 54
        width: img!="" ? 54 : 0
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 10
        source: getCover("qrc:/images/nocover62.jpg")
        smooth: true
    }

    Image {
        id: coverImg
        height: 54
        width: img!="" ? 54 : 0
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 10
        source: getCover(img)
        smooth: true
        states: [
            State {
                name: 'loaded'; when: coverImg.status==Image.Ready
                PropertyChanges { target: coverImg; scale: 1; opacity: 1; }
            },
            State {
                name: 'loading'; when: coverImg.status!=Image.Ready
                PropertyChanges { target: coverImg; scale: 1; opacity: 0; }
            }
        ]
        transitions: Transition {
            NumberAnimation { properties: "scale, opacity"; easing.type: Easing.InOutQuad; duration: 1000 }
        }

    }

    Text
    {
        id: trackLabel
        text: formatTrack(tracknum, discnum)
        anchors.top: parent.top
        anchors.topMargin: 8
        anchors.left: parent.left
        anchors.leftMargin: 68
        width: 24
        horizontalAlignment: Text.AlignRight
        font.pixelSize: 22
        elide: Text.ElideRight
        color: isplaying == "true" ? themeColor : (currentTheme==="blanco"? "#8c8e8c" : "white")
    }

    Text
    {
        text: name
        anchors.top: parent.top
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.topMargin: 8
        anchors.leftMargin: 96
        anchors.rightMargin: 10
        width: itemcontainer.width -106
        font.bold: currentTheme==="blanco"
        font.pixelSize: 22
        elide: Text.ElideRight
        color: isplaying == "true" ? themeColor : "white"
    }

    Text
    {
        text: desc
        anchors.top: parent.top
        anchors.left: parent.left
        elide: Text.ElideRight
        anchors.topMargin: 40
        anchors.leftMargin: 96
        anchors.rightMargin: 10
        width: itemcontainer.width -136
        font.pixelSize: 18
        color: isplaying == "true" ? themeColor : (currentTheme==="blanco"? "#8c8e8c" : "white")
    }

    Text
    {
        text: time
        anchors.top: parent.top
        anchors.topMargin: 40
        horizontalAlignment: Text.AlignRight
        width: itemcontainer.width -10
        font.pixelSize: 18
        color: isplaying == "true" ? themeColor : (currentTheme==="blanco"? "#8c8e8c" : "white")
    }


    MouseArea
    {
        id: mouseArea
        anchors.fill: itemcontainer
        onClicked: itemcontainer.clicked()
        onPressAndHold: itemcontainer.pressAndHold()
    }
}
