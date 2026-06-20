import qs.modules.common
import qs.modules.common.widgets
import qs.services
import qs.modules.ii.sidebarRight.notifications
import Qt5Compat.GraphicalEffects
import QtQuick
import QtQuick.Controls
import QtQuick.Layouts

Rectangle {
    id: root
    radius: 0
    color: "#181818"
    border.width: 1
    border.color: "#2f2f2f"

    NotificationList {
        anchors.fill: parent
        anchors.margins: 6
    }
}
