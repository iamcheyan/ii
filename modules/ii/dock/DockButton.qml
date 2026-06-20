import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts

RippleButton {
    id: root

    property bool vertical: false
    property real edgeInsetTop: 0
    property real edgeInsetBottom: 0
    property real edgeInsetLeft: 0
    property real edgeInsetRight: 0
    property real buttonSide: 64

    Layout.fillHeight: !vertical
    Layout.fillWidth: false
    Layout.alignment: vertical ? Qt.AlignHCenter : Qt.AlignVCenter
    Layout.topMargin: vertical ? 0 : (Appearance.sizes.elevationMargin - Appearance.sizes.hyprlandGapsOut)

    readonly property real squareSide: buttonSide

    implicitWidth: squareSide
    implicitHeight: squareSide

    buttonRadius: Math.min(10, squareSide / 5)
    colBackground: ColorUtils.transparentize(Appearance.colors.colLayer2, 1)
    colBackgroundHover: ColorUtils.transparentize(Appearance.colors.colLayer2Hover, 0.88)
    colRipple: ColorUtils.transparentize(Appearance.colors.colLayer2Active, 0.75)

    background.implicitHeight: buttonSide
    background.implicitWidth: buttonSide
}
