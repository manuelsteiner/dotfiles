import Quickshell
import Quickshell.Hyprland
import Quickshell.Wayland
import QtQuick
import QtQuick.Layouts

Scope {
    Variants {
        model: Config.enableSystemTray ? Quickshell.screens : []
        PanelWindow {
            id: menuWindow
            property var modelData
            property var submenuHandle: null
            property real submenuY: 0
            property real menuOpacity: 0
            readonly property int menuWidth: 200
            readonly property real menuTop: Math.max(0, root.trayMenuY - 18)
            readonly property real availableHeight: Math.max(64, screen.height - menuTop - 8)
            property int mainFocusedIndex: -1
            property int subFocusedIndex: -1
            screen: modelData
            visible: root.trayMenuVisible && root.trayMenuHandle !== null && modelData === root.activePanelScreen
            WlrLayershell.namespace: "qs-traymenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            // HyprlandFocusGrab (below) handles click-outside-to-dismiss, but
            // does NOT by itself route keyboard input to this surface —
            // without keyboardFocus at all, Keys.on* handlers never fire.
            // Claiming it immediately on map fought with the click that
            // opens the menu (see dismissGrabTimer's own comment below), so
            // it's gated on the same 150ms delay as the dismiss grab instead.
            WlrLayershell.keyboardFocus: dismissGrab.active ? WlrKeyboardFocus.OnDemand : WlrKeyboardFocus.None
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.gap
            WlrLayershell.margins.top: menuTop
            anchors { top: true; left: true }
            implicitWidth: menuWidth * 2 + 4
            implicitHeight: Math.min(availableHeight, Math.max(menuFrame.height,
                submenuHandle !== null ? submenuFrame.y + submenuFrame.height : 0))
            color: "transparent"

            onVisibleChanged: {
                if (visible) {
                    menuOpacity = 0
                    mainFocusedIndex = menuWindow.firstNonSeparatorIndex(rootMenuOpener.children.values)
                    subFocusedIndex = -1
                    dismissGrabTimer.restart()
                    menuFadeTimer.restart()
                }
                else {
                    closeSubmenu()
                    dismissGrab.active = false
                    menuOpacity = 0
                }
            }

            function openSubmenu(handle, y) {
                submenuHandle = handle
                submenuY = y
                subFocusedIndex = 0
            }

            function closeSubmenu() {
                submenuHandle = null
                subFocusedIndex = -1
            }

            // D-9 keyboard traversal: operates on the submenu list when one is
            // open, otherwise the main list. QsMenuOpener.children is an
            // UntypedObjectModel (a QAbstractListModel), not a plain array —
            // it has no .length/index access of its own, only .values (a
            // QObjectList that does). Returning the model itself here made
            // entries.length undefined, so the very first arrow press turned
            // focusedIndex into NaN and every press after that was a no-op.
            function activeEntries() {
                return submenuHandle !== null ? submenuOpener.children.values : rootMenuOpener.children.values
            }

            // Steps past separators in one keypress instead of landing on them
            // (a divider isn't a selectable row, so it shouldn't cost a press).
            function moveFocus(delta) {
                var entries = menuWindow.activeEntries()
                if (!entries || entries.length === 0) return
                var isSub = submenuHandle !== null
                var idx = isSub ? subFocusedIndex : mainFocusedIndex
                if (idx < 0) idx = 0
                var next = idx
                while (true) {
                    var candidate = next + delta
                    if (candidate < 0 || candidate >= entries.length) break
                    next = candidate
                    if (!entries[next].isSeparator) break
                }
                if (isSub) subFocusedIndex = next
                else mainFocusedIndex = next
            }

            function firstNonSeparatorIndex(entries) {
                for (var i = 0; i < entries.length; i++) {
                    if (!entries[i].isSeparator) return i
                }
                return entries.length > 0 ? 0 : -1
            }

            function activateFocused() {
                var entries = menuWindow.activeEntries()
                var isSub = submenuHandle !== null
                var idx = isSub ? subFocusedIndex : mainFocusedIndex
                if (!entries || idx < 0 || idx >= entries.length) return
                var entry = entries[idx]
                if (entry.isSeparator || !entry.enabled) return
                if (entry.hasChildren) {
                    menuWindow.openSubmenu(entry, 0)
                } else {
                    entry.triggered()
                    root.closeTrayMenu()
                }
            }

            HyprlandFocusGrab {
                id: dismissGrab
                windows: [menuWindow]
                onCleared: root.closeTrayMenu()
            }

            Timer {
                id: dismissGrabTimer
                interval: 150
                repeat: false
                onTriggered: dismissGrab.active = menuWindow.visible
            }

            Timer {
                id: menuFadeTimer
                interval: 150
                repeat: false
                onTriggered: {
                    menuWindow.menuOpacity = 1
                }
            }

            Item {
                anchors.fill: parent
                focus: true
                Keys.onEscapePressed: root.closeTrayMenu()
                Keys.onUpPressed: menuWindow.moveFocus(-1)
                Keys.onDownPressed: menuWindow.moveFocus(1)
                Keys.onLeftPressed: if (menuWindow.submenuHandle !== null) menuWindow.closeSubmenu()
                Keys.onReturnPressed: menuWindow.activateFocused()
                Keys.onEnterPressed: menuWindow.activateFocused()
            }

            QsMenuOpener {
                id: rootMenuOpener
                menu: root.trayMenuHandle
            }

            QsMenuOpener {
                id: submenuOpener
                menu: menuWindow.submenuHandle
            }

            PopoutFrame {
                id: menuFrame
                z: 1
                opacity: menuWindow.menuOpacity
                anchors.left: parent.left
                y: 0
                width: menuWindow.menuWidth
                height: Math.min(mainMenu.implicitHeight + 16, menuWindow.availableHeight)
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Flickable {
                    id: mainMenuView
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: mainMenu.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: mainMenu
                        width: mainMenuView.width
                        spacing: 2

                        Repeater {
                            model: rootMenuOpener.children

                            delegate: MenuRow {
                                id: mainRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 160
                                entry: modelData
                                leadingItem: index === 0
                                isFocused: menuWindow.submenuHandle === null && index === menuWindow.mainFocusedIndex
                                onSubmenuRequested: menuWindow.openSubmenu(entry, mainRow.mapToItem(menuFrame, 0, 0).y)
                                onSubmenuCleared: menuWindow.closeSubmenu()
                                onHovered: menuWindow.mainFocusedIndex = index
                            }
                        }
                    }
                }

                OverlayScrollBar { flickable: mainMenuView }
            }

            PopoutFrame {
                id: submenuFrame
                z: 1
                visible: true
                opacity: menuWindow.submenuHandle !== null ? 1 : 0
                anchors.left: menuFrame.right
                anchors.leftMargin: 4
                y: Math.min(menuWindow.submenuY,
                    Math.max(0, menuWindow.availableHeight - height))
                width: menuWindow.menuWidth
                height: Math.min(subMenu.implicitHeight + 16, menuWindow.availableHeight)
                Behavior on opacity {
                    NumberAnimation {
                        duration: 160
                        easing.type: Easing.OutCubic
                    }
                }

                Flickable {
                    id: subMenuView
                    anchors.fill: parent
                    anchors.margins: 8
                    contentWidth: width
                    contentHeight: subMenu.implicitHeight
                    clip: true
                    boundsBehavior: Flickable.StopAtBounds

                    ColumnLayout {
                        id: subMenu
                        width: subMenuView.width
                        spacing: 2

                        Repeater {
                            model: submenuOpener.children

                            delegate: MenuRow {
                                id: subRow
                                required property var modelData
                                required property int index
                                Layout.fillWidth: true
                                Layout.minimumWidth: 160
                                entry: modelData
                                interactionEnabled: menuWindow.submenuHandle !== null
                                leadingItem: index === 0
                                isFocused: menuWindow.submenuHandle !== null && index === menuWindow.subFocusedIndex
                                onSubmenuRequested: menuWindow.openSubmenu(entry, subRow.mapToItem(menuFrame, 0, 0).y)
                                onHovered: menuWindow.subFocusedIndex = index
                            }
                        }
                    }
                }

                OverlayScrollBar { flickable: subMenuView }
            }
        }
    }

    component MenuRow: Rectangle {
        required property var entry
        property bool interactionEnabled: true
        property bool leadingItem: false
        property bool isFocused: false
        signal submenuRequested()
        signal submenuCleared()
        signal hovered()
        Layout.fillWidth: true
        // Disabled entries may be informational headers (for example, Handy's
        // version label), so retain them while preventing interaction below.
        visible: !(leadingItem && entry.isSeparator)
        height: entry.isSeparator ? 9 : 28
        radius: Config.radiusCell
        // isFocused already tracks mouse hover too (see the hovered() signal
        // below), so it alone drives the row fill — no separate border for
        // "focused" vs fill for "hovered"; that split doesn't hold up once
        // both gestures move the same state, and no other row list in the
        // shell uses a border for this (device panels, notification rows
        // all just fill on hover).
        color: !entry.isSeparator && isFocused
            ? Theme.hover : "transparent"
        Behavior on color { ColorAnimation { duration: 80 } }

        Rectangle {
            visible: entry.isSeparator
            anchors.centerIn: parent
            width: parent.width - 8
            height: 1
            color: Theme.divider
        }

        RowLayout {
            visible: !entry.isSeparator
            anchors.fill: parent
            anchors.leftMargin: 8
            anchors.rightMargin: 8
            spacing: 6

            Text {
                visible: entry.buttonType !== 0
                font.family: Config.fontFamily
                font.pixelSize: 12
                color: Theme.magenta
                text: entry.checkState > 0
                    ? (entry.buttonType === 1 ? "󰄵" : "󰄮")
                    : (entry.buttonType === 1 ? "󰄱" : "󰄯")
                Layout.preferredWidth: 16
            }

            Text {
                text: entry.text ?? ""
                font { family: Config.fontFamily; pixelSize: 12 }
                color: entry.enabled
                    ? (isFocused ? Theme.text : Theme.subtle)
                    : Theme.muted
                Behavior on color { ColorAnimation { duration: 80 } }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: entry.hasChildren
                text: "›"
                font.pixelSize: 12
                color: Theme.subtle
            }
        }

        Timer {
            id: submenuTimer
            interval: 150
            onTriggered: {
                if (rowMouse.containsMouse && entry.hasChildren)
                    submenuRequested()
            }
        }

        MouseArea {
            id: rowMouse
            anchors.fill: parent
            hoverEnabled: true
            preventStealing: true
            enabled: interactionEnabled && !entry.isSeparator && entry.enabled
            onEntered: {
                hovered()
                if (entry.hasChildren) submenuTimer.restart()
                else submenuCleared()
            }
            onExited: submenuTimer.stop()
            onPressed: mouse => mouse.accepted = true
            onClicked: mouse => {
                mouse.accepted = true
                if (entry.hasChildren)
                    submenuRequested()
                else {
                    entry.triggered()
                    root.closeTrayMenu()
                }
            }
        }
    }
}
