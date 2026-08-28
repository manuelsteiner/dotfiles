import Quickshell
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableCalendar ? Quickshell.screens : []
        PanelWindow {
            id: calWindow
            property var modelData
            screen: modelData
            visible: root.calendarVisible
            WlrLayershell.namespace: "qs-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            onVisibleChanged: {
                if (visible) {
                    calWindow._now = new Date()
                    calWindow.viewYear = calWindow._now.getFullYear()
                    calWindow.viewMonth = calWindow._now.getMonth()
                }
            }

            property int viewYear: new Date().getFullYear()
            property int viewMonth: new Date().getMonth()

            property var _now: new Date()
            property bool isCurrentMonth: viewYear === _now.getFullYear() && viewMonth === _now.getMonth()

            function prevMonth() {
                if (viewMonth === 0) { viewMonth = 11; viewYear-- }
                else viewMonth--
            }

            function nextMonth() {
                if (viewMonth === 11) { viewMonth = 0; viewYear++ }
                else viewMonth++
            }

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.calendarVisible = false
            }

            Rectangle {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.topMargin: Config.barGap
                width: 240
                height: calContent.implicitHeight + 32
                radius: 12
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: calContent
                    anchors.fill: parent
                    anchors.margins: 16
                    spacing: 8

                    // Header: nav buttons aligned with grid edges
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 28

                        Rectangle {
                            id: prevBtn
                            anchors.left: parent.left
                            width: 28; height: 28; radius: 6
                            color: prevMA.containsMouse ? Theme.highlightMed : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font { family: Config.fontFamily; pixelSize: 14 }
                                color: prevMA.containsMouse ? Theme.text : Theme.muted
                            }
                            MouseArea {
                                id: prevMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: calWindow.prevMonth()
                            }
                        }

                        Rectangle {
                            anchors.left: prevBtn.right
                            anchors.right: nextBtn.left
                            anchors.leftMargin: 2
                            anchors.rightMargin: 2
                            height: 28; radius: 6
                            color: !calWindow.isCurrentMonth && headerMA.containsMouse ? Theme.highlightMed : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: new Date(calWindow.viewYear, calWindow.viewMonth, 1).toLocaleDateString(Qt.locale(), "MMMM yyyy")
                                font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                color: Theme.text
                            }
                            MouseArea {
                                id: headerMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: {
                                    var now = new Date()
                                    calWindow.viewYear = now.getFullYear()
                                    calWindow.viewMonth = now.getMonth()
                                }
                            }
                        }

                        Rectangle {
                            id: nextBtn
                            anchors.right: parent.right
                            width: 28; height: 28; radius: 6
                            color: nextMA.containsMouse ? Theme.highlightMed : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font { family: Config.fontFamily; pixelSize: 14 }
                                color: nextMA.containsMouse ? Theme.text : Theme.muted
                            }
                            MouseArea {
                                id: nextMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: calWindow.nextMonth()
                            }
                        }
                    }

                    // Calendar grid
                    GridLayout {
                        id: calGrid
                        Layout.alignment: Qt.AlignHCenter
                        columns: 7
                        rowSpacing: 2
                        columnSpacing: 2

                        property int daysInMonth: new Date(calWindow.viewYear, calWindow.viewMonth + 1, 0).getDate()
                        property int daysInPreviousMonth: new Date(calWindow.viewYear, calWindow.viewMonth, 0).getDate()
                        property int firstDay: (new Date(calWindow.viewYear, calWindow.viewMonth, 1).getDay() + 6) % 7
                        property int todayDay: calWindow.isCurrentMonth ? calWindow._now.getDate() : -1

                        Repeater {
                            model: ["Mo", "Tu", "We", "Th", "Fr", "Sa", "Su"]
                            delegate: Text {
                                required property string modelData
                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 20
                                horizontalAlignment: Text.AlignHCenter
                                verticalAlignment: Text.AlignVCenter
                                text: modelData
                                font { family: Config.fontFamily; pixelSize: 11; bold: true }
                                color: Theme.muted
                            }
                        }

                        Repeater {
                            model: 42
                            delegate: Rectangle {
                                required property int index
                                property int dayNum: index - calGrid.firstDay + 1
                                property bool isValid: dayNum >= 1 && dayNum <= calGrid.daysInMonth
                                property bool isToday: isValid && dayNum === calGrid.todayDay
                                property bool isPrev: dayNum < 1
                                property bool isNext: dayNum > calGrid.daysInMonth

                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: 6
                                color: isToday ? (dayMA.containsMouse ? Theme.accentDim : Theme.accent)
                                    : dayMA.containsMouse ? Theme.highlightMed
                                    : "transparent"
                                Behavior on color { ColorAnimation { duration: 80 } }

                                Text {
                                    anchors.centerIn: parent
                                    text: {
                                        if (parent.isPrev)
                                            return calGrid.daysInPreviousMonth + parent.dayNum
                                        if (parent.isNext)
                                            return parent.dayNum - calGrid.daysInMonth
                                        return parent.dayNum
                                    }
                                    font { family: Config.fontFamily; pixelSize: 12 }
                                    color: parent.isToday ? Theme.base
                                        : parent.isValid ? Theme.text
                                        : Theme.muted
                                }

                                MouseArea {
                                    id: dayMA
                                    anchors.fill: parent
                                    hoverEnabled: true
                                    onClicked: {
                                        if (parent.isPrev) calWindow.prevMonth()
                                        else if (parent.isNext) calWindow.nextMonth()
                                    }
                                }
                            }
                        }
                    }
                }
            }
        }
    }
}
