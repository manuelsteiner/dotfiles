import Quickshell
import Quickshell.Wayland
import Quickshell.Hyprland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableNotifications ? Quickshell.screens : []
        PanelWindow {
            id: toastWindow
            property var modelData
            screen: modelData
            // "focused": each toast is pinned to whichever monitor was
            // focused at the moment it arrived (toastScreen, snapshotted
            // once in shell.qml) — not re-evaluated live against the
            // *current* focused monitor, which would otherwise relocate an
            // already-visible toast to wherever you move focus next.
            readonly property var relevantToasts: Config.toastMonitorMode === "focused"
                ? root.toastNotifications.filter(n => n.toastScreen === toastWindow.modelData?.name)
                : root.toastNotifications
            visible: relevantToasts.length > 0
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
                readonly property int fullCount: toastWindow.relevantToasts.length > 3 ? 1 : toastWindow.relevantToasts.length

                Repeater {
                    // Index-based lookup against the live array, not a plain
                    // object-array model — passing JS objects through a
                    // Repeater's array model boxes them, so `modelData` stops
                    // being reference-equal to the array's own entries and
                    // every `filter(n => n !== entry)` dismiss/expire call
                    // silently no-ops (same failure mode NotificationPanel.qml
                    // already hit and fixed the same way).
                    model: toastColumn.fullCount

                    delegate: PopoutFrame {
                        id: toastCard
                        required property int index
                        readonly property var modelData: toastWindow.relevantToasts[index]
                        readonly property bool isCritical: toastCard.modelData?.urgency === NotificationUrgency.Critical
                        // Local to this screen — drives the close-button
                        // reveal here only, not the pause (see hoveredToastIds
                        // below).
                        readonly property bool cardHovered: cardHover.hovered
                        // Toasts render once per monitor (independent
                        // PanelWindow instances for the same notification),
                        // so pausing only needs to check "is *any* copy of
                        // this notification hovered anywhere" — otherwise the
                        // copy on the screen you're not touching just expires
                        // on schedule regardless, which looks like hovering
                        // does nothing even though the one you're actually
                        // hovering paused correctly.
                        readonly property bool anyScreenHovered: root.hoveredToastIds.indexOf(toastCard.modelData?.id) !== -1
                        width: toastColumn.width
                        implicitHeight: toastContent.implicitHeight + 24
                        border.color: toastCard.isCritical ? Theme.urgentColor : Theme.edge

                        // F-1: normal-urgency toasts auto-expire after 6s;
                        // critical toasts never auto-expire (and survive DND,
                        // handled in shell.qml). Low-urgency notifications
                        // never reach the toast layer at all. `progress` is
                        // the single source of truth for both the visual
                        // countdown and the actual expiry. Driven by a manual
                        // 50ms tick rather than a `NumberAnimation` so the
                        // remaining time lives in a plain property — hovering
                        // just stops the Timer, no separate pause/resume
                        // semantics to reason about.
                        readonly property int _durationMs: 6000
                        property real progress: 1
                        property real _remainingMs: _durationMs
                        property bool _expired: false
                        Timer {
                            interval: 50
                            repeat: true
                            running: !toastCard.isCritical && !toastCard.anyScreenHovered
                            onTriggered: {
                                toastCard._remainingMs = Math.max(0, toastCard._remainingMs - interval)
                                toastCard.progress = toastCard._remainingMs / toastCard._durationMs
                                if (toastCard._remainingMs <= 0 && !toastCard._expired) {
                                    toastCard._expired = true
                                    root.expireToast(toastCard.modelData)
                                }
                            }
                        }

                        // Hover tracked via HoverHandler, not
                        // MouseArea.hoverEnabled: on this layer-shell overlay
                        // surface, MouseArea's containsMouse reliably fires
                        // true on enter but the matching false on leave can
                        // simply never arrive, leaving the toast paused
                        // forever. HoverHandler goes through Qt Quick's
                        // newer pointer-handler event path instead of
                        // MouseArea's, which doesn't exhibit this.
                        HoverHandler {
                            id: cardHover
                            onHoveredChanged: {
                                var id = toastCard.modelData?.id
                                if (id === undefined) return
                                var ids = root.hoveredToastIds.filter(i => i !== id)
                                if (hovered) ids.push(id)
                                root.hoveredToastIds = ids
                            }
                        }

                        MouseArea {
                            id: cardMA
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
                                    visible: (toastCard.modelData?.appIcon ?? "") !== ""
                                    source: toastCard.modelData?.appIcon ?? ""
                                    Layout.preferredWidth: 16
                                    Layout.preferredHeight: 16
                                    sourceSize.width: 16
                                    sourceSize.height: 16
                                }
                                Text {
                                    text: toastCard.modelData?.appName || "Notification"
                                    font { family: Config.fontFamily; pixelSize: 11 }
                                    color: Theme.subtle
                                    Layout.fillWidth: true
                                    elide: Text.ElideRight
                                }
                                Rectangle {
                                    visible: toastCard.modelData?.urgency === NotificationUrgency.Critical
                                    width: 6; height: 6; radius: 3
                                    color: Theme.red
                                }
                                // Close button and the circular countdown
                                // ring share this slot, spin-morphing between
                                // each other on hover — same trick as a
                                // hamburger-to-X icon transition (rotation,
                                // not literal shape interpolation, which
                                // would need per-frame path interpolation
                                // between a circle and an X and is prone to
                                // ugly self-intersections mid-transition).
                                Item {
                                    id: cornerSlot
                                    width: 20; height: 20

                                    Rectangle {
                                        id: closeBtn
                                        anchors.fill: parent
                                        radius: Config.radiusCell
                                        color: closeMA.containsMouse ? Theme.hover : "transparent"
                                        opacity: toastCard.cardHovered ? 1 : 0
                                        scale: toastCard.cardHovered ? 1 : 0.4
                                        rotation: toastCard.cardHovered ? 0 : -90
                                        visible: opacity > 0.01
                                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }

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
                                            enabled: toastCard.cardHovered
                                            onClicked: root.dismissNotification(toastCard.modelData)
                                        }
                                    }

                                    Canvas {
                                        id: countdownRing
                                        anchors.fill: parent
                                        opacity: toastCard.cardHovered ? 0 : 1
                                        scale: toastCard.cardHovered ? 0.4 : 1
                                        rotation: toastCard.cardHovered ? 90 : 0
                                        visible: opacity > 0.01
                                            && !toastCard.isCritical
                                            && Config.toastCountdownStyle === "circle"
                                        Behavior on opacity { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        Behavior on scale { NumberAnimation { duration: 180; easing.type: Easing.OutBack } }
                                        Behavior on rotation { NumberAnimation { duration: 180; easing.type: Easing.OutCubic } }
                                        onPaint: {
                                            var ctx = getContext("2d")
                                            ctx.reset()
                                            var cx = width / 2, cy = height / 2
                                            var r = width / 2 - 2
                                            var start = -Math.PI / 2
                                            var end = start + 2 * Math.PI * toastCard.progress
                                            ctx.lineWidth = 2
                                            ctx.strokeStyle = Theme.subtle
                                            ctx.beginPath()
                                            ctx.arc(cx, cy, r, start, end)
                                            ctx.stroke()
                                        }
                                        Connections {
                                            target: toastCard
                                            function onProgressChanged() { countdownRing.requestPaint() }
                                        }
                                        onVisibleChanged: if (visible) requestPaint()
                                    }
                                }
                            }

                            Text {
                                visible: (toastCard.modelData?.summary ?? "") !== ""
                                text: toastCard.modelData?.summary ?? ""
                                font { family: Config.fontFamily; pixelSize: 13; bold: true }
                                color: Theme.text
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 2
                                elide: Text.ElideRight
                            }

                            Text {
                                visible: (toastCard.modelData?.body ?? "") !== ""
                                text: toastCard.modelData?.body ?? ""
                                font { family: Config.fontFamily; pixelSize: 12 }
                                color: Theme.subtle
                                Layout.fillWidth: true
                                wrapMode: Text.WordWrap
                                maximumLineCount: 3
                                elide: Text.ElideRight
                            }

                            // Some senders (Claude Code among them) include
                            // an action with an empty label — probably a
                            // default/icon-only action their client expects
                            // its OWN UI to render specially, not something
                            // meant to show as a blank pill here. Filtered
                            // out rather than rendered empty.
                            RowLayout {
                                readonly property var visibleActions: (toastCard.modelData?.actions ?? []).filter(a => (a.text ?? "") !== "")
                                visible: visibleActions.length > 0
                                Layout.fillWidth: true
                                Layout.topMargin: 4
                                spacing: 6
                                // Right-aligned, not stretched: equal
                                // full-width buttons imply equal weight and
                                // turn a mostly-ignored control into the
                                // toast's biggest hit target. Buttons size to
                                // their label instead.
                                Item { Layout.fillWidth: true }
                                Repeater {
                                    model: parent.visibleActions
                                    delegate: Rectangle {
                                        required property var modelData
                                        implicitWidth: btnLabel.implicitWidth + 24
                                        height: 28; radius: Config.radiusCell
                                        // Recessed → level → raised against the
                                        // card's own elev2 ink (0.05/0.10/0.16),
                                        // never outranking the card it sits on
                                        // — and edgeStrong instead of edge,
                                        // since edge's contrast is calibrated
                                        // against bare `base`, not a card
                                        // (halved effective contrast otherwise,
                                        // which is why a plain-edge border here
                                        // read as barely-there). No shadow of
                                        // its own: the halo belongs to the
                                        // toast as a whole.
                                        color: actionArea.pressed ? Theme.controlPress
                                            : actionArea.containsMouse ? Theme.controlHover : Theme.controlRest
                                        border.width: 1
                                        border.color: Theme.edgeStrong
                                        Behavior on color { ColorAnimation { duration: 80 } }
                                        Text {
                                            id: btnLabel
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
                            visible: Config.toastCountdownStyle === "hairline"
                                && !toastCard.isCritical
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
                    visible: toastWindow.relevantToasts.length > 3
                    width: toastColumn.width
                    height: 40
                    readonly property int extraCount: Math.max(0, toastWindow.relevantToasts.length - toastColumn.fullCount)

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
