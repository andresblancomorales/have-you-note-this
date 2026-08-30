import QtQuick
import qs.Commons

// The All Notes window's button. Tinted from whatever colour it is handed --
// the window's foreground for ordinary actions, the theme's urgent for the
// destructive one -- so a button never carries a colour the theme did not
// choose. `enabled` is Item's own, so a disabled button stops its handlers as
// well as dimming.
Rectangle {
  id: button

  property string label: ""
  property color ink: Color.foreground
  // A filled button is the one about to do something irreversible.
  property bool filled: false

  signal clicked()

  implicitWidth: buttonLabel.implicitWidth + 26
  implicitHeight: 30
  width: implicitWidth
  height: implicitHeight
  radius: 8
  opacity: enabled ? 1 : 0.4
  color: button.filled
    ? Util.alpha(button.ink, hover.hovered ? 1.0 : 0.85)
    : (hover.hovered && enabled ? Util.alpha(button.ink, 0.16) : Util.alpha(button.ink, 0.08))

  Text {
    id: buttonLabel
    anchors.centerIn: parent
    text: button.label
    color: button.filled ? Color.background : button.ink
    font.family: Style.font.family
    font.pixelSize: 12
    font.bold: true
  }

  HoverHandler { id: hover }
  TapHandler {
    gesturePolicy: TapHandler.ReleaseWithinBounds
    onTapped: button.clicked()
  }
}
