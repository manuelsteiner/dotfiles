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
            visible: root.calendarVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-calendar"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            // D-9 keyboard traversal over the 42-cell day grid.
            property int focusedIndex: -1

            function clampIndex(i) { return Math.max(0, Math.min(41, i)) }

            function activateFocused() {
                if (calWindow.focusedIndex < 0) return
                var dayNum = calWindow.focusedIndex - calGrid.firstDay + 1
                if (dayNum < 1) calWindow.prevMonth()
                else if (dayNum > calGrid.daysInMonth) calWindow.nextMonth()
            }

            onVisibleChanged: {
                if (visible) {
                    calWindow._now = new Date()
                    calWindow.viewYear = calWindow._now.getFullYear()
                    calWindow.viewMonth = calWindow._now.getMonth()
                    calWindow.focusedIndex = calGrid.firstDay + calWindow._now.getDate() - 1
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
                focus: true
                Keys.onEscapePressed: root.calendarVisible = false
                Keys.onUpPressed: calWindow.focusedIndex = calWindow.clampIndex(calWindow.focusedIndex - 7)
                Keys.onDownPressed: calWindow.focusedIndex = calWindow.clampIndex(calWindow.focusedIndex + 7)
                Keys.onLeftPressed: calWindow.focusedIndex = calWindow.clampIndex(calWindow.focusedIndex - 1)
                Keys.onRightPressed: calWindow.focusedIndex = calWindow.clampIndex(calWindow.focusedIndex + 1)
                Keys.onReturnPressed: calWindow.activateFocused()
                Keys.onEnterPressed: calWindow.activateFocused()
            }

            PopoutFrame {
                anchors.top: parent.top
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.topMargin: Config.gap
                width: 240
                height: calContent.implicitHeight + 24

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    id: calContent
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header: nav buttons aligned with grid edges
                    Item {
                        Layout.fillWidth: true
                        implicitHeight: 28

                        Rectangle {
                            id: prevBtn
                            anchors.left: parent.left
                            width: 28; height: 28; radius: 6
                            color: prevMA.containsMouse ? Theme.hover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅁"
                                font { family: Config.fontFamily; pixelSize: 13 }
                                color: prevMA.containsMouse ? Theme.text : Theme.subtle
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
                            color: !calWindow.isCurrentMonth && headerMA.containsMouse ? Theme.hover : "transparent"
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
                            color: nextMA.containsMouse ? Theme.hover : "transparent"
                            Text {
                                anchors.centerIn: parent
                                text: "󰅂"
                                font { family: Config.fontFamily; pixelSize: 13 }
                                color: nextMA.containsMouse ? Theme.text : Theme.subtle
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
                                color: Theme.subtle
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
                                property bool isFocused: index === calWindow.focusedIndex

                                Layout.preferredWidth: 28
                                Layout.preferredHeight: 28
                                radius: Config.radiusCell
                                // Today is an accent edge + accent numeral, not a
                                // filled block (rule 8: no colour inversion).
                                color: !isToday && dayMA.containsMouse ? Theme.hover : "transparent"
                                border.width: isToday || isFocused ? 1 : 0
                                border.color: Theme.accent
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
                                    font { family: Config.fontFamily; pixelSize: 12; features: { "tnum": 1 } }
                                    color: parent.isToday ? Theme.accent
                                        : parent.isValid ? Theme.text
                                        : Theme.subtle
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
