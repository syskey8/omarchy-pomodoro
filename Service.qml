import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons

Item {
  id: root

  property var shell: null
  property var settings: ({})

  function setting(name, fallback) {
    var value = settings ? settings[name] : undefined
    return value === undefined || value === null ? fallback : value
  }

  readonly property int focusSecs: setting("focusMinutes", 25) * 60
  readonly property int shortBreakSecs: setting("shortBreakMinutes", 5) * 60
  readonly property int longBreakSecs: setting("longBreakMinutes", 15) * 60
  readonly property int sessionsBeforeLong: setting("sessionsBeforeLongBreak", 4)

  property string phase: "focus"
  property int totalSecs: focusSecs
  property int remainingSecs: focusSecs
  property bool running: false
  property int completedSessions: 0
  property int customMinutes: 10

  property double targetTimeMs: 0
  
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

  function start(duration) {
    if (!running) {
      if (remainingSecs <= 0 && duration) {
        remainingSecs = duration
      }
      totalSecs = duration || remainingSecs
      targetTimeMs = Date.now() + (remainingSecs * 1000)
      running = true
    }
  }

  function pause() {
    running = false
  }

  function skip() {
    running = false
    // Skip without completion credit or alarm
    advancePhase()
  }

  function reset() {
    running = false
    phase = "focus"
    completedSessions = 0
    totalSecs = focusSecs
    remainingSecs = focusSecs
  }

  function setCustom(mins) {
    running = false
    customMinutes = mins
    phase = "custom"
    totalSecs = mins * 60
    remainingSecs = mins * 60
  }

  function advancePhase() {
    if (phase === "custom") {
      phase = "focus"
      totalSecs = focusSecs
      remainingSecs = focusSecs
      return
    }

    if (phase === "focus") {
      if (completedSessions > 0 && completedSessions % sessionsBeforeLong === 0) {
        phase = "longBreak"
        totalSecs = longBreakSecs
      } else {
        phase = "shortBreak"
        totalSecs = shortBreakSecs
      }
    } else {
      phase = "focus"
      totalSecs = focusSecs
    }
    remainingSecs = totalSecs
  }

  Process {
    id: alarmSound
    command: ["pw-play", "/usr/share/sounds/freedesktop/stereo/alarm-clock-elapsed.oga"]
  }

  Process {
    id: notifyProcess
    property string titleMsg: ""
    property string bodyMsg: ""
    command: ["omarchy-notification-send", titleMsg, bodyMsg]
  }

  function onPhaseComplete() {
    running = false
    if (phase === "focus") {
      completedSessions++
    }
    
    notifyProcess.titleMsg = phase === "focus" ? "Focus complete" : "Break complete"
    notifyProcess.bodyMsg = phase === "focus" ? "Time for a break." : "Back to work!"
    
    alarmSound.running = true
    notifyProcess.running = true
    
    advancePhase()
  }

  Timer {
    id: countdown
    interval: 500
    running: root.running
    repeat: true
    onTriggered: {
      if (root.running) {
        var now = Date.now()
        var rem = Math.ceil(Math.max(0, root.targetTimeMs - now) / 1000)
        root.remainingSecs = rem
        if (rem <= 0) {
          root.onPhaseComplete()
        }
      }
    }
  }
}
