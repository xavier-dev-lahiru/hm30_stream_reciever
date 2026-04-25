import QtQuick 2.15

Item {
    id: root
    width: 200
    height: 200

    property string labelUp: "Up"
    property string labelDown: "Down"
    property string labelLeft: "Left"
    property string labelRight: "Right"
    property bool isRightSide: false
    property bool autoCenter: true

    signal positionChanged(real x, real y)

    function resetCenter() {
        stick.x = (base.width - stick.width) / 2;
        stick.y = (base.height - stick.height) / 2;
        root.positionChanged(0, 0);
    }

    // Main ring
    Rectangle {
        id: base
        anchors.fill: parent
        radius: width / 2
        color: "transparent"
        border.color: "#333333"
        border.width: 2

        // Labels
        Text {
            text: "↑ " + labelUp
            color: "#666"
            font.pixelSize: 12
            anchors.top: parent.top
            anchors.topMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "↓ " + labelDown
            color: "#666"
            font.pixelSize: 12
            anchors.bottom: parent.bottom
            anchors.bottomMargin: 10
            anchors.horizontalCenter: parent.horizontalCenter
        }
        Text {
            text: "↺ " + labelLeft
            color: "#666"
            font.pixelSize: 12
            anchors.left: parent.left
            anchors.leftMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            rotation: -90
        }
        Text {
            text: "↻ " + labelRight
            color: "#666"
            font.pixelSize: 12
            anchors.right: parent.right
            anchors.rightMargin: 10
            anchors.verticalCenter: parent.verticalCenter
            rotation: 90
        }

        // Draggable stick
        Rectangle {
            id: stick
            width: 60
            height: 60
            radius: 30
            color: isRightSide ? "#222" : "white" // Left is white, right is dark with dot
            
            // Inner dot for right stick
            Rectangle {
                width: 20
                height: 20
                radius: 10
                color: isRightSide ? "#444" : "black"
                anchors.centerIn: parent
                visible: true
            }

            x: (base.width - width) / 2
            y: (base.height - height) / 2

            MouseArea {
                id: mouseArea
                anchors.fill: parent
                drag.target: stick
                drag.axis: Drag.XAndYAxis

                onPositionChanged: {
                    var dx = stick.x + stick.width/2 - base.width/2;
                    var dy = stick.y + stick.height/2 - base.height/2;
                    var distance = Math.sqrt(dx*dx + dy*dy);
                    var maxDist = base.width/2 - stick.width/2;

                    if (distance > maxDist) {
                        var angle = Math.atan2(dy, dx);
                        stick.x = base.width/2 + Math.cos(angle) * maxDist - stick.width/2;
                        stick.y = base.height/2 + Math.sin(angle) * maxDist - stick.height/2;
                    }
                    
                    // Normalize -1 to 1
                    var nx = (stick.x + stick.width/2 - base.width/2) / maxDist;
                    var ny = (stick.y + stick.height/2 - base.height/2) / maxDist;
                    root.positionChanged(nx, ny);
                }

                onReleased: {
                    if (autoCenter) {
                        resetCenter();
                    }
                }
            }
            
            Behavior on x { NumberAnimation { duration: mouseArea.pressed ? 0 : 100 } }
            Behavior on y { NumberAnimation { duration: mouseArea.pressed ? 0 : 100 } }
        }
    }
}
