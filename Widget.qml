import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui

// Bar widget tracking Steam downloads:
//   boot mode - client bootstrap / self-update (from the Steam journal)
//   game mode - game/content download (from appmanifest_*.acf byte counts)
// Hidden while Steam is closed or idle. Fires one-time notifications when
// the client update or a tracked game download finishes.
BarWidget {
  id: root
  moduleName: "vm.steam-progress"

  property bool active: false
  property int percent: 0
  property string mode: "boot"      // "boot" | "game"
  property string gameName: ""

  property string lastState: "off"
  property int lastPercent: 0
  property string lastGame: ""
  property bool notifiedBoot: false
  property var notifiedGames: ({})

  function clamp(p) { return Math.max(0, Math.min(100, Math.round(p))) }

  function apply(line) {
    let data
    try { data = JSON.parse(String(line).trim()) } catch (e) { return }
    const state = data.state || "off"
    const prev = root.lastState
    root.lastState = state

    if (state === "boot") {
      root.active = true
      root.mode = "boot"
      root.percent = root.clamp(data.pct || 0)
    } else if (state === "game") {
      root.active = true
      root.mode = "game"
      root.gameName = data.name || "Steam"
      root.percent = root.clamp(data.pct || 0)
    } else {
      root.active = false
    }

    // Client bootstrap just finished: one "ready" ping per Steam session.
    if (prev === "boot" && state !== "boot" && !root.notifiedBoot) {
      root.notifiedBoot = true
      root.notify("Steam siap \u{1F3AE}", "Client update selesai \u2014 Steam sudah bisa dibuka.")
    }
    if (state === "off") root.notifiedBoot = false

    // A game we tracked at >=95% left the game state: it finished. (Below 95%
    // the transition is far more likely a pause or a stall, so stay quiet.)
    if (prev === "game" && state !== "game" && root.lastPercent >= 95 && root.lastGame !== "") {
      const g = root.lastGame
      if (!root.notifiedGames[g]) {
        const map = Object.assign({}, root.notifiedGames)
        map[g] = true
        root.notifiedGames = map
        root.notify(g + " siap dimainkan \u{1F3AE}", "Download selesai \u2014 selamat bermain!")
      }
    }
    if (state === "game") {
      root.lastPercent = root.percent
      root.lastGame = root.gameName
    }
  }

  function notify(title, body) {
    if (notifyProc.running) return
    notifyProc.command = ["/usr/bin/notify-send", "-a", "Steam", "-i", "steam", title, body]
    notifyProc.running = true
  }

  function refresh() {
    if (!probe.running) probe.running = true
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
      text: root.mode === "game" ? root.gameName : "Steam"
      font.family: Style.font.family
      font.pixelSize: Style.font.caption
      color: Color.foreground
      elide: Text.ElideRight
      maximumWidth: 110
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
