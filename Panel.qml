import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Pomodoro timer — a native Omarchy bar widget with a dropdown panel.
//
// Architecture mirrors omarchy.agents: a Panel {} root (IPC + open/close
// lifecycle), a WidgetButton for the bar slot, and a KeyboardPanel for the
// dropdown card.  All colours and sizes come from the theme singletons
// (Style, Color) so the widget looks right on every Omarchy theme.

Panel {
  id: root
  moduleName: "pomodoro"
  ipcTarget: "pomodoro"
  manageIpc: false

  // ---- theme wiring (same pattern as omarchy.agents) ---------------------
  readonly property color foreground: bar ? bar.foreground : Color.foreground
  readonly property color urgent: bar ? bar.urgent : Color.urgent
  readonly property color dim: Qt.darker(foreground, 1.55)
  readonly property color surface: Color.popups.background
  readonly property color track: Style.selectedFillFor(foreground, Color.accent)
  readonly property string fontFamily: bar ? bar.fontFamily : Style.font.family

  // ---- configurable durations (shell.json overrides) ---------------------
  readonly property int focusSecs:      setting("focusMinutes", 25) * 60
  readonly property int shortBreakSecs: setting("shortBreakMinutes", 5) * 60
  readonly property int longBreakSecs:  setting("longBreakMinutes", 15) * 60
  readonly property int sessionsBeforeLong: setting("sessionsBeforeLongBreak", 4)

  // ---- timer state -------------------------------------------------------
  // phase: "focus" | "shortBreak" | "longBreak" | "custom"
  property string phase: "focus"
  property int totalSecs: focusSecs
  property int remainingSecs: focusSecs
  property bool running: false
  property int completedSessions: 0

  // Custom timer input (minutes entered by the user)
  property int customMinutes: 10

  // Human-readable helpers
  readonly property string phaseLabel: phase === "focus" ? "Focus"
    : phase === "shortBreak" ? "Short Break"
    : phase === "longBreak" ? "Long Break"
    : "Custom Timer"

  readonly property string timeText: {
    var m = Math.floor(remainingSecs / 60)
    var s = remainingSecs % 60
    return (m < 10 ? "0" : "") + m + ":" + (s < 10 ? "0" : "") + s
  }

  readonly property real progress: totalSecs > 0
    ? 1.0 - (remainingSecs / totalSecs) : 0

  readonly property bool alarming: running && remainingSecs <= 30

  // ---- core timer --------------------------------------------------------
  Timer {
    id: countdown
    interval: 1000
    running: root.running
    repeat: true
    onTriggered: {
      if (root.remainingSecs > 0) {
        root.remainingSecs--
      }
      if (root.remainingSecs <= 0) {
        root.running = false
        root.onPhaseComplete()
      }
    }
  }

  // ---- sound alert -------------------------------------------------------
  Process {
    id: alarmSound
    command: ["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]
  }

  // Desktop notification via notify-send (does not depend on omarchy reminder)
  Process {
    id: notifyProcess
    property string message: ""
    command: ["notify-send", "--urgency=critical", "--app-name=Pomodoro", "🍅 Pomodoro", message]
  }

  function playAlarm() {
    alarmSound.running = false
    alarmSound.running = true
  }

  function sendNotification(msg) {
    notifyProcess.message = msg
    notifyProcess.running = false
    notifyProcess.running = true
  }

  function onPhaseComplete() {
    // Play the alarm sound and show a notification
    playAlarm()

    if (phase === "focus") {
      completedSessions++
      if (completedSessions % sessionsBeforeLong === 0) {
        sendNotification("Great work! Time for a long break.")
        switchPhase("longBreak")
      } else {
        sendNotification("Focus done! Take a short break.")
        switchPhase("shortBreak")
      }
    } else if (phase === "custom") {
      sendNotification("Custom timer finished!")
      // Stay on custom, reset to the same duration
      remainingSecs = totalSecs
    } else {
      sendNotification("Break over! Time to focus.")
      switchPhase("focus")
    }
  }

  function switchPhase(newPhase) {
    phase = newPhase
    if (newPhase === "focus") {
      totalSecs = focusSecs
    } else if (newPhase === "shortBreak") {
      totalSecs = shortBreakSecs
    } else if (newPhase === "longBreak") {
      totalSecs = longBreakSecs
    } else if (newPhase === "custom") {
      totalSecs = customMinutes * 60
    }
    remainingSecs = totalSecs
  }

  // ---- public actions (also exposed via IPC) -----------------------------
  function startPause() {
    running = !running
  }

  function stop() {
    running = false
    switchPhase("focus")
    completedSessions = 0
  }

  function skip() {
    running = false
    onPhaseComplete()
  }

  function startCustom(minutes) {
    customMinutes = minutes
    running = false
    switchPhase("custom")
    running = true
  }

  // ---- visibility / sizing -----------------------------------------------
  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onOpenedChanged: if (opened) {
    Qt.callLater(function() { keyCatcher.forceActiveFocus() })
  }

  // ---- IPC handler -------------------------------------------------------
  IpcHandler {
    target: root.ipcTarget
    function open(): void { root.open() }
    function close(): void { root.close() }
    function show(): void { root.open() }
    function hide(): void { root.close() }
    function toggle(): void { root.toggle() }
    function start(): void { if (!root.running) root.startPause() }
    function pause(): void { if (root.running) root.startPause() }
    function reset(): void { root.stop() }
  }

  // ---- bar button --------------------------------------------------------
  // Show the icon + live countdown text when running; just the icon at rest.
  WidgetButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    // Tomato icon from Nerd Font
    text: root.running ? "󱎫 " + root.timeText : "󱎫"
    fontSize: Style.font.body
    active: root.alarming
    horizontalMargin: 8.75
    verticalPadding: 8.75
    dimmed: !root.running && root.remainingSecs === root.totalSecs

    onPressed: function(b) {
      if (b === Qt.RightButton) root.startPause()
      else root.toggle()
    }
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
    contentHeight: panel.fittedContentHeight(column.implicitHeight, Style.space(560))

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

      Column {
        id: column
        anchors.left: parent.left
        anchors.right: parent.right
        anchors.top: parent.top
        spacing: Style.space(14)

        // ---------- Hero: tomato icon · phase · session count ---------------
        PanelHero {
          width: parent.width
          title: root.phaseLabel
          meta: root.completedSessions > 0
            ? root.completedSessions + " session" + (root.completedSessions !== 1 ? "s" : "") + " done"
            : "Ready to focus"
          foreground: root.foreground
          fontFamily: root.fontFamily

          iconComponent: Component {
            Text {
              width: Style.font.display
              height: Style.font.display
              text: "󱎫"
              color: root.foreground
              font.family: root.fontFamily
              font.pixelSize: Style.font.display
              horizontalAlignment: Text.AlignHCenter
              verticalAlignment: Text.AlignVCenter
            }
          }
        }

        // ---------- Big countdown display -----------------------------------
        Text {
          width: parent.width
          text: root.timeText
          color: root.alarming ? root.urgent : root.foreground
          font.family: root.fontFamily
          font.pixelSize: Style.font.displayLarge
          font.bold: true
          horizontalAlignment: Text.AlignHCenter

          Behavior on color { ColorAnimation { duration: 200 } }
        }

        // ---------- Progress meter ------------------------------------------
        Item {
          width: parent.width
          implicitHeight: Style.space(8)

          Rectangle {
            id: progressTrack
            anchors.fill: parent
            radius: height / 2
            color: root.track
          }

          Rectangle {
            anchors.left: progressTrack.left
            anchors.verticalCenter: progressTrack.verticalCenter
            height: progressTrack.height
            radius: progressTrack.radius
            color: root.alarming ? root.urgent : root.foreground
            width: Math.max(progressTrack.height, progressTrack.width * root.progress)

            Behavior on width {
              NumberAnimation { duration: 320; easing.type: Easing.OutCubic }
            }
            Behavior on color { ColorAnimation { duration: 220 } }

            // Pulse while running
            SequentialAnimation on opacity {
              running: root.running && root.opened
              loops: Animation.Infinite
              alwaysRunToEnd: true
              NumberAnimation { from: 1.0; to: 0.55; duration: 950; easing.type: Easing.InOutSine }
              NumberAnimation { from: 0.55; to: 1.0; duration: 950; easing.type: Easing.InOutSine }
            }
          }
        }

        // ---------- Controls ------------------------------------------------
        PanelSeparator {
          foreground: root.foreground
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * 2) / 3

          // Start / Pause
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
            active: root.running
            onClicked: root.startPause()
          }

          // Skip to next phase
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

          // Reset everything
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

        // ---------- Phase picker --------------------------------------------
        PanelSeparator {
          foreground: root.foreground
        }

        PanelSectionHeader {
          text: "TIMER MODE"
          foreground: root.foreground
          fontFamily: root.fontFamily
        }

        Row {
          width: parent.width
          spacing: Style.space(6)

          readonly property real cellWidth: (width - spacing * 2) / 3

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
            onClicked: { root.running = false; root.switchPhase("focus") }
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
            onClicked: { root.running = false; root.switchPhase("shortBreak") }
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
            onClicked: { root.running = false; root.switchPhase("longBreak") }
          }
        }

        // ---------- Custom timer --------------------------------------------
        PanelSeparator {
          foreground: root.foreground
        }

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
            accent: root.track // Using track color or default accent
            fontFamily: root.fontFamily
            fontSize: Style.font.body
            onModified: function(v) { root.customMinutes = v }
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
            onClicked: root.startCustom(root.customMinutes)
          }
        }

        // ---------- Keyboard hints ------------------------------------------
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
