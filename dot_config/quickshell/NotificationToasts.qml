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
            visible: root.toastNotifications.length > 0
            WlrLayershell.namespace: "qs-notifications"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            anchors { top: true; right: true }
            implicitWidth: 380
            implicitHeight: toastColumn.height + 20
            color: "transparent"

            Column {
                id: toastColumn
                anchors.top: parent.top
                anchors.right: parent.right
                anchors.topMargin: 10
                anchors.rightMargin: 10
                width: 360
                height: childrenRect.height
                spacing: 8

                // D-8: beyond 3 toasts, stop laying out full-height cards down
                // the screen — show the newest in full and collapse the rest
                // into a small stacked-offset "+N more" indicator.
                readonly property int fullCount: root.toastNotifications.length > 3 ? 1 : root.toastNotifications.length

                Repeater {
                    model: root.toastNotifications.slice(0, toastColumn.fullCount)

                    delegate: PopoutFrame {
                        id: toastCard
                        required property var modelData
                        width: toastColumn.width
                        implicitHeight: toastContent.implicitHeight + 24
                        border.color: toastCard.modelData.urgency === NotificationUrgency.Critical
                            ? Theme.urgentColor : Theme.edge

                        // F-1: normal-urgency toasts auto-expire after 6s;
                        // critical toasts never auto-expire (and survive DND,
                        // handled in shell.qml). Low-urgency notifications
                        // never reach the toast layer at all.
                        property real progress: 1
                        NumberAnimation on progress {
                            running: toastCard.modelData.urgency !== NotificationUrgency.Critical
                            from: 1; to: 0; duration: 6000
                        }

                        Timer {
                            interval: 6000
                            running: toastCard.modelData.urgency !== NotificationUrgency.Critical
                            onTriggered: root.expireToast(toastCard.modelData)
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.dismissNotification(toastCard.modelData)
                        }

                        ColumnLayout {
                            id: toastContent
                            anchors.fill: parent
                            anchors.margins: 12
                            spacing: 4

                            RowLayout {
                                Layout.fillWidth: true
                                spacing: 8
                                Image {
                                    visible: (toastCard.modelData.appIcon ?? "") !== ""
                                    source: toastCard.modelData.appIcon ?? ""
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }
                                Text {
                                    text: toastCard.modelData.appName || "Notification"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: Theme.subtle
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: toastCard.modelData.urgency === NotificationUrgency.Critical
                                    width: 6; height: 6; radius: 3
                                    color: Theme.red
                                }
                                Rectangle {
                                    width: 20; height: 20; radius: Config.radiusCell
                                    color: closeMA.containsMouse ? Theme.hover : "transparent"
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
                                        onClicked: root.dismissNotification(toastCard.modelData)
                                    }
                                }
                            }

                            Text {
                                visible: (toastCard.modelData.summary ?? "") !== ""
                                text: toastCard.modelData.summary ?? ""
                                font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                color: Theme.text
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: (toastCard.modelData.body ?? "") !== ""
                                text: toastCard.modelData.body ?? ""
                                font { family: Config.fontFamily; pixelSize: 12 }
                                color: Theme.subtle
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            RowLayout {
                                visible: (toastCard.modelData.actions ?? []).length > 0
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                Repeater {
                                    model: toastCard.modelData.actions ?? []
                                    delegate: Rectangle {
                                        required property var modelData
                                        Layout.fillWidth: true
                                        height: 26; radius: Config.radiusCell
                                        color: actionArea.containsMouse ? Theme.hover : Theme.divider
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            anchors.centerIn: parent
                                            text: modelData.text ?? ""
                                            font { family: Config.fontFamily; pixelSize: 11 }
                                            color: actionArea.containsMouse ? Theme.text : Theme.subtle
                                        }
                                        MouseArea {
                                            id: actionArea
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            onClicked: modelData.invoke()
                                        }
                                    }
                                }
                            }
                        }

                        // Normal-urgency countdown hairline: shrinks from full
                        // width to 0 over the 6s auto-expire window. Inset
                        // from both edges by the card's own corner radius so
                        // it sits on the flat part of the bottom edge instead
                        // of cutting straight across the rounded corners.
                        Rectangle {
                            visible: Config.toastProgressHairline
                                && toastCard.modelData.urgency !== NotificationUrgency.Critical
                            anchors.left: parent.left
                            anchors.leftMargin: Config.radiusPopout
                            anchors.bottom: parent.bottom
                            anchors.bottomMargin: 3
                            height: 2
                            radius: 1
                            width: Math.max(0, (parent.width - Config.radiusPopout * 2) * toastCard.progress)
                            color: Theme.subtle
                        }
                    }
                }

                // Overflow indicator once more than 3 toasts are live.
                Item {
                    id: peekStack
                    visible: root.toastNotifications.length > 3
                    width: toastColumn.width
                    height: 40
                    readonly property int extraCount: Math.max(0, root.toastNotifications.length - toastColumn.fullCount)

                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 10
                        width: parent.width - 24
                        height: 28
                        radius: Config.radiusIsland
                        color: Theme.elev2
                        border.width: 1
                        border.color: Theme.edge
                        opacity: 0.5
                    }
                    Rectangle {
                        anchors.horizontalCenter: parent.horizontalCenter
                        anchors.top: parent.top
                        anchors.topMargin: 5
                        width: parent.width - 12
                        height: 28
                        radius: Config.radiusIsland
                        color: Theme.elev2
                        border.width: 1
                        border.color: Theme.edge
                        opacity: 0.75
                    }
                    Rectangle {
                        anchors.top: parent.top
                        width: parent.width
                        height: 28
                        radius: Config.radiusIsland
                        color: Theme.elev2
                        border.width: 1
                        border.color: Theme.edge

                        Text {
                            anchors.centerIn: parent
                            text: "+" + peekStack.extraCount + " more"
                            font { family: Config.fontFamily; pixelSize: 11; weight: Font.Medium; features: { "tnum": 1 } }
                            color: Theme.subtle
                        }

                        MouseArea {
                            anchors.fill: parent
                            onClicked: root.toggleNotifPanel()
                        }
                    }
                }
            }
        }
    }
}
