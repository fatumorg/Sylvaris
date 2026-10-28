import QtQuick
import qs
import qs.services
import qs.components
import "../lib/files.mjs" as F

FocusScope {
    id: clash

    required property var files
    readonly property var spec: clash.files.clash
    readonly property var view: clash.spec !== null ? F.clashView(clash.spec, clash.files.home, Date.now()) : null
    readonly property bool open: clash.view !== null
    property bool renaming: false
    property bool all: false

    visible: card.opacity > 0
    onOpenChanged: {
        if (clash.open) {
            showAnim.restart();
        } else {
            showAnim.stop();
            card.opacity = 0;
            clash.all = false;
            clash.files.focusView();
        }
    }
    onViewChanged: {
        if (clash.view === null)
            return;
        clash.renaming = false;
        field.text = "";
        Qt.callLater(() => keys.forceActiveFocus());
    }

    function choose(what: string): void {
        if (!clash.open || clash.spec.actions.indexOf(what) < 0)
            return;
        if (what === "rename") {
            clash.startRename();
            return;
        }
        clash.files.answerClash(what, "", clash.all);
    }

    function startRename(): void {
        clash.renaming = true;
        field.text = clash.spec.free;
        const dot = F.kindOf(clash.spec.free, clash.spec.incoming.dir) === "folder" ? -1 : clash.spec.free.lastIndexOf(".");
        const end = dot > 0 ? dot : clash.spec.free.length;
        field.focusInput();
        field.select(0, end);
        Qt.callLater(() => {
            field.focusInput();
            field.select(0, end);
        });
    }

    function submitName(): void {
        const err = F.checkName(field.text, [], "");
        if (err !== "" || field.text === clash.spec.name)
            return;
        clash.files.answerClash("rename", field.text, false);
    }

    Keys.onEscapePressed: {
        if (clash.renaming) {
            clash.renaming = false;
            keys.forceActiveFocus();
        } else {
            clash.files.answerClash("cancel", "", false);
        }
    }
    Keys.onReturnPressed: clash.renaming ? clash.submitName() : clash.choose(clash.view.primary)
    Keys.onEnterPressed: clash.renaming ? clash.submitName() : clash.choose(clash.view.primary)
    Keys.onPressed: event => {
        if (clash.renaming || !clash.open || event.modifiers & (Qt.ControlModifier | Qt.AltModifier | Qt.MetaModifier))
            return;
        const k = event.text.toUpperCase();
        if (k === "A") {
            clash.all = !clash.all;
            event.accepted = true;
        } else if (F.CLASH_KEYS[k]) {
            clash.choose(F.CLASH_KEYS[k]);
            event.accepted = true;
        }
    }

    Item {
        id: keys
        focus: true
    }

    Rectangle {
        anchors.fill: parent
        color: Qt.alpha(Theme.base, 0.45)
        opacity: card.opacity
    }

    MouseArea {
        anchors.fill: parent
        enabled: clash.open
        acceptedButtons: Qt.AllButtons
    }

    Item {
        id: card
        anchors.centerIn: parent
        width: Math.min(parent.width - 48, 560)
        height: body.height + 44
        opacity: 0
        scale: 0.96 + 0.04 * card.opacity

        NumberAnimation {
            id: showAnim
            target: card
            property: "opacity"
            from: 0
            to: 1
            duration: Tokens.enterDuration
            easing.type: Easing.BezierSpline
            easing.bezierCurve: Tokens.enterCurve
        }

        Glass {
            anchors.fill: parent
            radius: Tokens.radiusPanel
            raised: true
            offColor: Theme.surface
            offBorder: Theme.line
        }

        MouseArea {
            anchors.fill: parent
            acceptedButtons: Qt.AllButtons
        }

        Column {
            id: body
            x: 24
            y: 22
            width: parent.width - 48
            spacing: 14

            Row {
                width: parent.width
                spacing: 12

                Glyph {
                    id: mark
                    anchors.verticalCenter: parent.verticalCenter
                    text: !clash.open ? "" : ({
                            extract: F.GLYPH.extract,
                            add: F.GLYPH.archive,
                            compress: F.GLYPH.compress,
                            restore: F.GLYPH.restore
                        })[clash.spec.op] || (clash.view.primary === "merge" ? F.GLYPH.folder : F.GLYPH.paste)
                    size: 24
                    color: Theme.accent
                }

                Text {
                    anchors.verticalCenter: parent.verticalCenter
                    width: parent.width - mark.width - 12
                    textFormat: Text.PlainText
                    text: clash.open ? clash.view.title : ""
                    elide: Text.ElideMiddle
                    color: Theme.text
                    font.family: Tokens.fontDisplay
                    font.pixelSize: Tokens.titleSize
                    font.weight: Tokens.titleWeight
                }
            }

            Text {
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: clash.open ? clash.view.text : ""
                color: Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                id: sides
                width: parent.width
                spacing: 10

                Repeater {
                    model: clash.open ? clash.view.sides : []

                    Item {
                        id: side
                        required property var modelData
                        required property int index
                        width: (sides.width - sides.spacing) / 2
                        height: 72

                        Glass {
                            anchors.fill: parent
                            radius: Tokens.radiusRow
                            inner: true
                            offColor: side.index === 1 ? Qt.alpha(Theme.accent, 0.08) : Theme.tintSoft
                            offBorder: side.index === 1 ? Qt.alpha(Theme.accent, 0.35) : Theme.cardLine
                        }

                        Glyph {
                            id: kindMark
                            x: 14
                            anchors.verticalCenter: parent.verticalCenter
                            text: F.glyphOf(F.kindOf(clash.open ? clash.spec.name : "", side.modelData.folder))
                            size: 28
                            color: side.modelData.folder ? Theme.accent : Theme.textDim
                        }

                        Column {
                            anchors.left: kindMark.right
                            anchors.leftMargin: 12
                            anchors.right: parent.right
                            anchors.rightMargin: 12
                            anchors.verticalCenter: parent.verticalCenter
                            spacing: 3

                            Text {
                                width: parent.width
                                textFormat: Text.PlainText
                                text: side.modelData.label
                                elide: Text.ElideMiddle
                                color: Theme.textDim
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                            }

                            Text {
                                width: parent.width
                                textFormat: Text.PlainText
                                text: side.modelData.detail
                                elide: Text.ElideRight
                                color: Theme.text
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.bodySize
                            }

                            Text {
                                visible: side.modelData.badge !== ""
                                textFormat: Text.PlainText
                                text: side.modelData.badge
                                color: Theme.accent
                                font.family: Tokens.fontUi
                                font.pixelSize: Tokens.smallSize
                                font.weight: Font.DemiBold
                            }
                        }
                    }
                }
            }

            Text {
                visible: text !== ""
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                text: !clash.open ? "" : clash.spec.error ? clash.spec.error : clash.view.same ? "They look the same: same size and date." : ""
                color: clash.open && clash.spec.error ? Theme.danger : Theme.textDim
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize
            }

            Row {
                visible: clash.renaming
                width: parent.width
                spacing: 8

                TextBox {
                    id: field
                    width: parent.width - renameButton.width - 8
                    placeholder: "New name"
                    persistentSelection: true
                }

                PillButton {
                    id: renameButton
                    anchors.verticalCenter: parent.verticalCenter
                    label: "Rename"
                    primary: true
                    enabled: F.checkName(field.text, [], "") === "" && clash.open && field.text !== clash.spec.name
                    onClicked: clash.submitName()
                }
            }

            Item {
                width: parent.width
                height: 28

                Toggle {
                    id: allToggle
                    anchors.verticalCenter: parent.verticalCenter
                    checked: clash.all
                    onToggled: value => clash.all = value
                }

                Text {
                    anchors.left: allToggle.right
                    anchors.leftMargin: 10
                    anchors.right: parent.right
                    anchors.verticalCenter: parent.verticalCenter
                    textFormat: Text.PlainText
                    text: "Do the same for every other clash"
                    elide: Text.ElideRight
                    color: Theme.text
                    font.family: Tokens.fontUi
                    font.pixelSize: Tokens.smallSize

                    MouseArea {
                        anchors.fill: parent
                        onClicked: clash.all = !clash.all
                    }
                }
            }

            Flow {
                width: parent.width
                spacing: 8
                layoutDirection: Qt.RightToLeft

                Repeater {
                    model: clash.open ? clash.view.buttons.slice().reverse() : []

                    PillButton {
                        required property var modelData
                        label: modelData.label
                        primary: clash.open && modelData.id === clash.view.primary
                        danger: modelData.id === "replace" && clash.open && clash.view.primary !== "replace"
                        onClicked: clash.choose(modelData.id)
                    }
                }

                PillButton {
                    label: "Cancel"
                    onClicked: clash.files.answerClash("cancel", "", false)
                }
            }

            Text {
                width: parent.width
                textFormat: Text.PlainText
                wrapMode: Text.Wrap
                horizontalAlignment: Text.AlignRight
                text: clash.open ? clash.view.buttons.filter(b => b.id !== "rename").map(b => b.key + " " + b.label.toLowerCase()).concat(clash.spec.actions.indexOf("rename") >= 0 ? ["N rename"] : []).concat(["A every clash", "Esc cancel"]).join(" · ") : ""
                color: Theme.textDim
                opacity: 0.8
                font.family: Tokens.fontUi
                font.pixelSize: Tokens.smallSize - 1
            }
        }
    }
}
