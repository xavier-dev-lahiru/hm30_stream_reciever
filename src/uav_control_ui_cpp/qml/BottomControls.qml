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
    Row {
        anchors.right: parent.right
        anchors.bottom: parent.bottom
        anchors.rightMargin: 20
        anchors.bottomMargin: 20
        spacing: 20

        Column {
            width: 140
            anchors.verticalCenter: parent.verticalCenter
            spacing: 15

            // Max Speed Slider
            Column {
                spacing: 8
                width: parent.width
                
                Text { 
                    text: "Max Speed: " + rosBackend.maxSpeed.toFixed(1) + "x"
                    color: "#AAAAAA"
                    font.pixelSize: 14
                    horizontalAlignment: Text.AlignRight
                    width: parent.width
                }
                Slider {
                    id: speedSlider
                    width: parent.width
                    from: 0.1
                    to: 5.0
                    stepSize: 0.1
                    value: rosBackend.maxSpeed
                    enabled: !rosBackend.isAuto
                    focusPolicy: Qt.NoFocus
                    onValueChanged: {
                        if (rosBackend.maxSpeed !== value) {
                            rosBackend.maxSpeed = value
                        }
                    }

                    background: Rectangle {
                        x: speedSlider.leftPadding
                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                        implicitWidth: 100
                        implicitHeight: 4
                        width: speedSlider.availableWidth
                        height: implicitHeight
                        radius: 2
                        color: "#333333"

                        Rectangle {
                            width: speedSlider.visualPosition * parent.width
                            height: parent.height
                            color: "#F4D03F" // match active color
                            radius: 2
                        }
                    }

                    handle: Rectangle {
                        x: speedSlider.leftPadding + speedSlider.visualPosition * (speedSlider.availableWidth - width)
                        y: speedSlider.topPadding + speedSlider.availableHeight / 2 - height / 2
                        implicitWidth: 14 // reduced size
                        implicitHeight: 14 // reduced size
                        radius: 7
                        color: speedSlider.pressed ? "#f0f0f0" : "#ffffff"
                        border.color: "#888888"
                        opacity: 0.8 // slight transparency
                    }
                }
            }

            // Velocities
            Column {
                spacing: 5
                width: parent.width
                Text { text: "Linear: " + rosBackend.linearSpeed.toFixed(2) + " m/s"; color: "#AAAAAA"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; width: parent.width }
                Text { text: "Angular: " + rosBackend.angularSpeed.toFixed(2) + " rad/s"; color: "#AAAAAA"; font.pixelSize: 14; horizontalAlignment: Text.AlignRight; width: parent.width }
            }
        }

        Column {
            spacing: 15
            anchors.bottom: parent.bottom

            Row {
                anchors.horizontalCenter: parent.horizontalCenter
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

            Joystick {
                labelUp: "Forward"
                labelDown: "Backward"
                labelLeft: "Left"
                labelRight: "Right"
                isRightSide: true
                enabled: !rosBackend.isAuto
                opacity: enabled ? 1.0 : 0.4
                onPositionChanged: rosBackend.updateRightJoystick(x, y)
            }
        }
    }
}
