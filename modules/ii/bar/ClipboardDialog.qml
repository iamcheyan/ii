import qs
import qs.services
import qs.modules.common
import qs.modules.common.widgets
import QtQuick
import QtQuick.Layouts
import Quickshell

WindowDialog {
    id: root
    backgroundHeight: 600

    onVisibleChanged: {
        if (visible) {
            Cliphist.refresh();
        }
    }

    WindowDialogTitle {
        text: Translation.tr("Clipboard History")
    }

    WindowDialogSeparator {}

    ListView {
        id: clipboardList
        Layout.fillHeight: true
        Layout.fillWidth: true
        Layout.topMargin: 0
        Layout.bottomMargin: 0
        Layout.leftMargin: 0
        Layout.rightMargin: 0

        clip: true
        spacing: 0

        model: ScriptModel {
            values: Cliphist.entries
        }

        delegate: ClipboardItem {
            required property string modelData
            entry: modelData
            width: ListView.view.width
            onItemClicked: root.dismiss()
        }
    }

    WindowDialogSeparator {}

    WindowDialogButtonRow {
        DialogButton {
            buttonText: Translation.tr("Clear All")
            onClicked: {
                Cliphist.wipe();
                root.dismiss();
            }
        }

        Item {
            Layout.fillWidth: true
        }

        DialogButton {
            buttonText: Translation.tr("Done")
            onClicked: root.dismiss()
        }
    }
}
