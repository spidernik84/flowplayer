import QtQuick 2.0
import Sailfish.Silica 1.0

Item {
    id: header

    property alias title: headerText.text
    property alias description: descText.text
    // Keep the title clear of the display notch, like Silica's PageHeader.
    // Disable for headers that are not at the top of the page.
    property bool avoidCutout: true

    property Item _page
    readonly property real _cutoutMargin: (avoidCutout && _page && _page.orientation === Orientation.Portrait)
                                          ? Screen.topCutout.height : 0

    Component.onCompleted: {
        var p = parent
        while (p && !p.hasOwnProperty("__silica_page"))
            p = p.parent
        _page = p
    }

    height: col1.height + Theme.paddingLarge*2 + _cutoutMargin
    width: parent.width

    Column {
        id: col1
        width: parent.width
        anchors.topMargin: Theme.paddingLarge
        anchors.verticalCenter: parent.verticalCenter
        anchors.verticalCenterOffset: header._cutoutMargin / 2

        Label {
            id: headerText
            width: parent.width -Theme.paddingLarge*2
            //truncationMode: TruncationMode.Fade
            horizontalAlignment: Text.AlignRight
            color: Theme.highlightColor
            //anchors.top: parent.top
            //anchors.topMargin: descText.text==="" ? Theme.paddingLarge*1.5 : Theme.paddingMedium
            wrapMode: Text.WrapAtWordBoundaryOrAnywhere
            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingLarge
            font {
                pixelSize: /*lineCount==1?*/ Theme.fontSizeLarge /*: Theme.fontSizeMedium*/
                family: Theme.fontFamilyHeading
            }
        }

        Label {
            id: descText
            //anchors.top: headerText.bottom
            color: Theme.secondaryColor
            width: parent.width -Theme.paddingLarge*2
            horizontalAlignment: Text.AlignRight
            font.pixelSize: Theme.fontSizeExtraSmall
            anchors.right: parent.right
            anchors.rightMargin: Theme.paddingLarge
            truncationMode: TruncationMode.Fade
            visible: text!=""
        }

    }

}
