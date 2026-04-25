import QtQuick 2.15
import QtQuick.Controls 2.15
import CustomControls 1.0

Item {
    id: joystickViewRoot

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
