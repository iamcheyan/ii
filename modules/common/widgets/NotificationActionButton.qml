import qs.modules.common
import qs.modules.common.functions
import qs.modules.common.widgets
import qs.services
import QtQuick
import Quickshell.Services.Notifications

RippleButton {
    id: button
    property string buttonText
    property string urgency

    implicitHeight: 28
    leftPadding: 12
    rightPadding: 12
    buttonRadius: 0
    rippleEnabled: false

    colBackground: ColorUtils.transparentize(Appearance.tiling.bg, 1)
    colBackgroundHover: Appearance.tiling.bgHover
    colRipple: Appearance.tiling.bgHover

    borderWidth: 1
    borderColor: (urgency == NotificationUrgency.Critical) ? Appearance.tiling.borderCritical : Appearance.tiling.border

    contentItem: StyledText {
        horizontalAlignment: Text.AlignHCenter
        text: buttonText
        color: (urgency == NotificationUrgency.Critical) ? Appearance.tiling.error : Appearance.tiling.text
    }
}