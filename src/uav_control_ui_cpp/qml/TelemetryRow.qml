import QtQuick 2.15
import QtQuick.Layouts 1.15

RowLayout {
    property string icon: ""
    property string label: ""
    property string subLabel: ""
    property string val1: ""
    property string val2: ""
    property color color1: "white"
    property color color2: "#888"

    width: parent.width
    spacing: 15

    Text { text: icon; font.pixelSize: 16; Layout.alignment: Qt.AlignVCenter }
    Column {
        Layout.fillWidth: true
        Text { text: label; color: "white"; font.pixelSize: 14 }
        Text { text: subLabel; color: "#888"; font.pixelSize: 10; visible: subLabel !== "" }
    }
    ColumnLayout {
        Layout.alignment: Qt.AlignRight
        spacing: 0
        Text { Layout.alignment: Qt.AlignRight; text: val1; color: color1; font.pixelSize: 14; font.bold: true }
        Text { Layout.alignment: Qt.AlignRight; text: val2; color: color2; font.pixelSize: 12; visible: val2 !== "" }
    }
}
