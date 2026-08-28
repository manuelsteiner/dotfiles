import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableNotifications ? Quickshell.screens : []
        PanelWindow {
            property var modelData
            screen: modelData
            visible: root.notifPanelVisible
            WlrLayershell.namespace: "qs-notifpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap - 8
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.notifPanelVisible = false
            }

            Rectangle {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 8
                anchors.bottomMargin: Config.barGap
                width: Config.notifPanelWidth
                height: Config.notifPanelHeight
                radius: 12
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2
                clip: true

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Rectangle {
                            visible: root.storedNotifications.length > 0
                            width: Math.max(20, countText.implicitWidth + 8)
                            height: 20; radius: 10
                            color: Theme.love

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.storedNotifications.length.toString()
                                font { family: Config.fontFamily; pixelSize: 10; bold: true }
                                color: Theme.base
                            }
                        }

                        Text {
                            text: "Notifications"
                            font { family: Config.fontFamily; pixelSize: 14; bold: true }
                            color: Theme.text
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.storedNotifications.length > 0
                            width: clearRow.implicitWidth + 12
                            height: 22; radius: 4
                            color: clearAllMA.containsMouse ? Theme.highlightMed : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                id: clearRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰅖"
                                    font.family: Config.fontFamily
                                    font.pixelSize: 11
                                    color: clearAllMA.containsMouse ? Theme.love : Theme.muted
                                }
                                Text {
                                    text: "Clear all"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: clearAllMA.containsMouse ? Theme.text : Theme.muted
                                }
                            }

                            MouseArea {
                                id: clearAllMA
                                anchors.fill: parent
                                hoverEnabled: true
                                onClicked: root.clearAllNotifications()
                            }
                        }
                    }

                    // Separator
                    Rectangle {
                        Layout.fillWidth: true
                        height: 1
                        color: Theme.highlightMed
                    }

                    // Empty state
                    Item {
                        visible: root.storedNotifications.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: "No notifications"
                            font { family: Config.fontFamily; pixelSize: 13 }
                            color: Theme.muted
                        }
                    }

                    // Scrollable notification list
                    Flickable {
                        visible: root.storedNotifications.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true
                        contentHeight: storedCol.implicitHeight
                        clip: true
                        boundsBehavior: Flickable.StopAtBounds

                        ColumnLayout {
                            id: storedCol
                            width: parent.width
                            spacing: 6

                            Repeater {
                                model: root.storedNotifications

                                delegate: Rectangle {
                                    id: storedDelegate
                                    required property var modelData
                                    required property int index
                                    Layout.fillWidth: true
                                    implicitHeight: storedContent.implicitHeight + 20
                                    radius: 8
                                    color: Theme.overlay

                                    ColumnLayout {
                                        id: storedContent
                                        anchors.fill: parent
                                        anchors.margins: 10
                                        spacing: 3

                                        RowLayout {
                                            Layout.fillWidth: true
                                            spacing: 6

                                            Image {
                                                visible: (storedDelegate.modelData.appIcon ?? "") !== ""
                                                source: storedDelegate.modelData.appIcon ?? ""
                                                Layout.preferredWidth: 14
                                                Layout.preferredHeight: 14
                                                sourceSize.width: 14
                                                sourceSize.height: 14
                                            }

                                            Text {
                                                text: storedDelegate.modelData.appName || "Notification"
                                                font { family: Config.fontFamily; pixelSize: 10 }
                                                color: Theme.muted
                                                Layout.fillWidth: true
                                                elide: Text.ElideRight
                                            }

                                            Rectangle {
                                                visible: storedDelegate.modelData.urgency === NotificationUrgency.Critical
                                                width: 6; height: 6; radius: 3
                                                color: Theme.love
                                            }

                                            Rectangle {
                                                visible: storedDelegate.modelData.urgency === NotificationUrgency.Low
                                                width: 6; height: 6; radius: 3
                                                color: Theme.foam
                                            }

                                            Rectangle {
                                                width: 18; height: 18; radius: 4
                                                color: closeHover.hovered ? Theme.highlightMed : "transparent"

                                                Text {
                                                    anchors.centerIn: parent
                                                    text: "󰅖"
                                                    font.family: Config.fontFamily
                                                    font.pixelSize: 11
                                                    color: closeHover.hovered ? Theme.love : Theme.subtle
                                                }

                                                MouseArea {
                                                    id: closeHover
                                                    anchors.fill: parent
                                                    hoverEnabled: true
                                                    property bool hovered: containsMouse
                                                    onClicked: root.dismissStoredNotification(storedDelegate.modelData)
                                                }
                                            }
                                        }

                                        Text {
                                            visible: (storedDelegate.modelData.summary ?? "") !== ""
                                            text: storedDelegate.modelData.summary ?? ""
                                            font { family: Config.fontFamily; pixelSize: 12; bold: true }
                                            color: Theme.text
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        Text {
                                            visible: (storedDelegate.modelData.body ?? "") !== ""
                                            text: storedDelegate.modelData.body ?? ""
                                            font { family: Config.fontFamily; pixelSize: 11 }
                                            color: Theme.subtle
                                            Layout.fillWidth: true
                                            wrapMode: Text.WordWrap
                                            maximumLineCount: 2
                                            elide: Text.ElideRight
                                        }

                                        RowLayout {
                                            visible: (storedDelegate.modelData.actions ?? []).length > 0
                                            Layout.fillWidth: true
                                            Layout.topMargin: 2
                                            spacing: 6
                                            Repeater {
                                                model: storedDelegate.modelData.actions ?? []
                                                delegate: Rectangle {
                                                    required property var modelData
                                                    Layout.fillWidth: true
                                                    height: 24; radius: 4
                                                    color: actionHover.containsMouse ? Theme.highlightMed : Qt.rgba(Theme.highlightMed.r, Theme.highlightMed.g, Theme.highlightMed.b, 0.4)
                                                    Behavior on color { ColorAnimation { duration: 60 } }
                                                    Text {
                                                        anchors.centerIn: parent
                                                        text: modelData.text ?? ""
                                                        font { family: Config.fontFamily; pixelSize: 10 }
                                                        color: actionHover.containsMouse ? Theme.text : Theme.subtle
                                                    }
                                                    MouseArea {
                                                        id: actionHover
                                                        anchors.fill: parent
                                                        hoverEnabled: true
                                                        onClicked: modelData.invoke()
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
            }
        }
    }
}
