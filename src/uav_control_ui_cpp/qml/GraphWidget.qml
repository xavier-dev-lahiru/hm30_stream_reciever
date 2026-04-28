import QtQuick 2.15
import QtQuick.Controls 2.15

Rectangle {
    id: root
    property string title: "Title"
    property real baseValue: 0.0
    property real currentValue: baseValue
    property string unit: "unit"
    property color lineColor: "#FFF"
    property string statusText: "Safe"
    property color statusColor: "#2ECC71"
    
    // Configurable graph settings
    property int maxPoints: 20
    property int updateInterval: 1000 // ms
    
    property var dataPoints: []
    property real minVal: baseValue * 0.8
    property real maxVal: baseValue * 1.2
    
    property real xOffset: 0

    height: 260
    radius: 12
    color: "#2A2D35"
    border.color: "#333"
    
    Component.onCompleted: {
        // Initialize data array with values around baseValue
        var initial = []
        for (var i = 0; i < maxPoints + 2; i++) {
            initial.push(baseValue + (Math.random() - 0.5) * (baseValue * 0.1))
        }
        dataPoints = initial
        currentValue = dataPoints[dataPoints.length - 2]
        scrollAnim.start()
    }

    Timer {
        id: graphTimer
        interval: updateInterval
        running: true
        repeat: true
        onTriggered: {
            var pts = dataPoints
            pts.shift() // Remove oldest point
            
            // Add new point at the end
            var nextVal = pts[pts.length - 1] + (Math.random() - 0.5) * (baseValue * 0.1)
            if (nextVal > maxVal) nextVal = maxVal
            if (nextVal < minVal) nextVal = minVal
            pts.push(nextVal)
            dataPoints = pts
            
            currentValue = dataPoints[dataPoints.length - 2]
            scrollAnim.restart() // Restart the scrolling animation
            canvas.requestPaint()
        }
    }

    NumberAnimation {
        id: scrollAnim
        target: root
        property: "xOffset"
        from: 0
        to: (width - 30) / (maxPoints - 1) // approximate segment width
        duration: updateInterval
        easing.type: Easing.Linear
    }
    
    onXOffsetChanged: {
        canvas.requestPaint()
    }

    Column {
        anchors.fill: parent
        anchors.margins: 15
        spacing: 10

        Row {
            id: headerRow
            width: parent.width
            spacing: 10
            Rectangle {
                width: 30; height: 30; radius: 6; color: "#1C1E24"
                Text { text: "⚠"; color: "#888"; anchors.centerIn: parent }
            }
            Column {
                Text { text: title; color: "white"; font.pixelSize: 12; font.bold: true }
                Row {
                    spacing: 5
                    Text { text: currentValue.toFixed(3); color: lineColor; font.pixelSize: 20; font.bold: true }
                    Text { text: unit; color: "#888"; font.pixelSize: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 3 }
                    Text { text: "↗"; color: lineColor; font.pixelSize: 12; anchors.bottom: parent.bottom; anchors.bottomMargin: 3 }
                }
            }
            Item { width: parent.width - 150 } // Spacer
            Rectangle {
                width: 40; height: 20; radius: 10; color: "#0D2E1C"; border.color: statusColor; anchors.verticalCenter: parent.verticalCenter
                Text { text: statusText; color: statusColor; font.pixelSize: 10; font.bold: true; anchors.centerIn: parent }
            }
        }

        // Animated Graph
        Canvas {
            id: canvas
            width: parent.width
            height: parent.height - headerRow.height - 10
            onPaint: {
                var ctx = getContext("2d")
                ctx.clearRect(0, 0, width, height)
                
                var pts = dataPoints
                if (!pts || pts.length < 2) return;
                
                var segmentWidth = width / (maxPoints - 1)
                
                // Helper to get Y coordinate mapped to canvas height
                function getY(val) {
                    var range = maxVal - minVal
                    if (range === 0) range = 1
                    var norm = (val - minVal) / range
                    if (norm < 0) norm = 0; 
                    if (norm > 1) norm = 1;
                    return height - (norm * height * 0.8 + height * 0.1) // 10% vertical padding
                }

                // Map points to canvas coordinates
                var points = []
                for (var i = 0; i < pts.length; i++) {
                    var px = (i * segmentWidth) - xOffset - segmentWidth
                    var py = getY(pts[i])
                    points.push({x: px, y: py})
                }

                // Safely extract RGB components for the gradient
                var r = 255, g = 255, b = 255
                var colorStr = lineColor.toString()
                if (colorStr.length >= 7) {
                    r = parseInt(colorStr.slice(1,3), 16)
                    g = parseInt(colorStr.slice(3,5), 16)
                    b = parseInt(colorStr.slice(5,7), 16)
                }

                var gradient = ctx.createLinearGradient(0, 0, 0, height)
                gradient.addColorStop(0, "rgba(" + r + "," + g + "," + b + ", 0.5)")
                gradient.addColorStop(1, "rgba(" + r + "," + g + "," + b + ", 0.0)")

                // Draw Gradient Fill Area
                ctx.beginPath()
                ctx.moveTo(points[0].x, height)
                ctx.lineTo(points[0].x, points[0].y)
                
                for (var j = 0; j < points.length - 1; j++) {
                    var p0 = points[j]
                    var p1 = points[j+1]
                    var cpx1 = p0.x + (p1.x - p0.x) / 2
                    var cpx2 = p1.x - (p1.x - p0.x) / 2
                    ctx.bezierCurveTo(cpx1, p0.y, cpx2, p1.y, p1.x, p1.y)
                }
                
                ctx.lineTo(points[points.length-1].x, height)
                ctx.closePath()
                ctx.fillStyle = gradient
                ctx.fill()

                // Draw Smooth Line
                ctx.beginPath()
                ctx.moveTo(points[0].x, points[0].y)
                for (var k = 0; k < points.length - 1; k++) {
                    var lineP0 = points[k]
                    var lineP1 = points[k+1]
                    var lineCpx1 = lineP0.x + (lineP1.x - lineP0.x) / 2
                    var lineCpx2 = lineP1.x - (lineP1.x - lineP0.x) / 2
                    ctx.bezierCurveTo(lineCpx1, lineP0.y, lineCpx2, lineP1.y, lineP1.x, lineP1.y)
                }
                ctx.strokeStyle = lineColor
                ctx.lineWidth = 2
                ctx.stroke()
            }
        }
    }
}
