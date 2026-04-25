import QtQuick 2.15
import QtQuick.Controls 2.15
import QtQuick.Layouts 1.15

Rectangle {
    id: ppeRoot
    width: parent.width
    height: 480
    color: "#1C1E24"
    radius: 12
    clip: true

    RowLayout {
        id: mainRow
        anchors.fill: parent
        anchors.margins: 20
        spacing: 20

        // ── 1. LEFT COLUMN — fixed 260px ──────────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 260
            Layout.maximumWidth: 260
            Layout.fillHeight: true
            spacing: 8

            // Controls row
            RowLayout {
                Layout.fillWidth: true
                spacing: 6

                Rectangle {
                    width: 90; height: 28; radius: 5
                    color: "#2A2D35"; border.color: "#444"
                    Row { anchors.centerIn: parent; spacing: 4
                        Text { text: "All Types"; color: "white"; font.pixelSize: 11 }
                        Text { text: "▼"; color: "#888"; font.pixelSize: 9 }
                    }
                }
                Rectangle {
                    width: 28; height: 28; radius: 5
                    color: "#2A2D35"; border.color: "#444"
                    Text { text: "⛶"; color: "white"; font.pixelSize: 12; anchors.centerIn: parent }
                }
                Item { Layout.fillWidth: true }
                Rectangle {
                    width: 120; height: 28; radius: 5
                    color: "#2A2D35"; border.color: "#444"
                    Row { anchors.centerIn: parent; spacing: 4
                        Text { text: "📄"; font.pixelSize: 11 }
                        Text { text: "Download Report"; color: "white"; font.pixelSize: 11 }
                    }
                }
            }

            // Column headers
            Row {
                spacing: 0
                leftPadding: 8
                Item { width: 44; height: 18; Text { text: "Image"; color: "#666"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
                Item { width: 110; height: 18; Text { text: "Type"; color: "#666"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
                Item { width: 90; height: 18; Text { text: "Recorded at"; color: "#666"; font.pixelSize: 11; anchors.verticalCenter: parent.verticalCenter } }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#333" }

            // Row 1 — selected
            Rectangle {
                Layout.fillWidth: true; height: 52
                color: "#2A2D35"; radius: 4
                Rectangle { width: 3; height: parent.height; radius: 2; color: "#F4D03F" }
                Row {
                    anchors.fill: parent
                    anchors.leftMargin: 10
                    anchors.rightMargin: 6
                    spacing: 8
                    Rectangle {
                        width: 36; height: 36; radius: 4; color: "#111"; clip: true
                        anchors.verticalCenter: parent.verticalCenter
                        Image { anchors.fill: parent; source: "qrc:/assets/images/worker_no_jacket.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Item {
                        width: 100; height: parent.height
                        Text { text: "No Safety Jackets"; color: "white"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter
                        spacing: 1
                        Text { text: "27/03/2025"; color: "#ccc"; font.pixelSize: 10 }
                        Text { text: "09:30 am"; color: "#888"; font.pixelSize: 10 }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#2E3140" }

            // Row 2
            Rectangle {
                Layout.fillWidth: true; height: 52; color: "transparent"; radius: 4
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8
                    Rectangle {
                        width: 36; height: 36; radius: 4; color: "#111"; clip: true; anchors.verticalCenter: parent.verticalCenter
                        Image { anchors.fill: parent; source: "qrc:/assets/images/worker_no_jacket_group.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Item {
                        width: 100; height: parent.height
                        Text { text: "No Safety Jackets"; color: "#ccc"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: "27/03/2025"; color: "#ccc"; font.pixelSize: 10 }
                        Text { text: "09:35 am"; color: "#888"; font.pixelSize: 10 }
                    }
                }
            }

            Rectangle { Layout.fillWidth: true; height: 1; color: "#2E3140" }

            // Row 3
            Rectangle {
                Layout.fillWidth: true; height: 52; color: "transparent"; radius: 4
                Row {
                    anchors.fill: parent; anchors.leftMargin: 10; anchors.rightMargin: 6; spacing: 8
                    Rectangle {
                        width: 36; height: 36; radius: 4; color: "#111"; clip: true; anchors.verticalCenter: parent.verticalCenter
                        Image { anchors.fill: parent; source: "qrc:/assets/images/worker_no_helmet.png"; fillMode: Image.PreserveAspectCrop }
                    }
                    Item {
                        width: 100; height: parent.height
                        Text { text: "No Safety Helmets"; color: "#ccc"; font.pixelSize: 12; anchors.verticalCenter: parent.verticalCenter; elide: Text.ElideRight; width: parent.width }
                    }
                    Column {
                        anchors.verticalCenter: parent.verticalCenter; spacing: 1
                        Text { text: "27/03/2025"; color: "#ccc"; font.pixelSize: 10 }
                        Text { text: "09:40 am"; color: "#888"; font.pixelSize: 10 }
                    }
                }
            }

            Item { Layout.fillHeight: true }
        }

        // Divider
        Rectangle { width: 1; Layout.fillHeight: true; color: "#333" }

        // ── 2. CENTER COLUMN — fixed 200px ───────────────────────────────
        ColumnLayout {
            Layout.preferredWidth: 200
            Layout.maximumWidth: 200
            Layout.fillHeight: true
            spacing: 10

            Rectangle {
                Layout.fillWidth: true
                height: 200
                radius: 8; color: "#111"; clip: true
                Image {
                    anchors.fill: parent
                    source: "qrc:/assets/images/worker_no_jacket.png"
                    fillMode: Image.PreserveAspectCrop
                }
            }

            Row {
                spacing: 8
                Layout.fillWidth: true
                Text {
                    text: "No safety jackets"
                    color: "white"; font.pixelSize: 14; font.bold: true
                    width: 120
                    wrapMode: Text.WordWrap
                }
                Rectangle {
                    width: 56; height: 22; radius: 4; color: "#E67E22"
                    anchors.verticalCenter: parent.verticalCenter
                    Text { text: "Medium"; color: "white"; font.pixelSize: 11; font.bold: true; anchors.centerIn: parent }
                }
            }

            Column {
                spacing: 2
                Text { text: "27/03/2025"; color: "#ccc"; font.pixelSize: 12 }
                Text { text: "09:37 am";   color: "#888"; font.pixelSize: 12 }
            }

            Item { Layout.fillHeight: true }

            Rectangle {
                width: 100; height: 30; radius: 6
                color: "#2A2D35"; border.color: "#444"
                Row { anchors.centerIn: parent; spacing: 5
                    Text { text: "📝"; font.pixelSize: 12 }
                    Text { text: "Add Note"; color: "white"; font.pixelSize: 12 }
                }
            }
        }

        // Divider
        Rectangle { width: 1; Layout.fillHeight: true; color: "#333" }

        // ── 3. RIGHT COLUMN — fixed width ──────────────────────────────
        RowLayout {
            Layout.preferredWidth: 340
            Layout.maximumWidth: 340
            Layout.fillHeight: true
            spacing: 20

            // Left stats sub-column
            ColumnLayout {
                Layout.preferredWidth: 155
                Layout.maximumWidth: 155
                Layout.fillHeight: true
                spacing: 18

                Repeater {
                    model: [
                        { icon: "👷", label: "Persons",      value: "35 Scanned",    sub: "in total",       color: "white"   },
                        { icon: "🦺", label: "Safety Vests", value: "03 Detections", sub: "95% Compliant",  color: "#E74C3C" },
                        { icon: "🧤", label: "Gloves",       value: "02",            sub: "94% Compliant",  color: "#E74C3C" },
                        { icon: "🛡", label: "Face Guards",  value: "08",            sub: "88% Compliant",  color: "#E74C3C" }
                    ]
                    RowLayout {
                        spacing: 10
                        Text { text: modelData.icon; font.pixelSize: 24 }
                        Column {
                            spacing: 1
                            Text { text: modelData.label; color: "#888"; font.pixelSize: 11 }
                            Text { text: modelData.value; color: modelData.color; font.pixelSize: 14; font.bold: true }
                            Text { text: modelData.sub;   color: "#888"; font.pixelSize: 11 }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }

            // Right stats sub-column
            ColumnLayout {
                Layout.preferredWidth: 155
                Layout.maximumWidth: 155
                Layout.fillHeight: true
                spacing: 18

                Repeater {
                    model: [
                        { icon: "⛑", label: "Helmets", value: "02 Detections",  sub: "94% Compliant",  color: "#E74C3C" },
                        { icon: "🥾", label: "Boots",   value: "No Detections",  sub: "100% Compliant", color: "#2ECC71" },
                        { icon: "🥽", label: "Glasses",  value: "No Glasses 14", sub: "60% Compliant",  color: "#E74C3C" }
                    ]
                    RowLayout {
                        spacing: 10
                        Text { text: modelData.icon; font.pixelSize: 24 }
                        Column {
                            spacing: 1
                            Text { text: modelData.label; color: "#888"; font.pixelSize: 11 }
                            Text { text: modelData.value; color: modelData.color; font.pixelSize: 14; font.bold: true }
                            Text { text: modelData.sub;   color: "#888"; font.pixelSize: 11 }
                        }
                    }
                }

                Item { Layout.fillHeight: true }
            }
        }

        // Absorbs remaining space → keeps all columns left-aligned
        Item { Layout.fillWidth: true }
    }
}
