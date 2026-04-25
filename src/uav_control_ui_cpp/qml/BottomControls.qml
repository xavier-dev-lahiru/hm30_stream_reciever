import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root

    // Dark gradient backdrop for better visibility
    Rectangle {
        anchors.fill: parent
        gradient: Gradient {
            GradientStop { position: 0.0; color: "transparent" }
            GradientStop { position: 0.5; color: "#66000000" }
            GradientStop { position: 1.0; color: "#AA000000" }
        }
    }

    // LEFT SIDE
    Column {
        anchors.left: parent.left
        anchors.bottom: parent.bottom
        anchors.leftMargin: 20
        anchors.bottomMargin: 20
        spacing: 20

        Row {
            spacing: 20

            Column {
                spacing: 10
                
                Row {
                    spacing: 15
                    anchors.horizontalCenter: parent.horizontalCenter
                    
                    // Target Button
                    Rectangle {
                        width: 50
                        height: 50
                        radius: 25
                        color: "#1F2023" // Dark bluish/gray
                        Text {
                            text: "⌖"
                            color: "white"
                            font.pixelSize: 24
                            anchors.centerIn: parent
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onPressed: parent.opacity = 0.5
                            onReleased: parent.opacity = 1.0
                            onCanceled: parent.opacity = 1.0
                            onClicked: {
                                leftJoystick.resetCenter()
                                rosBackend.targetAction() 
                            }
                        }
                    }

                    // Home Button
                    Rectangle {
                        width: 50
                        height: 50
                        radius: 25
                        color: "#1F2023" // Dark bluish/gray
                        Text {
                            text: "🏠"
                            color: "white"
                            font.pixelSize: 20
                            anchors.centerIn: parent
                        }
                        MouseArea { 
                            anchors.fill: parent
                            onPressed: parent.opacity = 0.5
                            onReleased: parent.opacity = 1.0
                            onCanceled: parent.opacity = 1.0
                            onClicked: {
                                leftJoystick.resetCenter()
                                rosBackend.gimbalHomeAction() 
                            }
                        }
                    }
                }

                Joystick {
                    id: leftJoystick
                    labelUp: "Up"
                    labelDown: "Down"
                    labelLeft: "Left"
                    labelRight: "Right"
                    isRightSide: false
                    autoCenter: false
                    onPositionChanged: rosBackend.updateLeftJoystick(x, y)
                }
            }

            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "Pan (X): " + rosBackend.panX.toFixed(0); color: "#888"; font.pixelSize: 12 }
                Text { text: "Tilt (Y): " + rosBackend.tiltY.toFixed(0); color: "#888"; font.pixelSize: 12 }
            }
        }
    }

    // RIGHT SIDE
    Column {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 20

        Row {
            anchors.right: parent.right
            spacing: 15

            // Camera Button
            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: "#111" // very dark
                Text {
                    text: "📷"
                    color: "#444"
                    font.pixelSize: 20
                    anchors.centerIn: parent
                }
                MouseArea { anchors.fill: parent; onClicked: rosBackend.cameraAction() }
            }

            // STOP Button
            Rectangle {
                width: 50
                height: 50
                radius: 25
                color: "#E74C3C" // Red
                border.color: "white"
                border.width: 1
                Text {
                    text: "STOP"
                    color: "white"
                    font.pixelSize: 12
                    font.bold: true
                    anchors.centerIn: parent
                }
                MouseArea { anchors.fill: parent; onClicked: rosBackend.stopAction() }
            }
        }

        Row {
            anchors.right: parent.right
            spacing: 20

            Column {
                anchors.verticalCenter: parent.verticalCenter
                Text { text: "Linear: " + rosBackend.linearSpeed.toFixed(2) + " m/s"; color: "#888"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
                Text { text: "Angular: " + rosBackend.angularSpeed.toFixed(2) + " rad/s"; color: "#888"; font.pixelSize: 12; horizontalAlignment: Text.AlignRight }
            }

            Joystick {
                labelUp: "Forward"
                labelDown: "Backward"
                labelLeft: "Left"
                labelRight: "Right"
                isRightSide: true
                onPositionChanged: rosBackend.updateRightJoystick(x, y)
            }
        }
    }
}
