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
            readonly property int menuWidth: 184
            screen: modelData
            visible: root.trayMenuVisible && root.trayMenuHandle !== null
            WlrLayershell.namespace: "qs-traymenu"
            WlrLayershell.layer: WlrLayer.Overlay
            WlrLayershell.exclusionMode: ExclusionMode.Ignore
            WlrLayershell.margins.left: Config.effectiveBarWidth + Config.barGap
            WlrLayershell.margins.top: Math.max(0, root.trayMenuY - 18)
            anchors { top: true; left: true }
            implicitWidth: menuWidth * 2 + 4
            implicitHeight: Math.max(menuFrame.height,
                submenuHandle !== null ? submenuFrame.y + submenuFrame.height : 0)
            color: "transparent"

            onVisibleChanged: {
                if (visible) {
                    menuOpacity = 0
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
            }

            function closeSubmenu() {
                submenuHandle = null
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

            QsMenuOpener {
                id: rootMenuOpener
                menu: root.trayMenuHandle
            }

            QsMenuOpener {
                id: submenuOpener
                menu: menuWindow.submenuHandle
            }

            Rectangle {
                id: menuFrame
                z: 1
                opacity: menuWindow.menuOpacity
                anchors.left: parent.left
                y: 0
                width: menuWindow.menuWidth
                height: mainMenu.implicitHeight + 16
                radius: 8
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                ColumnLayout {
                    id: mainMenu
                    anchors.fill: parent
                    anchors.margins: 8
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
                            onSubmenuRequested: menuWindow.openSubmenu(entry, mainRow.mapToItem(menuFrame, 0, 0).y)
                            onSubmenuCleared: menuWindow.closeSubmenu()
                        }
                    }
                }
            }

            Rectangle {
                id: submenuFrame
                z: 1
                visible: true
                opacity: menuWindow.submenuHandle !== null ? 1 : 0
                anchors.left: menuFrame.right
                anchors.leftMargin: 4
                y: menuWindow.submenuY
                width: menuWindow.menuWidth
                height: subMenu.implicitHeight + 16
                radius: 8
                color: Theme.surface
                border.color: Theme.overlay
                border.width: 2
                Behavior on opacity {
                    NumberAnimation {
                        duration: 250
                        easing.type: Easing.OutQuint
                    }
                }

                ColumnLayout {
                    id: subMenu
                    anchors.fill: parent
                    anchors.margins: 8
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
                            onSubmenuRequested: menuWindow.openSubmenu(entry, subRow.mapToItem(menuFrame, 0, 0).y)
                        }
                    }
                }
            }
        }
    }

    component MenuRow: Rectangle {
        required property var entry
        property bool interactionEnabled: true
        property bool leadingItem: false
        signal submenuRequested()
        signal submenuCleared()
        Layout.fillWidth: true
        // Disabled entries may be informational headers (for example, Handy's
        // version label), so retain them while preventing interaction below.
        visible: !(leadingItem && entry.isSeparator)
        height: entry.isSeparator ? 9 : 28
        radius: 4
        color: !entry.isSeparator && rowMouse.containsMouse
            ? Theme.highlightMed : "transparent"
        Behavior on color { ColorAnimation { duration: 60 } }

        Rectangle {
            visible: entry.isSeparator
            anchors.centerIn: parent
            width: parent.width - 8
            height: 1
            color: Theme.highlightMed
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
                    ? (rowMouse.containsMouse ? Theme.text : Theme.subtle)
                    : Theme.muted
                Behavior on color { ColorAnimation { duration: 60 } }
                Layout.fillWidth: true
                elide: Text.ElideRight
            }

            Text {
                visible: entry.hasChildren
                text: "›"
                font.pixelSize: 14
                color: Theme.muted
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
