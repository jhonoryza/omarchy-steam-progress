import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget tracking the Steam bootstrap / self-update download.
// Hidden while Steam is closed or not updating; shows a compact
// "Steam <bar> NN%" readout while the download runs.
BarWidget {
  id: root
  moduleName: "vm.steam-progress"

  property bool active: false
  property int percent: 0
  property string lastState: "off"
  property bool notified: false

  function apply(line) {
    const s = String(line).trim()
    const parts = s.split(":")
    const state = parts[0]
    const prev = root.lastState
    root.lastState = state
    root.active = state === "down"

    if (state === "down") {
      const p = parseInt(parts[1], 10)
      root.percent = isNaN(p) ? 0 : Math.max(0, Math.min(100, p))
    }

    // Bootstrap just finished: fire the "ready" notification exactly once
    // per Steam session; the guard resets when Steam exits.
    if (prev === "down" && state === "done" && !root.notified) {
      root.notified = true
      root.notifyReady()
    }

    if (state === "off") root.notified = false
  }

  function refresh() {
    if (!probe.running) probe.running = true
  }

  function notifyReady() {
    if (notifyProc.running) return
    notifyProc.command = ["/usr/bin/notify-send",
      "-a", "Steam",
      "-i", "steam",
      "Steam siap \u{1F3AE}",
      "Update selesai \u2014 Steam sudah bisa dibuka."]
    notifyProc.running = true
  }

  visible: active
  implicitWidth: root.vertical ? Style.bar.statusSlot : (row.implicitWidth + 16)
  implicitHeight: root.vertical ? (row.implicitHeight + 12) : Style.bar.statusSlot

  IpcHandler {
    target: "vm.steam-progress"

    function refresh(): void {
      root.broadcast("refresh")
    }
  }

  Process {
    id: probe
    command: ["/bin/bash", Qt.resolvedUrl("steam-progress.sh").toString().replace("file://", "")]
    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.apply(text)
    }
  }

  Process {
    id: notifyProc
  }

  Timer {
    interval: 2000
    running: true
    repeat: true
    triggeredOnStart: true
    onTriggered: root.refresh()
  }

  Row {
    id: row
    visible: !root.vertical
    anchors.centerIn: parent
    spacing: 8

    Text {
      text: "Steam"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Color.foreground
      anchors.verticalCenter: parent.verticalCenter
    }

    Item {
      width: 64
      height: 6
      anchors.verticalCenter: parent.verticalCenter

      Rectangle {
        anchors.fill: parent
        radius: 3
        color: Color.foreground
        opacity: 0.15
      }

      Rectangle {
        width: parent.width * root.percent / 100
        anchors {
          top: parent.top
          bottom: parent.bottom
          left: parent.left
        }
        radius: 3
        color: Color.accent
      }
    }

    Text {
      text: root.percent + "%"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Color.foreground
      anchors.verticalCenter: parent.verticalCenter
    }
  }

  Text {
    visible: root.vertical
    anchors.centerIn: parent
    text: root.percent + "%"
    font.family: Style.font.family
    font.pixelSize: Style.font.caption
    color: Color.foreground
  }
}
