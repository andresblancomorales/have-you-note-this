import QtQuick
import QtQuick.Effects
import Quickshell
import qs.Commons
import qs.Ui
import "Notes.js" as Notes
import "Strings.js" as Strings

// Everything in one list: every note, searchable, filterable, selectable, and
// exportable. This is the window the deck cannot be -- the deck holds what is
// being worked on, this holds all of it, archive included.
//
// The chrome is the desktop's: background, foreground, accent and urgent all
// come from the Omarchy theme, so the window belongs to the session it opens
// in. The notes inside it keep their own paper colours -- that is the note,
// not the chrome, and a note that restyles itself with the desktop stops
// being a recognisable object.
FloatingWindow {
  id: window

  property var host: null
  property var store: null

  readonly property color windowBg: Color.background
  // Search field, filter chip, export sheet: one step up from the background,
  // mixed from the foreground so it lifts on a dark theme and settles on a
  // light one without a second palette to keep in sync.
  readonly property color panelBg: Util.alpha(Color.foreground, 0.07)
  readonly property color ink: Color.foreground
  readonly property color inkSoft: Util.alpha(Color.foreground, 0.55)
  readonly property color hairline: Util.alpha(Color.foreground, 0.12)
  readonly property color danger: Color.urgent

  property string filter: "all"
  property string query: ""
  property string selectedId: ""
  property var checkedIds: []
  property bool exportOpen: false
  property bool importOpen: false
  property bool shortcutsOpen: false
  property bool aboutOpen: false
  property string status: ""

  // The sort is per tab, so switching to Archived can keep its own answer.
  readonly property string sort: host ? host.sortFor(filter) : "updated"

  readonly property var shown: store
    ? Notes.sortNotes(Notes.filterNotes(store.notes, query, filter), sort) : []

  readonly property var sortOptions: [
    { key: "updated", label: host ? host.t("all.sort.updated") : "" },
    { key: "created", label: host ? host.t("all.sort.created") : "" },
    { key: "title", label: host ? host.t("all.sort.title") : "" },
    { key: "deck", label: host ? host.t("all.sort.deck") : "" }
  ]

  function sortLabel(key) {
    for (var i = 0; i < sortOptions.length; i++)
      if (sortOptions[i].key === key) return sortOptions[i].label
    return host ? host.t("all.sort.updated") : ""
  }
  readonly property var selected: store ? store.note(selectedId) : null
  readonly property int checkedCount: checkedIds.length

  title: Strings.APP_NAME
  color: windowBg
  implicitWidth: 1020
  implicitHeight: 700
  minimumSize: Qt.size(760, 520)
  visible: false

  function show(nextFilter) {
    filter = nextFilter || "all"
    if (store) store.refresh()
    visible = true
    Qt.callLater(function() { searchField.forceActiveFocus() })
  }

  function hide() { visible = false }

  function openShortcuts() {
    exportOpen = false
    importOpen = false
    aboutOpen = false
    shortcutsOpen = true
  }

  function openAbout() {
    exportOpen = false
    importOpen = false
    shortcutsOpen = false
    aboutOpen = true
  }

  // Every key the plugin answers to, in the order someone learning it would
  // meet them: the ones that reach the notes from anywhere, the ones inside a
  // note, and the ones that belong to this window.
  readonly property var shortcutGroups: host ? [
    {
      title: host.t("keys.group.anywhere"),
      items: [
        { keys: "Super + Alt + N", what: host.t("keys.newNote") },
        { keys: "Super + Alt + A", what: host.t("keys.allNotes") },
        { keys: "Super + Alt + L", what: host.t("keys.archive") },
        { keys: "Super + Alt + D", what: host.t("keys.toggleDeck") }
      ]
    },
    {
      title: host.t("keys.group.deck"),
      items: [
        { keys: host.t("keys.arrows"), what: host.t("keys.walk") },
        { keys: host.t("keys.homeEnd"), what: host.t("keys.ends") },
        { keys: "Return", what: host.t("keys.openCursor") },
        { keys: "Ctrl + N", what: host.t("keys.newNote") },
        { keys: "Esc", what: host.t("keys.foldAway") }
      ]
    },
    {
      title: host.t("keys.group.note"),
      items: [
        { keys: "Esc", what: host.t("keys.escNote") },
        { keys: "Ctrl + F", what: host.t("keys.find") },
        { keys: "Ctrl + .", what: host.t("keys.colour") },
        { keys: "Ctrl + Shift + A", what: host.t("keys.archiveIt") },
        { keys: "Ctrl + Backspace", what: host.t("keys.deleteIt") },
        { keys: "Tab", what: host.t("keys.titleToBody") }
      ]
    },
    {
      title: host.t("keys.group.window"),
      items: [
        { keys: "Ctrl + A", what: host.t("keys.selectAll") },
        { keys: "Ctrl + F", what: host.t("keys.search") },
        { keys: "Ctrl + N", what: host.t("keys.newNote") },
        { keys: "Ctrl + Z", what: host.t("keys.undo") },
        { keys: host.t("keys.arrows"), what: host.t("keys.listMove") },
        { keys: "Esc", what: host.t("keys.escWindow") },
        { keys: host.t("keys.f1"), what: host.t("keys.thisList") }
      ]
    }
  ] : []

  function isChecked(id) { return checkedIds.indexOf(id) !== -1 }

  // "Select all" means all of what the filter and the query left on screen --
  // ticking thirty rows by hand to act on a search result is not a workflow.
  readonly property bool allShownChecked: shown.length > 0 && shown.every(function(note) {
    return checkedIds.indexOf(note.id) !== -1
  })

  function selectAllShown() {
    var ids = []
    for (var i = 0; i < shown.length; i++) ids.push(shown[i].id)
    checkedIds = ids
  }

  function toggleSelectAll() {
    if (allShownChecked) checkedIds = []
    else selectAllShown()
  }

  function toggleChecked(id) {
    var next = checkedIds.slice()
    var at = next.indexOf(id)
    if (at === -1) next.push(id)
    else next.splice(at, 1)
    checkedIds = next
  }

  // What the action buttons act on: the ticked notes, or the one being read
  // when none are ticked. Every button reads this same list -- Delete used to
  // act on the selected note alone while the header said "5 selected", so
  // deleting a selection took five clicks and looked like a bug because it
  // was one.
  readonly property var targetIds: {
    if (checkedIds.length > 0) return checkedIds
    return selectedId === "" ? [] : [selectedId]
  }

  readonly property int targetCount: targetIds.length

  // A selection of archived notes offers to put them back; anything else --
  // active notes, or a mix -- offers to take them off the deck.
  readonly property bool targetsAllArchived: {
    if (!store || targetIds.length === 0) return false
    for (var i = 0; i < targetIds.length; i++) {
      var note = store.note(targetIds[i])
      if (!note || note.state !== "archived") return false
    }
    return true
  }

  // A count in the label, so a batch action says how big it is before it runs.
  function actionLabel(verb) {
    return targetCount > 1 ? (verb + " " + targetCount) : verb
  }

  // Ticks are ids, and ids go away -- deleting five notes used to leave "5
  // selected" pointing at nothing, with every button greyed out and no way
  // back. Whatever the store drops, the selection drops with it.
  // Delete asks twice here too, and forgets it was asked if the selection
  // moves underneath it -- arming on five notes and firing on a different
  // five is exactly the accident a confirmation is for.
  property bool deleteArmed: false

  function requestDelete() {
    if (targetCount === 0) return
    if (deleteArmed) {
      deleteArmed = false
      deleteDisarm.stop()
      host.deleteNotes(targetIds)
      checkedIds = []
      status = ""
      return
    }
    deleteArmed = true
    deleteDisarm.restart()
  }

  onTargetIdsChanged: { deleteArmed = false; deleteDisarm.stop() }

  Timer {
    id: deleteDisarm
    interval: 3000
    onTriggered: window.deleteArmed = false
  }

  function pruneChecked() {
    if (checkedIds.length === 0 || !store) return
    var next = []
    for (var i = 0; i < checkedIds.length; i++)
      if (store.note(checkedIds[i])) next.push(checkedIds[i])
    if (next.length !== checkedIds.length) checkedIds = next
  }

  Connections {
    target: window.store
    function onNotesChanged() { window.pruneChecked() }
  }

  function runExport(format, target) {
    var ids = window.targetIds
    if (ids.length === 0) { status = window.host.t("status.nothingSelected"); return }
    store.exportNotes(ids, format, target, function(result, error) {
      window.status = error
        ? window.host.t("status.exportFailed", { error: error })
        : window.host.tn("status.exported", ids.length,
            { path: (result && result.length ? result[result.length - 1] : target) })
      window.exportOpen = false
    })
  }

  function runImport(path) {
    store.importArchive(path, function(result, error) {
      window.status = error
        ? window.host.t("status.importFailed", { error: error })
        : window.host.tn("status.imported", result)
      window.importOpen = false
    })
  }

  onVisibleChanged: if (!visible) { checkedIds = []; status = ""; exportOpen = false; importOpen = false }

  // Keep a sensible note in the reading pane as the list narrows under a query.
  onShownChanged: {
    if (shown.length === 0) { selectedId = ""; return }
    if (Notes.indexOfId(shown, selectedId) === -1) selectedId = shown[0].id
  }

  // ------------------------------------------------------------ chrome

  Item {
    id: windowRoot
    anchors.fill: parent

    // -------------------------------------------------------- left pane
    Item {
      id: listPane
      width: 470
      anchors { left: parent.left; top: parent.top; bottom: parent.bottom }

      Column {
        anchors { fill: parent; margins: 22 }
        spacing: 14

        Item {
          width: parent.width
          height: 30

          // The window wears the app's name and its mark; the filter chips
          // below say which notes are in front of you, so a heading that also
          // said "All Notes" was saying it twice.
          Row {
            anchors { left: parent.left; verticalCenter: parent.verticalCenter }
            spacing: 10

            Image {
              anchors.verticalCenter: parent.verticalCenter
              width: 18
              height: 18
              // The 64px art downscaled, rather than the 16px one blown up: at
              // this size the mark reads by its shape, and an integer-scaled
              // 16 would land on 22.5 physical pixels anyway.
              source: Qt.resolvedUrl("assets/logo-64.png")
              sourceSize: Qt.size(64, 64)
              fillMode: Image.PreserveAspectFit
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              text: Strings.APP_NAME
              color: window.ink
              font.family: Style.font.family
              font.pixelSize: 17
              font.bold: true
            }
          }

          // Import and export are the same operation in two directions, and
          // neither is something anyone does often. One button in the
          // window's own title row, rather than two in the rows meant for
          // what you do to a note.
          AllNotesButton {
            id: transferButton
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            label: "⋯"
            ink: window.ink
            onClicked: {
              if (transferMenu.open) { transferMenu.open = false; return }
              var point = transferButton.mapToItem(windowRoot, 0, transferButton.height + 4)
              transferMenu.x = point.x + transferButton.width - transferMenu.width
              transferMenu.y = point.y
              transferMenu.open = true
            }
          }
        }

        // Search
        Rectangle {
          width: parent.width
          height: 36
          radius: 10
          color: window.panelBg

          Text {
            id: searchGlyph
            anchors { left: parent.left; leftMargin: 12; verticalCenter: parent.verticalCenter }
            text: "⌕"
            color: window.inkSoft
            font.family: Style.font.family
            font.pixelSize: 15
          }

          TextInput {
            id: searchField
            anchors {
              left: searchGlyph.right; leftMargin: 8
              right: countLabel.left; rightMargin: 8
              verticalCenter: parent.verticalCenter
            }
            color: window.ink
            font.family: Style.font.family
            font.pixelSize: 13
            selectionColor: Util.alpha(Color.accent, 0.35)
            selectedTextColor: window.ink
            onTextChanged: window.query = text
            Keys.onEscapePressed: text === "" ? window.hide() : (text = "")
            Keys.onDownPressed: listView.forceActiveFocus()
            // A TextInput swallows Ctrl+Z for its own undo, and the search
            // field holds focus the moment this window opens -- so the
            // window-level shortcut never saw the one key most likely to be
            // pressed right after a delete.
            Keys.onPressed: function(event) {
              if (event.key === Qt.Key_Z && (event.modifiers & Qt.ControlModifier)
                  && searchField.text === "") {
                if (window.host) window.host.undoDelete()
                event.accepted = true
              }
              // Ctrl+A means the notes, not the query -- "filter, then take
              // all of these" is the whole reason to want it, and that is
              // exactly the moment the field has text in it. Esc still clears
              // the query, which is what selecting its text was for.
              if (event.key === Qt.Key_A && (event.modifiers & Qt.ControlModifier)) {
                window.toggleSelectAll()
                event.accepted = true
              }
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              visible: searchField.text === ""
              text: window.host.t("all.search")
              color: window.inkSoft
              font: searchField.font
            }
          }

          Text {
            id: countLabel
            anchors { right: parent.right; rightMargin: 12; verticalCenter: parent.verticalCenter }
            text: window.host.tn("all.count", window.shown.length)
            color: window.inkSoft
            font.family: Style.font.family
            font.pixelSize: 12
          }
        }

        // Filters, and how the tab in front of them is sorted.
        Item {
          width: parent.width
          height: 28

          // Lines up with the column of ticks below it, which is what says
          // what it is without a label.
          Rectangle {
            id: selectAllTick
            anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
            width: 18
            height: 18
            radius: 5
            color: window.checkedCount > 0 ? Color.accent : "transparent"
            border.width: 1
            border.color: window.checkedCount > 0
              ? Color.accent : Util.alpha(window.ink, 0.35)
            opacity: window.shown.length === 0 ? 0.35 : 1

            Text {
              anchors.centerIn: parent
              visible: window.checkedCount > 0
              // A dash for "some", a tick for "all of them" -- the state has
              // to say which, or the next click is a guess.
              text: window.allShownChecked ? "✓" : "–"
              color: Color.background
              font.pixelSize: 11
              font.bold: true
            }

            HoverHandler { id: selectAllHover }

            PanelToolTip {
              visible: selectAllHover.hovered
              text: window.allShownChecked
                ? window.host.t("all.clearSelection")
                : window.host.t("all.selectAll", { n: window.shown.length })
            }

            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              enabled: window.shown.length > 0
              onTapped: window.toggleSelectAll()
            }
          }

        Row {
          id: filterRow
          anchors.left: parent.left
          anchors.leftMargin: 30
          anchors.right: sortButton.left
          anchors.rightMargin: 10
          // A Row cannot elide what it holds, so the bound is enforced by
          // clipping: a chip cut off is a layout to fix, a chip drawn over
          // the sort button is a bug that ships.
          clip: true
          spacing: 6

          Repeater {
            model: [
              { key: "all", label: window.host.t("all.filter.all") },
              { key: "active", label: window.host.t("all.filter.active") },
              { key: "archived", label: window.host.t("all.filter.archived") }
            ]

            Rectangle {
              id: chip
              required property var modelData
              readonly property bool current: window.filter === modelData.key
              width: chipLabel.implicitWidth + 24
              height: 28
              radius: 8
              color: current ? Util.alpha(Color.accent, 0.2)
                : (chipHover.hovered ? Util.alpha(window.ink, 0.07) : "transparent")

              Text {
                id: chipLabel
                anchors.centerIn: parent
                text: chip.modelData.label
                color: chip.current ? window.ink : window.inkSoft
                font.family: Style.font.family
                font.pixelSize: 12
                font.bold: chip.current
              }

              HoverHandler { id: chipHover }
              TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: window.filter = chip.modelData.key
              }
            }
          }
        }

          // An icon, not the name of the current sort: that name is a
          // sentence in some languages, and a sentence anchored to the right
          // of a row whose left is a list of filters will eventually land on
          // top of them. The menu says which sort is on, and so does the
          // tooltip.
          AllNotesButton {
            id: sortButton
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            label: "󰒺"
            ink: window.ink
            onClicked: {
              if (sortMenu.open) { sortMenu.open = false; return }
              // Placed at open rather than bound: mapToItem is a one-shot, and
              // nothing above this row changes height while it is up.
              var point = sortButton.mapToItem(windowRoot, 0, sortButton.height + 4)
              sortMenu.x = point.x + sortButton.width - sortMenu.width
              sortMenu.y = point.y
              sortMenu.open = true
            }

            HoverHandler { id: sortHover }

            PanelToolTip {
              visible: sortHover.hovered && !sortMenu.open
              text: window.host.t("all.sortTooltip", { sort: window.sortLabel(window.sort) })
            }
          }
        }

        // The list
        ListView {
          id: listView
          width: parent.width
          height: parent.height - y
          clip: true
          model: window.shown
          spacing: 2
          currentIndex: Notes.indexOfId(window.shown, window.selectedId)
          keyNavigationEnabled: true

          Keys.onReturnPressed: if (currentIndex >= 0) window.selectedId = window.shown[currentIndex].id
          onCurrentIndexChanged: if (currentIndex >= 0 && currentIndex < window.shown.length)
            window.selectedId = window.shown[currentIndex].id

          delegate: Item {
            id: row
            required property var modelData
            required property int index

            readonly property bool current: window.selectedId === modelData.id
            width: listView.width
            height: 58

            Rectangle {
              anchors.fill: parent
              anchors.rightMargin: 4
              radius: 8
              color: row.current ? Util.alpha(Color.accent, 0.16)
                : (rowHover.hovered ? Util.alpha(window.ink, 0.07) : "transparent")
            }

            // Tick box for multi-select export.
            Rectangle {
              id: tick
              anchors { left: parent.left; leftMargin: 4; verticalCenter: parent.verticalCenter }
              width: 18
              height: 18
              radius: 5
              color: window.isChecked(row.modelData.id) ? Color.accent : "transparent"
              border.width: 1
              border.color: Util.alpha(window.ink, 0.35)

              Text {
                anchors.centerIn: parent
                visible: window.isChecked(row.modelData.id)
                text: "✓"
                color: window.windowBg
                font.pixelSize: 11
              }

              TapHandler {
                gesturePolicy: TapHandler.ReleaseWithinBounds
                onTapped: window.toggleChecked(row.modelData.id)
              }
            }

            Rectangle {
              id: colorBar
              anchors { left: tick.right; leftMargin: 12; top: parent.top; bottom: parent.bottom; topMargin: 8; bottomMargin: 8 }
              width: 4
              radius: 2
              color: Notes.palette(row.modelData.color).paper
            }

            Text {
              id: rowTitle
              anchors { left: colorBar.right; leftMargin: 10; right: rowChip.left; rightMargin: 8; top: parent.top; topMargin: 10 }
              text: Notes.titleOf(row.modelData)
              color: window.ink
              font.family: Style.font.family
              font.pixelSize: 13
              font.bold: true
              elide: Text.ElideRight
            }

            Text {
              id: rowChip
              anchors { right: rowTime.left; rightMargin: 10; top: parent.top; topMargin: 11 }
              text: window.host.t(row.modelData.state === "archived"
                ? "all.state.archived" : "all.state.activeShort")
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: 9
              font.letterSpacing: 1
              font.bold: true
            }

            Text {
              id: rowTime
              anchors { right: parent.right; rightMargin: 12; top: parent.top; topMargin: 11 }
              text: window.host.since(row.modelData.updated)
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: 11
            }

            Text {
              anchors { left: colorBar.right; leftMargin: 10; right: parent.right; rightMargin: 12; top: rowTitle.bottom; topMargin: 4 }
              text: Notes.previewOf(row.modelData)
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            HoverHandler { id: rowHover }
            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              onTapped: window.selectedId = row.modelData.id
            }
          }
        }
      }
    }

    Rectangle {
      id: divider
      width: 1
      anchors { left: listPane.right; top: parent.top; bottom: parent.bottom }
      color: window.hairline
    }

    // ------------------------------------------------------- right pane
    Item {
      id: detailPane
      anchors { left: divider.right; right: parent.right; top: parent.top; bottom: parent.bottom }

      Column {
        anchors { fill: parent; margins: 22 }
        spacing: 16

        // Actions for whatever is being read, or for the ticked selection.
        Item {
          width: parent.width
          height: 34

          // Bounded by where the buttons start, so the status line gives way
          // to them instead of running underneath.
          Row {
            id: statusRow
            anchors {
              left: parent.left
              right: actionRow.left
              rightMargin: 12
              verticalCenter: parent.verticalCenter
            }
            spacing: 8

            Rectangle {
              anchors.verticalCenter: parent.verticalCenter
              width: 12
              height: 12
              radius: 3
              visible: window.selected !== null
              color: window.selected ? Notes.palette(window.selected.color).paper : "transparent"
            }

            Text {
              anchors.verticalCenter: parent.verticalCenter
              width: Math.max(0, statusRow.width - 12 - statusRow.spacing
                - (clearButton.visible ? clearButton.width + statusRow.spacing : 0))
              text: window.checkedCount > 0
                ? window.host.t("all.selected", { n: window.checkedCount })
                : (window.selected
                   ? window.host.t(window.selected.state === "archived"
                       ? "all.state.archived" : "all.state.active")
                   : window.host.t("all.noSelection"))
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: 11
              font.letterSpacing: 1
              font.bold: true
              elide: Text.ElideRight
              maximumLineCount: 1
            }

            // Ticking five rows is easy; unticking five is not, and a
            // selection with nothing selected in view is a trap.
            AllNotesButton {
              id: clearButton
              anchors.verticalCenter: parent.verticalCenter
              visible: window.checkedCount > 0
              label: window.host.t("all.clear")
              ink: window.ink
              onClicked: window.checkedIds = []
            }
          }

          Row {
            id: actionRow
            anchors { right: parent.right; verticalCenter: parent.verticalCenter }
            spacing: 8

            AllNotesButton {
              label: window.actionLabel(window.host.t(window.targetsAllArchived
                ? "all.action.putBack" : "all.action.archive"))
              ink: window.ink
              enabled: window.targetCount > 0
              onClicked: {
                var ids = window.targetIds
                if (window.targetsAllArchived) window.host.unarchiveNotes(ids)
                else window.host.archiveNotes(ids)
                window.checkedIds = []
              }
            }

            AllNotesButton {
              label: window.deleteArmed
                ? window.host.t("all.action.deleteArmed")
                : window.actionLabel(window.host.t("all.action.delete"))
              ink: window.danger
              // Armed, it stops being a button that looks like the others.
              filled: window.deleteArmed
              enabled: window.targetCount > 0
              onClicked: window.requestDelete()
            }
          }
        }

        // The note itself, on its own paper.
        Rectangle {
          id: detailCard
          width: parent.width
          // Tall enough to be a note, no taller than it needs: a one-line
          // note used to paint the whole pane in its paper colour, which on a
          // dark theme is a slab rather than a sticky note.
          height: Math.max(220, Math.min(parent.height - y - (statusLine.visible ? statusLine.height + 12 : 0),
            detailFields.bodyContentHeight + 120))
          radius: 14
          visible: window.selected !== null
          color: window.selected ? Notes.palette(window.selected.color).paper : "transparent"

          readonly property color cardInk: window.selected ? Notes.palette(window.selected.color).ink : window.ink

          layer.enabled: true
          layer.effect: MultiEffect {
            shadowEnabled: true
            shadowBlur: 0.6
            shadowVerticalOffset: 3
            shadowOpacity: 0.18
          }

          Item {
            anchors { fill: parent; margins: 20 }

            // The note is editable here too: the reading pane is where a
            // note is found, and finding it is usually the step before
            // changing it. Same fields, same debounce as the deck's card.
            NoteFields {
              id: detailFields
              anchors {
                left: parent.left; right: parent.right
                top: parent.top; bottom: detailFooterRule.top
                bottomMargin: 12
              }
              store: window.store
              note: window.selected
              host: window.host
              ink: detailCard.cardInk
              rule: window.selected ? Notes.palette(window.selected.color).rule : Color.accent
              titleSize: Style.font.heading
              onEscaped: {
                if (findOpen) closeFind()
                else window.hide()
              }
            }

            Rectangle {
              id: detailFooterRule
              anchors { left: parent.left; right: parent.right; bottom: detailFooter.top; bottomMargin: 8 }
              height: 1
              color: Util.alpha(detailCard.cardInk, 0.15)
            }

            Text {
              id: detailFooter
              anchors { left: parent.left; bottom: parent.bottom }
              text: window.selected
                ? window.host.t("all.footer", {
                    created: window.host.longDate(window.selected.created),
                    updated: window.host.since(window.selected.updated) })
                : ""
              color: Util.alpha(detailCard.cardInk, 0.55)
              font.family: Style.font.family
              font.pixelSize: 11
            }
          }
        }

        Text {
          id: statusLine
          width: parent.width
          visible: window.status !== ""
          text: window.status
          color: window.inkSoft
          font.family: Style.font.family
          font.pixelSize: 11
          wrapMode: Text.Wrap
        }
      }

      // Empty state, when a filter or a query leaves nothing to read.
      Text {
        anchors.centerIn: parent
        visible: window.selected === null
        text: window.host.t(window.store && window.store.notes.length === 0
          ? "all.empty.none" : "all.empty.noMatch")
        color: window.inkSoft
        font.family: Style.font.family
        font.pixelSize: 13
      }
    }
  }

  // Sort menu. A sibling of the panes rather than a child of the row it hangs
  // off, so it paints over the list instead of stretching it.
  MouseArea {
    anchors.fill: parent
    visible: sortMenu.open
    onPressed: sortMenu.open = false
  }

  Rectangle {
    id: sortMenu

    property bool open: false

    visible: open
    width: 190
    height: sortColumn.implicitHeight + 12
    radius: 10
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    Column {
      id: sortColumn
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

      Repeater {
        model: Notes.sortsFor(window.filter)

        Item {
          id: sortRow
          required property string modelData
          readonly property bool current: window.sort === modelData
          width: sortColumn.width
          height: 26

          Rectangle {
            anchors.fill: parent
            radius: 6
            color: sortHover.hovered ? Util.alpha(Color.popups.text, 0.1) : "transparent"
          }

          Text {
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: (sortRow.current ? "✓ " : "   ") + window.sortLabel(sortRow.modelData)
            color: Color.popups.text
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
            font.bold: sortRow.current
          }

          HoverHandler { id: sortHover }

          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            onTapped: {
              if (window.host) window.host.setListSort(window.filter, sortRow.modelData)
              sortMenu.open = false
            }
          }
        }
      }
    }

    // A menu naming a sort for a tab that is no longer in front is a menu
    // about nothing.
    Connections {
      target: window
      function onFilterChanged() { sortMenu.open = false }
    }
  }

  // ------------------------------------------------------- transfer

  Rectangle {
    id: transferMenu

    property bool open: false

    // Sized to its longest label, for the same reason the sort control lost
    // its text: "Atajos de teclado" is not "Keyboard shortcuts".
    readonly property var menuItems: {
      var items = [
        { key: "import", label: window.host.t("transfer.import") },
        { key: "export", label: window.host.t("transfer.export") },
        { key: "shortcuts", label: window.host.t("menu.shortcuts") },
        { key: "about", label: window.host.t("menu.about") },
        { key: "", label: "" },
        { key: "", label: window.host.t("menu.languageHeading"), heading: true }
      ]
      for (var i = 0; i < Strings.LANGUAGE_CHOICES.length; i++) {
        var choice = Strings.LANGUAGE_CHOICES[i]
        items.push({
          key: "lang:" + choice.key,
          label: (window.host.languageSetting === choice.key ? "✓ " : "   ") + choice.label
        })
      }
      return items
    }

    readonly property string widestLabel: {
      var longest = ""
      for (var i = 0; i < menuItems.length; i++)
        if (String(menuItems[i].label).length > longest.length) longest = String(menuItems[i].label)
      return longest
    }

    TextMetrics {
      id: transferMetrics
      font.family: Style.font.family
      font.pixelSize: Style.font.bodySmall
      text: transferMenu.widestLabel
    }

    visible: open
    width: Math.max(200, Math.ceil(transferMetrics.advanceWidth) + 30)
    height: transferColumn.implicitHeight + 12
    radius: 10
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    Column {
      id: transferColumn
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 6 }

      Repeater {
        model: transferMenu.menuItems

        Item {
          id: transferRow
          required property var modelData
          readonly property bool heading: modelData.heading === true
          readonly property bool separator: modelData.key === "" && !heading
          readonly property bool usable: !heading && !separator
            && (modelData.key !== "export" || window.targetCount > 0)
          width: transferColumn.width
          height: transferRow.heading ? 22 : (transferRow.separator ? 7 : 26)
          opacity: (usable || heading || separator) ? 1 : 0.4

          Rectangle {
            visible: transferRow.separator
            height: 1
            anchors { left: parent.left; right: parent.right; verticalCenter: parent.verticalCenter; margins: 4 }
            color: Util.alpha(Color.popups.text, 0.15)
          }

          Rectangle {
            visible: !transferRow.separator && !transferRow.heading
            anchors.fill: parent
            radius: 6
            color: transferHover.hovered && transferRow.usable
              ? Util.alpha(Color.popups.text, 0.1) : "transparent"
          }

          Text {
            visible: !transferRow.separator
            anchors { left: parent.left; leftMargin: 8; verticalCenter: parent.verticalCenter }
            text: transferRow.modelData.key === "export" && window.targetCount > 1
              ? window.host.t("transfer.exportCount", { n: window.targetCount })
              : transferRow.modelData.label
            color: transferRow.heading ? Util.alpha(Color.popups.text, 0.5) : Color.popups.text
            font.family: Style.font.family
            font.pixelSize: transferRow.heading ? Style.font.caption : Style.font.bodySmall
            font.bold: transferRow.heading
          }

          HoverHandler { id: transferHover }

          TapHandler {
            gesturePolicy: TapHandler.ReleaseWithinBounds
            enabled: transferRow.usable
            onTapped: {
              var key = transferRow.modelData.key
              transferMenu.open = false
              if (key.indexOf("lang:") === 0) {
                window.host.setLanguage(key.substring(5))
                return
              }
              if (key === "shortcuts") {
                window.openShortcuts()
                return
              }
              if (key === "about") {
                window.openAbout()
                return
              }
              window.shortcutsOpen = false
              window.importOpen = key === "import"
              window.exportOpen = key === "export"
            }
          }
        }
      }
    }
  }

  // The sheet itself: a card over the window rather than a panel in the
  // reading pane, because what it does is about the collection and not about
  // the note being read.
  MouseArea {
    anchors.fill: parent
    visible: window.exportOpen || window.importOpen || window.shortcutsOpen || window.aboutOpen
    onPressed: {
      window.exportOpen = false
      window.importOpen = false
      window.shortcutsOpen = false
      window.aboutOpen = false
    }
  }

  Rectangle {
    id: transferSheet
    visible: window.exportOpen || window.importOpen
    anchors.centerIn: parent
    width: 460
    height: sheetColumn.implicitHeight + 36
    radius: 12
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    // Clicks land on the sheet, not on the dismiss layer under it.
    MouseArea { anchors.fill: parent }

    // A sheet whose whole job is a path should open with the path selected,
    // ready to be replaced or accepted with Return.
    onVisibleChanged: if (visible) Qt.callLater(function() {
      pathField.text = Quickshell.env("HOME") + "/Documents/Notes"
      pathField.forceActiveFocus()
      pathField.selectAll()
    })

    Column {
      id: sheetColumn
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 12 }
      spacing: 10

      Text {
        text: window.importOpen
          ? window.host.t("transfer.importTitle")
          : window.host.tn("transfer.exportTitle", window.targetCount)
        color: window.ink
        font.family: Style.font.family
        font.pixelSize: 12
        font.bold: true
      }

      Rectangle {
        width: parent.width
        height: 30
        radius: 8
        color: window.windowBg

        TextInput {
          id: pathField
          anchors { fill: parent; leftMargin: 10; rightMargin: 10 }
          verticalAlignment: TextInput.AlignVCenter
          // Folder for Markdown/Plain text, file name for the rest. Set on
          // open rather than bound, so each open starts from the default.
          color: window.ink
          font.family: Style.font.family
          font.pixelSize: 12
          selectionColor: Util.alpha(Color.accent, 0.35)
          clip: true
          Keys.onReturnPressed: window.importOpen ? window.runImport(text) : window.runExport("markdown", text)
        }
      }

      Row {
        spacing: 8
        visible: !window.importOpen

        Repeater {
          model: [
            { key: "markdown", label: window.host.t("format.markdown"),
              hint: window.host.t("format.markdown.hint") },
            { key: "text", label: window.host.t("format.text"),
              hint: window.host.t("format.text.hint") },
            { key: "single", label: window.host.t("format.single"),
              hint: window.host.t("format.single.hint") },
            { key: "stickies", label: window.host.t("format.stickies"),
              hint: window.host.t("format.stickies.hint") }
          ]

          // Fixed-width cells: the hint under each format is longer than the
          // button above it, and a Column sized by its widest child let the
          // hints run into each other.
          Item {
            id: formatChoice
            required property var modelData
            width: 103
            height: formatButton.height + 4 + formatHint.height

            AllNotesButton {
              id: formatButton
              anchors.horizontalCenter: parent.horizontalCenter
              label: formatChoice.modelData.label
              ink: window.ink
              onClicked: window.runExport(formatChoice.modelData.key, pathField.text)
            }

            Text {
              id: formatHint
              anchors { left: parent.left; right: parent.right; top: formatButton.bottom; topMargin: 4 }
              horizontalAlignment: Text.AlignHCenter
              wrapMode: Text.WordWrap
              text: formatChoice.modelData.hint
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: 10
            }
          }
        }
      }

      Row {
        spacing: 8

        AllNotesButton {
          visible: window.importOpen
          label: window.host.t("transfer.importButton")
          ink: window.ink
          onClicked: window.runImport(pathField.text)
        }

        AllNotesButton {
          label: window.host.t("transfer.cancel")
          ink: window.inkSoft
          onClicked: { window.exportOpen = false; window.importOpen = false }
        }
      }
    }
  }

  // The cheat sheet. Same card treatment as the transfer sheet: a rare thing
  // you came looking for, over the window rather than inside a pane of it.
  Rectangle {
    id: shortcutSheet
    visible: window.shortcutsOpen
    anchors.centerIn: parent
    width: 560
    height: Math.min(parent.height - 60, shortcutColumn.implicitHeight + 40)
    radius: 12
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    MouseArea { anchors.fill: parent }

    Flickable {
      anchors { fill: parent; margins: 20 }
      contentWidth: width
      contentHeight: shortcutColumn.implicitHeight
      clip: true
      boundsBehavior: Flickable.StopAtBounds

      Column {
        id: shortcutColumn
        width: parent.width
        spacing: 16

        Repeater {
          model: window.shortcutGroups

          Column {
            id: shortcutGroup
            required property var modelData
            width: shortcutColumn.width
            spacing: 6

            Text {
              text: shortcutGroup.modelData.title
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: 10
              font.letterSpacing: 1
              font.bold: true
            }

            Repeater {
              model: shortcutGroup.modelData.items

              Item {
                id: shortcutRow
                required property var modelData
                width: shortcutGroup.width
                // Grows for a line that needs two: the same sentence is
                // longer in one language than in another, and eliding the
                // explanation of a key defeats the point of listing it.
                height: Math.max(22, whatLabel.implicitHeight + 4)

                Text {
                  id: keyLabel
                  anchors { left: parent.left; verticalCenter: parent.verticalCenter }
                  width: 155
                  text: shortcutRow.modelData.keys
                  color: window.ink
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  font.bold: true
                  elide: Text.ElideRight
                }

                Text {
                  id: whatLabel
                  anchors {
                    left: keyLabel.right; leftMargin: 12
                    right: parent.right
                    verticalCenter: parent.verticalCenter
                  }
                  text: shortcutRow.modelData.what
                  color: window.inkSoft
                  font.family: Style.font.family
                  font.pixelSize: Style.font.bodySmall
                  wrapMode: Text.WordWrap
                }
              }
            }
          }
        }

        // The one thing here that is not a key, and the one people miss.
        Text {
          width: shortcutColumn.width
          wrapMode: Text.WordWrap
          text: window.host.t("keys.footer")
          color: Util.alpha(window.ink, 0.4)
          font.family: Style.font.family
          font.pixelSize: 10
        }
      }
    }
  }

  // About: what this is, where it came from, and where it keeps your notes.
  // The facts it quotes are read from the plugin manifest and the running
  // store rather than typed in here, so the card cannot drift from the truth.
  Rectangle {
    id: aboutSheet
    visible: window.aboutOpen
    anchors.centerIn: parent
    width: 520
    height: aboutColumn.implicitHeight + 44
    radius: 12
    color: Color.popups.background
    border.width: 1
    border.color: Util.alpha(Color.popups.border, 0.5)

    MouseArea { anchors.fill: parent }

    Column {
      id: aboutColumn
      anchors { left: parent.left; right: parent.right; top: parent.top; margins: 22 }
      spacing: 14

      Row {
        spacing: 14

        Image {
          anchors.verticalCenter: parent.verticalCenter
          width: 44
          height: 44
          source: Qt.resolvedUrl("assets/logo-256.png")
          sourceSize: Qt.size(256, 256)
          fillMode: Image.PreserveAspectFit
        }

        Column {
          anchors.verticalCenter: parent.verticalCenter
          spacing: 3

          Text {
            text: Strings.APP_NAME
            color: window.ink
            font.family: Style.font.family
            font.pixelSize: Style.font.heading
            font.bold: true
          }

          Text {
            // Straight from manifest.json, so releasing means bumping one file.
            text: window.host.t("about.version", {
              version: (window.host.manifest && window.host.manifest.version) || "—"
            })
            color: window.inkSoft
            font.family: Style.font.family
            font.pixelSize: Style.font.bodySmall
          }
        }
      }

      Text {
        width: aboutColumn.width
        wrapMode: Text.WordWrap
        text: window.host.t("about.tagline")
        color: window.inkSoft
        font.family: Style.font.family
        font.pixelSize: Style.font.bodySmall
      }

      Rectangle {
        width: aboutColumn.width
        height: 1
        color: window.hairline
      }

      // The facts, as label and value pairs.
      Column {
        width: aboutColumn.width
        spacing: 7

        Repeater {
          model: [
            // Shown without its scheme so it fits one line; the tap still
            // hands the browser the whole URL.
            { label: window.host.t("about.repository"),
              value: String(Strings.APP_REPO).replace("https://", ""),
              href: Strings.APP_REPO, link: true },
            { label: window.host.t("about.pluginId"),
              value: (window.host.manifest && window.host.manifest.id) || "—", link: false },
            { label: window.host.t("about.storage"),
              value: (window.store && window.store.dbPath) || "—", link: false },
            { label: window.host.t("about.key"),
              value: window.host.t(window.store && window.store.keyStorage === "keyring"
                ? "about.key.keyring" : "about.key.file"), link: false },
            { label: window.host.t("about.licence"),
              value: window.host.t("about.licenceValue"), link: false }
          ]

          Item {
            id: factRow
            required property var modelData
            width: parent.width
            height: Math.max(18, factValue.implicitHeight)

            Text {
              id: factLabel
              anchors { left: parent.left; top: parent.top }
              width: 118
              text: factRow.modelData.label
              color: window.inkSoft
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
            }

            Text {
              id: factValue
              anchors { left: factLabel.right; leftMargin: 10; right: parent.right; top: parent.top }
              text: factRow.modelData.value
              color: factRow.modelData.link
                ? (repoHover.hovered ? Color.accent : Util.alpha(Color.accent, 0.85))
                : window.ink
              font.family: Style.font.family
              font.pixelSize: Style.font.bodySmall
              font.underline: factRow.modelData.link && repoHover.hovered
              wrapMode: Text.WrapAnywhere
            }

            HoverHandler {
              id: repoHover
              enabled: factRow.modelData.link
              cursorShape: Qt.PointingHandCursor
            }

            PanelToolTip {
              visible: factRow.modelData.link && repoHover.hovered
              text: window.host.t("about.openRepo")
            }

            TapHandler {
              gesturePolicy: TapHandler.ReleaseWithinBounds
              enabled: factRow.modelData.link
              // The desktop decides what a browser is; this only hands it a URL.
              onTapped: Quickshell.execDetached(["xdg-open", factRow.modelData.href])
            }
          }
        }
      }

      Rectangle {
        width: aboutColumn.width
        height: 1
        color: window.hairline
      }

      Text {
        width: aboutColumn.width
        wrapMode: Text.WordWrap
        text: window.host.t("about.sealed")
        color: Util.alpha(window.ink, 0.45)
        font.family: Style.font.family
        font.pixelSize: 10
      }

      AllNotesButton {
        label: window.host.t("about.close")
        ink: window.inkSoft
        onClicked: window.aboutOpen = false
      }
    }
  }

  // Where the notes actually live, said plainly.
  Text {
    anchors { left: parent.left; bottom: parent.bottom; margins: 8 }
    text: (window.store && window.host)
      ? window.host.t(window.store.keyStorage === "keyring"
          ? "all.privacy.keyring" : "all.privacy.file")
      : ""
    color: Util.alpha(window.ink, 0.4)
    font.family: Style.font.family
    font.pixelSize: 10
  }

  // Undo without chasing the toast on the screen edge: the window that ran
  // the delete is the window that should be able to take it back.
  Shortcut {
    sequences: ["Ctrl+Z"]
    onActivated: if (window.host) window.host.undoDelete()
  }
  Shortcut {
    sequences: ["Esc"]
    onActivated: {
      if (window.exportOpen || window.importOpen || window.shortcutsOpen || window.aboutOpen) {
        window.exportOpen = false
        window.importOpen = false
        window.shortcutsOpen = false
        window.aboutOpen = false
      } else if (sortMenu.open || transferMenu.open) {
        sortMenu.open = false
        transferMenu.open = false
      } else {
        window.hide()
      }
    }
  }
  Shortcut { sequences: ["Ctrl+F"]; onActivated: searchField.forceActiveFocus() }
  Shortcut { sequences: ["Ctrl+A"]; onActivated: window.toggleSelectAll() }
  Shortcut {
    sequences: ["F1", "?"]
    onActivated: window.shortcutsOpen ? window.shortcutsOpen = false : window.openShortcuts()
  }
  Shortcut { sequences: ["Ctrl+N"]; onActivated: if (window.host) window.host.newNote() }
}
