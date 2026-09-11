import Quickshell
import Quickshell.Wayland
import Quickshell.Services.Notifications
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableNotifications ? Quickshell.screens : []
        PanelWindow {
            id: notifWindow
            property var modelData
            screen: modelData
            visible: root.notifPanelVisible && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-notifpanel"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.keyboardFocus: WlrKeyboardFocus.OnDemand
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            anchors { top: true; bottom: true; left: true; right: true }
            color: "transparent"

            // D-6: collapse consecutive same-app notifications into one group,
            // expandable to reveal the individual entries.
            //
            // The ListView below is bound DIRECTLY to root.storedNotifications
            // (a flat array of live Notification QObjects, the same shape
            // used safely elsewhere in the shell) rather than to a freshly
            // synthesized array of grouping objects. Two earlier attempts at
            // a "pre-grouped" model — first nesting an array of QObjects per
            // group, then a flatter {appName, primary, count} object per
            // group — both crashed Quickshell with a segfault confirmed via
            // crash report: Qt's var/QVariantMap conversion for a plain-JS-
            // object-array ListView model is not reliable here once a QObject
            // reference is involved, evidently regardless of how flat the
            // wrapping object is. headIndices avoids the problem entirely —
            // it's a plain array of integers, nothing else — and grouping
            // becomes per-delegate visibility logic instead of pre-shaped
            // model data.
            readonly property var headIndices: {
                var list = root.storedNotifications
                var heads = []
                for (var i = 0; i < list.length; i++) {
                    var key = notifWindow.groupKey(list[i])
                    var prevKey = i > 0 ? notifWindow.groupKey(list[i - 1]) : null
                    if (i === 0 || key !== prevKey) heads.push(i)
                }
                return heads
            }

            // Grouping key: appName when the sender set one, otherwise a
            // per-notification id so unnamed notifications (some CLI tools'
            // notify-send calls, some apps) don't all collapse into one
            // shared "Notification" group with every other unnamed one.
            // When Config.groupNotifications is off, every notification gets
            // its own unique key (its id) so grouping never kicks in at all.
            function groupKey(n) {
                if (!Config.groupNotifications) return "notification-" + n.id
                return n.appName ? n.appName : "notification-" + n.id
            }

            // storedNotifications is sorted by urgency (descending), so the
            // head being Critical means at least one Critical entry exists.
            readonly property bool anyCritical: root.storedNotifications.length > 0
                && root.storedNotifications[0].urgency === NotificationUrgency.Critical

            // Expand/collapse state keyed by groupKey.
            property var expandedGroups: ({})
            function toggleGroup(key) {
                var copy = Object.assign({}, notifWindow.expandedGroups)
                copy[key] = !copy[key]
                notifWindow.expandedGroups = copy
            }

            // D-9 keyboard traversal — focusedIndex is a position within
            // headIndices (i.e. "which group"), not a raw storedNotifications index.
            property int focusedIndex: -1
            onVisibleChanged: if (visible) notifWindow.focusedIndex = notifWindow.headIndices.length > 0 ? 0 : -1

            MouseArea {
                anchors.fill: parent
                acceptedButtons: Qt.LeftButton | Qt.RightButton
                onClicked: root.notifPanelVisible = false
                focus: true
                Keys.onEscapePressed: root.notifPanelVisible = false
                Keys.onUpPressed: notifWindow.focusedIndex = Math.max(0, notifWindow.focusedIndex - 1)
                Keys.onDownPressed: notifWindow.focusedIndex = Math.min(notifWindow.headIndices.length - 1, notifWindow.focusedIndex + 1)
                Keys.onReturnPressed: notifWindow.activateFocused()
                Keys.onEnterPressed: notifWindow.activateFocused()
            }

            function activateFocused() {
                if (notifWindow.focusedIndex < 0 || notifWindow.focusedIndex >= notifWindow.headIndices.length) return
                var storedIdx = notifWindow.headIndices[notifWindow.focusedIndex]
                var nextHead = notifWindow.focusedIndex + 1 < notifWindow.headIndices.length
                    ? notifWindow.headIndices[notifWindow.focusedIndex + 1] : root.storedNotifications.length
                var count = nextHead - storedIdx
                var key = notifWindow.groupKey(root.storedNotifications[storedIdx])
                if (count > 1) notifWindow.toggleGroup(key)
            }

            PopoutFrame {
                anchors.bottom: parent.bottom
                anchors.left: parent.left
                anchors.leftMargin: 0
                anchors.bottomMargin: Config.gap
                width: Config.notifPanelWidth
                height: Config.notifPanelHeight

                MouseArea { anchors.fill: parent }

                ColumnLayout {
                    anchors.fill: parent
                    anchors.margins: 12
                    spacing: 8

                    // Header
                    RowLayout {
                        Layout.fillWidth: true
                        spacing: 8

                        Text {
                            text: "Notifications"
                            font { family: Config.fontFamily; pixelSize: 13; bold: true }
                            color: Theme.text
                        }

                        Rectangle {
                            // Outlined and urgency-conditional, matching the
                            // bar badge and the per-group ×N chip — a count
                            // of routine notifications shouldn't carry the
                            // same red as an actually critical one.
                            visible: root.storedNotifications.length > 0
                            width: Math.max(20, countText.implicitWidth + 8)
                            height: 20; radius: 10
                            color: "transparent"
                            border.width: 1
                            border.color: notifWindow.anyCritical ? Theme.red : Theme.edge

                            Text {
                                id: countText
                                anchors.centerIn: parent
                                text: root.storedNotifications.length.toString()
                                font { family: Config.fontFamily; pixelSize: 10; bold: true; features: { "tnum": 1 } }
                                color: notifWindow.anyCritical ? Theme.red : Theme.text
                            }
                        }

                        Item { Layout.fillWidth: true }

                        Rectangle {
                            visible: root.storedNotifications.length > 0
                            width: clearRow.implicitWidth + 12
                            height: 22; radius: Config.radiusCell
                            color: clearAllMA.containsMouse ? Theme.hover : "transparent"
                            Behavior on color { ColorAnimation { duration: 80 } }

                            RowLayout {
                                id: clearRow
                                anchors.centerIn: parent
                                spacing: 4
                                Text {
                                    text: "󰅖"
                                    font.family: Config.fontFamily
                                    font.pixelSize: 11
                                    color: clearAllMA.containsMouse ? Theme.red : Theme.subtle
                                }
                                Text {
                                    text: "Clear all"
                                    font { family: Config.fontFamily; pixelSize: 11; weight: Font.Medium }
                                    color: clearAllMA.containsMouse ? Theme.text : Theme.subtle
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
                        color: Theme.divider
                    }

                    // Empty state. D-7 prefers no placeholder at all, but
                    // unlike the device panels this one has no other control
                    // to fall back on — with nothing here the panel collapses
                    // to just its header, leaving a stray-looking title over
                    // a dead void instead of a filled popout.
                    Item {
                        visible: root.storedNotifications.length === 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        Text {
                            anchors.centerIn: parent
                            text: "No notifications"
                            font { family: Config.fontFamily; pixelSize: 12 }
                            color: Theme.subtle
                        }
                    }

                    // Scrollable notification list
                    Item {
                        visible: root.storedNotifications.length > 0
                        Layout.fillWidth: true
                        Layout.fillHeight: true

                        ListView {
                            id: storedList
                            anchors.fill: parent
                            clip: true
                            boundsBehavior: Flickable.StopAtBounds
                            spacing: 6
                            // Bound directly to the live notification array —
                            // see the note above groupedNotifications' successor,
                            // headIndices, for why this isn't a pre-grouped model.
                            model: root.storedNotifications

                            delegate: Rectangle {
                                id: groupDelegate
                                required property var modelData
                                required property int index
                                readonly property var primary: modelData
                                // Display label only — falls back to a generic
                                // string, not unique. groupKeyValue (below) is
                                // what actually decides grouping.
                                readonly property string appName: modelData.appName || "Notification"
                                readonly property string groupKeyValue: notifWindow.groupKey(modelData)
                                readonly property bool isHead: index === 0
                                    || groupDelegate.groupKeyValue !== notifWindow.groupKey(root.storedNotifications[index - 1])
                                // Position of this row's group within headIndices; -1 for a continuation row.
                                readonly property int headPos: groupDelegate.isHead ? notifWindow.headIndices.indexOf(index) : -1
                                readonly property int nextHeadStoredIndex: {
                                    if (!groupDelegate.isHead) return -1
                                    var hp = groupDelegate.headPos
                                    return hp + 1 < notifWindow.headIndices.length
                                        ? notifWindow.headIndices[hp + 1] : root.storedNotifications.length
                                }
                                readonly property int groupCount: groupDelegate.isHead
                                    ? groupDelegate.nextHeadStoredIndex - index : 0
                                readonly property bool expanded: !!notifWindow.expandedGroups[groupDelegate.groupKeyValue]
                                readonly property bool isFocused: groupDelegate.isHead && groupDelegate.headPos === notifWindow.focusedIndex

                                // Continuation rows only ever render (as a
                                // compact one-liner further down) while their
                                // group is expanded; heads always render.
                                visible: groupDelegate.isHead || groupDelegate.expanded
                                width: storedList.width
                                implicitHeight: visible ? (groupDelegate.isHead ? groupCol.implicitHeight + 20 : extraRow.implicitHeight + 12) : 0
                                radius: Config.radiusIsland
                                color: groupDelegate.isHead ? Theme.elev2 : "transparent"
                                border.width: isFocused ? 1 : 0
                                border.color: Theme.accent

                                // Head row: full content (icon, summary, body, actions, count badge).
                                ColumnLayout {
                                    id: groupCol
                                    visible: groupDelegate.isHead
                                    anchors.fill: parent
                                    anchors.margins: 10
                                    spacing: 3

                                    RowLayout {
                                        Layout.fillWidth: true
                                        spacing: 6

                                        Image {
                                            visible: (groupDelegate.primary.appIcon ?? "") !== ""
                                            source: groupDelegate.primary.appIcon ?? ""
                                            Layout.preferredWidth: 14
                                            Layout.preferredHeight: 14
                                            sourceSize.width: 14
                                            sourceSize.height: 14
                                        }

                                        Text {
                                            text: groupDelegate.appName
                                            font { family: Config.fontFamily; pixelSize: 11 }
                                            color: Theme.subtle
                                            Layout.fillWidth: true
                                            elide: Text.ElideRight
                                        }

                                        Rectangle {
                                            visible: groupDelegate.groupCount > 1
                                            width: countBadge.implicitWidth + 8
                                            height: 16; radius: Config.radiusCell
                                            color: "transparent"
                                            border.width: 1
                                            border.color: Theme.edge
                                            Text {
                                                id: countBadge
                                                anchors.centerIn: parent
                                                text: "×" + groupDelegate.groupCount
                                                font { family: Config.fontFamily; pixelSize: 10; bold: true; features: { "tnum": 1 } }
                                                color: Theme.text
                                            }
                                            MouseArea {
                                                anchors.fill: parent
                                                onClicked: notifWindow.toggleGroup(groupDelegate.groupKeyValue)
                                            }
                                        }

                                        Text {
                                            visible: groupDelegate.groupCount > 1
                                            text: groupDelegate.expanded ? "󰅃" : "󰅀"
                                            font.family: Config.fontFamily
                                            font.pixelSize: 11
                                            color: Theme.subtle
                                            MouseArea {
                                                anchors.fill: parent
                                                anchors.margins: -4
                                                onClicked: notifWindow.toggleGroup(groupDelegate.groupKeyValue)
                                            }
                                        }

                                        Rectangle {
                                            visible: groupDelegate.primary.urgency === NotificationUrgency.Critical
                                            width: 6; height: 6; radius: 3
                                            color: Theme.red
                                        }

                                        Rectangle {
                                            visible: groupDelegate.primary.urgency === NotificationUrgency.Low
                                            width: 6; height: 6; radius: 3
                                            color: Theme.cyan
                                        }

                                        Rectangle {
                                            width: 18; height: 18; radius: Config.radiusCell
                                            color: closeHover.hovered ? Theme.hover : "transparent"

                                            Text {
                                                anchors.centerIn: parent
                                                text: "󰅖"
                                                font.family: Config.fontFamily
                                                font.pixelSize: 11
                                                color: closeHover.hovered ? Theme.red : Theme.subtle
                                            }

                                            MouseArea {
                                                id: closeHover
                                                anchors.fill: parent
                                                hoverEnabled: true
                                                property bool hovered: containsMouse
                                                onClicked: root.dismissStoredNotification(groupDelegate.primary)
                                            }
                                        }
                                    }

                                    Text {
                                        visible: (groupDelegate.primary.summary ?? "") !== ""
                                        text: groupDelegate.primary.summary ?? ""
                                        font { family: Config.fontFamily; pixelSize: 12; bold: true }
                                        color: Theme.text
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    Text {
                                        visible: (groupDelegate.primary.body ?? "") !== ""
                                        text: groupDelegate.primary.body ?? ""
                                        font { family: Config.fontFamily; pixelSize: 11 }
                                        color: Theme.subtle
                                        Layout.fillWidth: true
                                        wrapMode: Text.WordWrap
                                        maximumLineCount: 2
                                        elide: Text.ElideRight
                                    }

                                    RowLayout {
                                        visible: (groupDelegate.primary.actions ?? []).length > 0
                                        Layout.fillWidth: true
                                        Layout.topMargin: 2
                                        spacing: 6
                                        Repeater {
                                            model: groupDelegate.primary.actions ?? []
                                            delegate: Rectangle {
                                                required property var modelData
                                                Layout.fillWidth: true
                                                height: 24; radius: Config.radiusCell
                                                color: actionHover.containsMouse ? Theme.hover : Theme.divider
                                                Behavior on color { ColorAnimation { duration: 80 } }
                                                Text {
                                                    anchors.centerIn: parent
                                                    text: modelData.text ?? ""
                                                    font { family: Config.fontFamily; pixelSize: 11 }
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

                                // Continuation row: a compact one-liner for an
                                // older entry in an expanded group. Each such
                                // row IS its own ListView delegate (index into
                                // root.storedNotifications), not a nested
                                // Repeater — see the note above headIndices.
                                RowLayout {
                                    id: extraRow
                                    visible: !groupDelegate.isHead && groupDelegate.expanded
                                    anchors.left: parent.left
                                    anchors.right: parent.right
                                    anchors.verticalCenter: parent.verticalCenter
                                    anchors.margins: 10
                                    spacing: 6

                                    Text {
                                        text: groupDelegate.primary.summary || groupDelegate.primary.body || ""
                                        font { family: Config.fontFamily; pixelSize: 11 }
                                        color: Theme.subtle
                                        Layout.fillWidth: true
                                        elide: Text.ElideRight
                                    }

                                    Rectangle {
                                        width: 16; height: 16; radius: Config.radiusCell
                                        color: subCloseHover.hovered ? Theme.hover : "transparent"
                                        Text {
                                            anchors.centerIn: parent
                                            text: "󰅖"
                                            font.family: Config.fontFamily
                                            font.pixelSize: 11
                                            color: subCloseHover.hovered ? Theme.red : Theme.subtle
                                        }
                                        MouseArea {
                                            id: subCloseHover
                                            anchors.fill: parent
                                            hoverEnabled: true
                                            property bool hovered: containsMouse
                                            onClicked: root.dismissStoredNotification(groupDelegate.primary)
                                        }
                                    }
                                }
                            }
                        }

                        OverlayScrollBar { flickable: storedList }
                    }
                }
            }
        }
    }
}
