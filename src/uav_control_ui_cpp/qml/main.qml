import QtQuick 2.15
import QtQuick.Window 2.15
import QtQuick.Controls 2.15
import CustomControls 1.0

Window {
    width: 1280
    height: 720
    visible: true
    title: qsTr("UAV Control UI")
    color: "#080808"

    StackView {
        id: stackView
        anchors.fill: parent
        initialItem: "Dashboard.qml"
    }

    onWidthChanged: console.log("Width changed:", width)
}
