import QtQuick
import QtQuick.Layouts

// One island shell shared by every group of bar cells (A3 rule 2, A8):
// elev1 fill, radiusIsland, 1px edge. Content goes inside as normal children.
Rectangle {
    Layout.alignment: Qt.AlignHCenter
    Layout.fillWidth: true
    radius: Config.barIslands ? Config.radiusIsland : 0
    color: Config.barIslands ? Theme.elev1 : "transparent"
    border.width: Config.barIslands ? 1 : 0
    border.color: Theme.edge
}
