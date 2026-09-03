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
            visible: root.activeNotifications.length > 0
            WlrLayershell.namespace: "qs-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            implicitWidth: 380
            implicitHeight: notifList.contentHeight + 20
            color: "transparent"

            ListView {
                id: notifList
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: 360
                spacing: 8
                interactive: false
                model: root.activeNotifications

                delegate: Rectangle {
                        required property var modelData
                        required property int index
                        width: notifList.width
                        implicitHeight: notifContent.implicitHeight + 24
                        radius: 10
                        color: Theme.surface
                        border.color: Theme.overlay
                        border.width: 1

                        Timer {
                            interval: 6000
                            running: true
                            onTriggered: root.expireToast(modelData)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.dismissNotification(modelData)
                        }

                        ColumnLayout {
                            id: notifContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Image {
                                    visible: (modelData.appIcon ?? "") !== ""
                                    source: modelData.appIcon ?? ""
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }
                                Text {
                                    text: modelData.appName || "Notification"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: Theme.muted
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: modelData.urgency === NotificationUrgency.Critical
                                    width: 6; height: 6; radius: 3
                                    color: Theme.red
                                }
                                Rectangle {
                                    width: 20; height: 20; radius: 4
                                    color: closeMA.containsMouse ? Theme.highlightMed : "transparent"
                                    Text {
                                        anchors.centerIn: parent
                                        text: "󰅖"
                                        font.family: Config.fontFamily
                                        font.pixelSize: 12
                                        color: closeMA.containsMouse ? Theme.red : Theme.subtle
                                    }
                                    MouseArea {
                                        id: closeMA
                                        anchors.fill: parent
                                        hoverEnabled: true
                                        onClicked: root.dismissNotification(modelData)
                                    }
                                }
                            }

                            Text {
                                visible: (modelData.summary ?? "") !== ""
                                text: modelData.summary ?? ""
                                font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                color: Theme.text
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: (modelData.body ?? "") !== ""
                                text: modelData.body ?? ""
                                font { family: Config.fontFamily; pixelSize: 12 }
                                color: Theme.subtle
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                visible: (modelData.actions ?? []).length > 0
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                Repeater {
                                    model: modelData.actions ?? []
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 26; radius: 4
                                        color: actMA.containsMouse ? Theme.highlightMed : Theme.overlay
                                        Behavior on color { ColorAnimation { duration: 60 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.text ?? ""
                                            font { family: Config.fontFamily; pixelSize: 11 }
                                            color: actMA.containsMouse ? Theme.text : Theme.subtle
                                        }
                                        MouseArea {
                                            id: actMA
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
