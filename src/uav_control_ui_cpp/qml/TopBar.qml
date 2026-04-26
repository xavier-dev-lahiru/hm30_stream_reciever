import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Item {
    id: root
    
    signal backClicked()
    
    // Define some colors matching the dark theme
    property color bgColor: "#1A1A1A"
    property color activeColor: "#F4D03F" // Yellowish color for Auto
    property color textColor: "#FFFFFF"
    property color disabledTextColor: "#AAAAAA"
    property color buttonBg: "#222222"
    
    // Left controls
    RowLayout {
        anchors.left: parent.left
        anchors.verticalCenter: parent.verticalCenter
        spacing: 15

        // Back Button
        Rectangle {
            width: 40
            height: 40
            radius: 8
            color: buttonBg
            Text {
                anchors.centerIn: parent
                text: "←"
                color: textColor
                font.pixelSize: 18
            }
            MouseArea { anchors.fill: parent; onClicked: root.backClicked() }
        }

        // Return to Start
        Rectangle {
            width: 140
            height: 40
            radius: 8
            color: buttonBg
            Row {
                anchors.centerIn: parent
                spacing: 8
                Text { text: "⚑"; color: textColor; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Return to Start"; color: textColor; font.pixelSize: 14; font.family: "sans-serif"; anchors.verticalCenter: parent.verticalCenter }
            }
            MouseArea { anchors.fill: parent; onClicked: console.log("Return to Start clicked") }
        }

        // Auto / Manual Toggle
        Rectangle {
            width: 180
            height: 40
            radius: 8
            color: buttonBg
            RowLayout {
                anchors.fill: parent
                spacing: 0
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: rosBackend.isAuto ? activeColor : "transparent"
                    radius: 8
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "✨"; color: rosBackend.isAuto ? "#000" : textColor; font.pixelSize: 14 }
                        Text { text: "Auto"; color: rosBackend.isAuto ? "#000" : textColor; font.pixelSize: 14; font.bold: rosBackend.isAuto }
                    }
                    MouseArea { anchors.fill: parent; onClicked: rosBackend.isAuto = true }
                }
                Rectangle {
                    Layout.fillWidth: true
                    Layout.fillHeight: true
                    color: !rosBackend.isAuto ? activeColor : "transparent"
                    radius: 8
                    Row {
                        anchors.centerIn: parent
                        spacing: 5
                        Text { text: "⚙"; color: !rosBackend.isAuto ? "#000" : textColor; font.pixelSize: 14 }
                        Text { text: "Manual"; color: !rosBackend.isAuto ? "#000" : textColor; font.pixelSize: 14; font.bold: !rosBackend.isAuto }
                    }
                    MouseArea { anchors.fill: parent; onClicked: rosBackend.isAuto = false }
                }
            }
        }

        // Launch UAV
        Rectangle {
            width: 140
            height: 40
            radius: 8
            color: buttonBg
            
            // Container for default state
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: rosBackend.padStatus !== "opening" && rosBackend.padStatus !== "closing"
                Text { text: "🚁"; color: textColor; font.pixelSize: 16; anchors.verticalCenter: parent.verticalCenter }
                Text { text: "Launch UAV"; color: textColor; font.pixelSize: 14; font.family: "sans-serif"; anchors.verticalCenter: parent.verticalCenter }
            }
            
            // Container for loading state
            Row {
                anchors.centerIn: parent
                spacing: 8
                visible: rosBackend.padStatus === "opening" || rosBackend.padStatus === "closing"
                BusyIndicator {
                    width: 20
                    height: 20
                    running: parent.visible
                    anchors.verticalCenter: parent.verticalCenter
                }
                Text { 
                    text: rosBackend.padStatus === "opening" ? "Opening Pad..." : "Closing Pad..."
                    color: activeColor
                    font.pixelSize: 12
                    font.family: "sans-serif"
                    anchors.verticalCenter: parent.verticalCenter 
                }
            }

            MouseArea { 
                anchors.fill: parent
                enabled: rosBackend.padStatus !== "opening" && rosBackend.padStatus !== "closing"
                onClicked: rosBackend.launchUAV() 
            }
        }
    }

    // Center Speed
    Column {
        anchors.centerIn: parent
        spacing: -5
        Text {
            text: rosBackend.speed.toString()
            color: textColor
            font.pixelSize: 36
            font.bold: true
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "mph"
            color: disabledTextColor
            font.pixelSize: 12
            anchors.horizontalCenter: parent.horizontalCenter
        }
    }

    // Right controls
    ColumnLayout {
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: 10
        
        // Signal Dots
        Row {
            Layout.alignment: Qt.AlignRight
            spacing: 5
            Rectangle { width: 8; height: 8; radius: 4; color: "#2ECC71" } // Green
            Rectangle { width: 8; height: 8; radius: 4; color: activeColor } // Yellow
            Rectangle { width: 8; height: 8; radius: 4; color: activeColor } // Yellow
            Rectangle { width: 8; height: 8; radius: 4; color: activeColor } // Yellow
        }

        RowLayout {
            spacing: 15
            // Temp
            Rectangle {
                width: 80
                height: 40
                radius: 8
                color: buttonBg
                
                property real disp_temperature: rosBackend.temperature
                Behavior on disp_temperature { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "🌡"; color: disabledTextColor; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Math.round(parent.parent.disp_temperature) + "°C"; color: textColor; font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }
            
            // Battery
            Rectangle {
                width: 80
                height: 40
                radius: 8
                color: buttonBg
                
                property real disp_battery: rosBackend.battery
                Behavior on disp_battery { NumberAnimation { duration: 800; easing.type: Easing.OutCubic } }

                Row {
                    anchors.centerIn: parent
                    spacing: 5
                    Text { text: "🔋"; color: parent.parent.disp_battery > 50 ? "#2ECC71" : (parent.parent.disp_battery > 20 ? "#F39C12" : "#E74C3C"); font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: Math.round(parent.parent.disp_battery) + "%"; color: textColor; font.pixelSize: 14; font.bold: true; anchors.verticalCenter: parent.verticalCenter }
                }
            }

            // Mapping Toggle
            Rectangle {
                width: 120
                height: 40
                radius: 8
                color: buttonBg
                Row {
                    anchors.centerIn: parent
                    spacing: 8
                    Text { text: "🗺"; color: textColor; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    Text { text: "Mapping"; color: textColor; font.pixelSize: 14; anchors.verticalCenter: parent.verticalCenter }
                    // Switch
                    Rectangle {
                        width: 30
                        height: 16
                        radius: 8
                        color: rosBackend.mappingEnabled ? activeColor : "#444"
                        anchors.verticalCenter: parent.verticalCenter
                        Rectangle {
                            width: 12
                            height: 12
                            radius: 6
                            color: "white"
                            anchors.verticalCenter: parent.verticalCenter
                            x: rosBackend.mappingEnabled ? 16 : 2
                            Behavior on x { NumberAnimation { duration: 150 } }
                        }
                        MouseArea {
                            anchors.fill: parent
                            onClicked: rosBackend.mappingEnabled = !rosBackend.mappingEnabled
                        }
                    }
                }
            }
        }
    }
}
