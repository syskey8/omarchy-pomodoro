import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

Panel {
  id: root
  moduleName: "syskey8.pomodoro"
  ipcTarget: "syskey8.pomodoro"
  manageIpc: false

  readonly property var service: bar?.shell?.serviceFor("syskey8.pomodoro") || bar?.shell?.serviceFor("omarchy.pomodoro")

  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  readonly property string phase: root.service ? root.service.phase : "focus"
  readonly property bool running: root.service ? root.service.running : false
  readonly property int remainingSecs: root.service ? root.service.remainingSecs : 0
  readonly property int totalSecs: root.service ? root.service.totalSecs : 0
  readonly property int completedSessions: root.service ? root.service.completedSessions : 0
  readonly property int customMinutes: root.service ? root.service.customMinutes : 10
  
  readonly property string phaseLabel: root.service ? root.service.phaseLabel : ""
  readonly property string timeText: root.service ? root.service.timeText : "00:00"
  readonly property real progress: root.service ? root.service.progress : 0
  readonly property bool alarming: root.service ? root.service.alarming : false

  function startPause() {
    if (!root.service) return
    if (root.running) root.service.pause()
    else root.service.start(0)
  }
  
  function stop() { if (root.service) root.service.reset() }
  function skip() { if (root.service) root.service.skip() }
  function setCustom(m) { if (root.service) root.service.setCustom(m) }
  
  function switchPhase(newPhase) {
    if (!root.service) return
    root.service.running = false
    root.service.phase = newPhase
    if (newPhase === "focus") root.service.totalSecs = root.service.focusSecs
    else if (newPhase === "shortBreak") root.service.totalSecs = root.service.shortBreakSecs
    else if (newPhase === "longBreak") root.service.totalSecs = root.service.longBreakSecs
    root.service.remainingSecs = root.service.totalSecs
  }

  // ---- IPC handles -------------------------------------------------------
  Connections {
    target: bar ? bar.ipc : null
    ignoreUnknownSignals: true
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function start(): void { if (!root.running) root.startPause() }
    function pause(): void { if (root.running) root.startPause() }
    function reset(): void { root.stop() }
  }

  // ---- bar slot ----------------------------------------------------------
  WidgetButton {
    id: button
    bar: root.bar
    text: root.running || root.remainingSecs !== root.totalSecs ? root.timeText : ""
    iconText: root.phase === "focus" ? "󰔟" : root.phase === "custom" ? "󰔟" : "󰒲"
    iconOnly: text === ""
    urgency: root.alarming ? 2 : root.running ? 1 : 0
    selected: panel.open
    tooltip: root.phaseLabel

    onClicked: root.toggle()
    onRightClicked: root.startPause()
  }

  // ---- dropdown panel ----------------------------------------------------
  KeyboardPanel {
    id: panel
    anchorItem: button
    owner: root
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(320))
    contentHeight: panel.fittedContentHeight(scroll.implicitHeight, Style.space(560))

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: customField.field.activeFocus

      onActivateRequested: root.startPause()
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onTextKey: function(t) {
        if (t === "s" || t === "S") root.startPause()
        else if (t === "r" || t === "R") root.stop()
        else if (t === "n" || t === "N") root.skip()
      }

      ScrollView {
        id: scroll
        anchors.fill: parent
        contentWidth: availableWidth
        clip: true

        Column {
          id: column
          width: parent.width
          spacing: Style.space(14)

          PanelHero {
            width: parent.width
            title: root.phaseLabel
            meta: root.completedSessions > 0
              ? root.completedSessions + " session" + (root.completedSessions > 1 ? "s" : "")
              : "Ready to focus"
            heroSize: Style.font.heading1 * 1.5
            hero: root.timeText
            foreground: root.foreground
            dim: root.dim
            fontFamily: root.fontFamily
            urgency: root.alarming ? 2 : 0
          }

          ProgressBar {
            width: parent.width
            value: root.progress
            foreground: root.foreground
            track: root.track
            accent: root.urgent
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            property real cellWidth: (width - spacing * 2) / 3

            Button {
              width: parent.cellWidth
              iconText: root.running ? "󰏤" : "󰐊"
              text: root.running ? "Pause" : "Start"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              accent: root.running ? root.foreground : root.urgent
              onClicked: root.startPause()
            }

            Button {
              width: parent.cellWidth
              iconText: "󰒭"
              text: "Skip"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              onClicked: root.skip()
            }

            Button {
              width: parent.cellWidth
              iconText: "󰑐"
              text: "Reset"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              onClicked: root.stop()
            }
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "MODES"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)
            property real cellWidth: (width - spacing * 2) / 3

            Button {
              width: parent.cellWidth
              text: "Focus"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              selected: root.phase === "focus"
              onClicked: root.switchPhase("focus")
            }

            Button {
              width: parent.cellWidth
              text: "Short"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              selected: root.phase === "shortBreak"
              onClicked: root.switchPhase("shortBreak")
            }

            Button {
              width: parent.cellWidth
              text: "Long"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              verticalPadding: Style.spacing.controlPaddingY + Style.space(2)
              bordered: true
              selected: root.phase === "longBreak"
              onClicked: root.switchPhase("longBreak")
            }
          }

          PanelSeparator { foreground: root.foreground }

          PanelSectionHeader {
            text: "CUSTOM TIMER"
            foreground: root.foreground
            fontFamily: root.fontFamily
          }

          Row {
            width: parent.width
            spacing: Style.space(6)

            NumberField {
              id: customField
              value: root.customMinutes
              from: 1
              to: 999
              stepSize: 1
              foreground: root.foreground
              accent: root.track
              fontFamily: root.fontFamily
              fontSize: Style.font.body
              onModified: function(v) { if (root.service) root.service.customMinutes = v }
            }

            Button {
              width: parent.width - customField.width - parent.spacing
              height: customField.height
              iconText: "󰐊"
              text: "Start Timer"
              fontSize: Style.font.bodySmall
              foreground: root.foreground
              fontFamily: root.fontFamily
              horizontalPadding: Style.spacing.controlPaddingX
              bordered: true
              active: root.phase === "custom"
              onClicked: root.setCustom(customField.value)
            }
          }

          Text {
            width: parent.width
            text: "S start/pause · N skip · R reset"
            color: root.dim
            font.family: root.fontFamily
            font.pixelSize: Style.font.caption
            horizontalAlignment: Text.AlignHCenter
          }
        }
      }
    }
  }
}
