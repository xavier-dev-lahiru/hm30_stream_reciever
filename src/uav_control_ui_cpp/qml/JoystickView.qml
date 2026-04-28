import QtQuick 2.15
import QtQuick.Controls 2.15
import CustomControls 1.0

Item {
    id: joystickViewRoot
    focus: true
    Component.onCompleted: forceActiveFocus()
    onVisibleChanged: {
        if (visible) forceActiveFocus()
    }

    // Track keyboard states to allow simultaneous key presses (e.g., Forward + Left)
    property real keyLinear: 0.0
    property real keyAngular: 0.0

    Keys.onPressed: (event) => {
        if (rosBackend.isAuto) return;
        if (event.isAutoRepeat) return;
        let changed = false;
        if (event.key === Qt.Key_Up) { keyLinear = -1.0; changed = true; }
        else if (event.key === Qt.Key_Down) { keyLinear = 1.0; changed = true; }
        else if (event.key === Qt.Key_Left) { keyAngular = -1.0; changed = true; }
        else if (event.key === Qt.Key_Right) { keyAngular = 1.0; changed = true; }
        
        if (changed) {
            rosBackend.updateRightJoystick(keyAngular, keyLinear);
            event.accepted = true;
        }
    }

    Keys.onReleased: (event) => {
        if (rosBackend.isAuto) return;
        if (event.isAutoRepeat) return;
        let changed = false;
        if (event.key === Qt.Key_Up && keyLinear === -1.0) { keyLinear = 0.0; changed = true; }
        else if (event.key === Qt.Key_Down && keyLinear === 1.0) { keyLinear = 0.0; changed = true; }
        else if (event.key === Qt.Key_Left && keyAngular === -1.0) { keyAngular = 0.0; changed = true; }
        else if (event.key === Qt.Key_Right && keyAngular === 1.0) { keyAngular = 0.0; changed = true; }
        
        if (changed) {
            rosBackend.updateRightJoystick(keyAngular, keyLinear);
            event.accepted = true;
        }
    }

    VideoStreamItem {
        id: videoStream
        anchors.fill: parent
        targetBackend: rosBackend
    }

    Item {
        anchors.fill: parent

        TopBar {
            id: topBar
            anchors.top: parent.top
            anchors.left: parent.left
            anchors.right: parent.right
            anchors.margins: 20
            height: 60
            onBackClicked: {
                if (joystickViewRoot.StackView.view) {
                    joystickViewRoot.StackView.view.pop()
                }
            }
        }

        Rectangle {
            id: mapOverlay
            z: 100
            anchors.top: topBar.bottom
            anchors.topMargin: 20
            anchors.right: parent.right
            anchors.rightMargin: 20
            width: 350
            height: 350
            color: "#080C14"
            radius: 12
            border.color: "#1A1F2E"
            border.width: 1
            clip: true
            visible: rosBackend.mappingEnabled

            OccupancyMapView {
                id: occupancyMapView
                anchors.fill: parent
                usingLiveData: rosBackend.usingLiveData
                gridData: rosBackend.gridData
                gridWidth: rosBackend.gridWidth
                gridHeight: rosBackend.gridHeight
                robotX: rosBackend.robotX
                robotY: rosBackend.robotY
                robotAngle: rosBackend.robotAngle
                mapMinX: rosBackend.mapMinX
                mapMinY: rosBackend.mapMinY
                mapMaxX: rosBackend.mapMaxX
                mapMaxY: rosBackend.mapMaxY
            }

            Rectangle {
                width: 140; height: 30; radius: 8; color: Qt.rgba(0,0,0,0.55)
                anchors.top: parent.top; anchors.left: parent.left; anchors.margins: 15
                Text { text: "🗺 2D Occupancy Map"; color: "white"; font.pixelSize: 12; anchors.centerIn: parent }
            }

            Rectangle {
                width: 120; height: 30; radius: 8; color: "#2ECC71"
                anchors.bottom: parent.bottom; anchors.horizontalCenter: parent.horizontalCenter; anchors.margins: 15
                Text { text: "💾 Save Map"; color: "white"; font.pixelSize: 12; font.bold: true; anchors.centerIn: parent }
                MouseArea {
                    anchors.fill: parent
                    onClicked: rosBackend.saveMap()
                }
            }
        }

        Text {
            anchors.centerIn: parent
            text: "Waiting for ROS connection..."
            color: "white"
            font.pixelSize: 16
            font.family: "sans-serif"
            visible: !rosBackend.connected
        }

        BottomControls {
            id: bottomControls
            anchors.bottom: parent.bottom
            anchors.left: parent.left
            anchors.right: parent.right
            height: 350
        }
    }

    // Takeoff Confirmation Popup
    Popup {
        id: takeoffPopup
        x: (parent.width - width) / 2
        y: (parent.height - height) / 2
        width: 400
        height: 200
        modal: true
        focus: true
        closePolicy: Popup.NoAutoClose
        visible: rosBackend.padStatus === "open" || rosBackend.padStatus === "open_and_lifted"
        
        background: Rectangle {
            color: "#1E1E1E"
            radius: 12
            border.color: "#333333"
            border.width: 1
        }

        Column {
            anchors.fill: parent
            anchors.margins: 20
            spacing: 20

            Text {
                text: "Drone Pad Ready"
                color: "white"
                font.pixelSize: 20
                font.bold: true
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Text {
                text: "The drone pad is completely open.\nProceed with takeoff?"
                color: "#AAAAAA"
                font.pixelSize: 14
                horizontalAlignment: Text.AlignHCenter
                anchors.horizontalCenter: parent.horizontalCenter
            }

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
                spacing: 20
                
                // Cancel Button
                Rectangle {
                    width: 140
                    height: 40
                    radius: 8
                    color: "#E74C3C" // Red
                    Text { text: "Cancel Take off"; color: "white"; anchors.centerIn: parent; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            takeoffPopup.close()
                            rosBackend.cancelTakeoff()
                        }
                    }
                }

                // Take off Button
                Rectangle {
                    width: 140
                    height: 40
                    radius: 8
                    color: "#2ECC71" // Green
                    Text { text: "Take off"; color: "white"; anchors.centerIn: parent; font.bold: true }
                    MouseArea {
                        anchors.fill: parent
                        onClicked: {
                            takeoffPopup.close()
                            console.log("Proceeding with Take off")
                            // Add actual takeoff logic here later
                        }
                    }
                }
            }
        }
    }
}
