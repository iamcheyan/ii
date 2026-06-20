import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import qs.modules.common.functions
import QtQuick
import QtQuick.Layouts
import Quickshell

DialogListItem {
    id: root
    required property string entry
    signal itemClicked()

    onClicked: {
        Cliphist.copy(entry);
        root.itemClicked();
    }

    readonly property bool isImage: Cliphist.entryIsImage(entry)
    readonly property string cleanText: StringUtils.cleanCliphistEntry(entry)

    contentItem: RowLayout {
        anchors {
            fill: parent
            topMargin: root.verticalPadding
            bottomMargin: root.verticalPadding
            leftMargin: root.horizontalPadding
            rightMargin: root.horizontalPadding
        }
        spacing: 10

        ColumnLayout {
            Layout.fillWidth: true
            spacing: 4

            RowLayout {
                spacing: 10
                MaterialSymbol {
                    iconSize: Appearance.font.pixelSize.larger
                    text: root.isImage ? "image" : "description"
                    color: Appearance.colors.colOnSurfaceVariant
                }
                StyledText {
                    Layout.fillWidth: true
                    color: Appearance.colors.colOnSurfaceVariant
                    elide: Text.ElideRight
                    text: root.isImage ? Translation.tr("Binary Image Data") : root.cleanText
                    textFormat: Text.PlainText
                    font.pixelSize: Appearance.font.pixelSize.small
                }
            }

            Loader {
                active: root.isImage
                Layout.fillWidth: true
                Layout.leftMargin: Appearance.font.pixelSize.larger + 10
                sourceComponent: CliphistImage {
                    entry: root.entry
                    maxWidth: parent.width - (Appearance.font.pixelSize.larger + 10)
                    maxHeight: 80
                }
            }
        }

        RowLayout {
            Layout.alignment: Qt.AlignVCenter
            spacing: 4
            visible: root.hovered || root.focus

            RippleButton {
                id: copyButton
                implicitHeight: 34
                implicitWidth: 34
                buttonRadius: Appearance.rounding.full
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: {
                    Cliphist.copy(root.entry);
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "content_copy"
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
                StyledToolTip {
                    text: Translation.tr("Copy")
                }
            }

            RippleButton {
                id: pasteButton
                implicitHeight: 34
                implicitWidth: 34
                buttonRadius: Appearance.rounding.full
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: {
                    Cliphist.paste(root.entry);
                    root.itemClicked();
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "content_paste"
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
                StyledToolTip {
                    text: Translation.tr("Paste")
                }
            }

            RippleButton {
                id: deleteButton
                implicitHeight: 34
                implicitWidth: 34
                buttonRadius: Appearance.rounding.full
                colBackgroundHover: Appearance.colors.colSecondaryContainerHover
                colRipple: Appearance.colors.colSecondaryContainerActive
                onClicked: {
                    Cliphist.deleteEntry(root.entry);
                }
                MaterialSymbol {
                    anchors.centerIn: parent
                    text: "delete"
                    font.pixelSize: Appearance.font.pixelSize.large
                    color: Appearance.colors.colOnSurface
                }
                StyledToolTip {
                    text: Translation.tr("Delete")
                }
            }
        }
    }
}
