import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

BarWidget {
  id: root
  moduleName: "dguillerm.omarchy-converter"

  // Rate state, shared with the panel through hostWidget.
  property var currencyRates: ({})
  property real ratesFetchedAt: 0
  property string ratesStatus: "loading" // loading | ok | error
  property var cryptoPrices: ({})
  property real cryptoFetchedAt: 0
  property string cryptoStatus: "loading" // loading | ok | error

  readonly property var cryptoIdList: {
    var configured = setting("cryptoIds", null)
    var ids = []
    if (Object.prototype.toString.call(configured) === "[object Array]" && configured.length > 0) {
      for (var i = 0; i < configured.length; i++) {
        var value = String(configured[i]).trim()
        if (value !== "") ids.push(value)
      }
    } else if (typeof configured === "string" && configured.trim() !== "") {
      var parts = configured.split(",")
      for (var j = 0; j < parts.length; j++) {
        var part = parts[j].trim()
        if (part !== "") ids.push(part)
      }
    }
    if (ids.length === 0) {
      for (var k = 0; k < Model.CRYPTO_LIST.length; k++) ids.push(Model.CRYPTO_LIST[k].id)
    }
    return ids
  }
  readonly property string ratesScript: localPath(Qt.resolvedUrl("scripts/fetch-rates"))
  readonly property string cryptoScript: localPath(Qt.resolvedUrl("scripts/fetch-crypto"))

  function localPath(url) {
    var value = String(url || "")
    if (value.indexOf("file://") === 0) value = value.substring(7)
    try { return decodeURIComponent(value) } catch (error) { return value }
  }

  function refresh() {
    refreshRates(true)
    refreshCrypto(true)
  }

  function refreshRates(force) {
    if (ratesProcess.running) return
    ratesProcess.force = force === true
    ratesProcess.running = true
  }

  function refreshCrypto(force) {
    if (cryptoProcess.running) return
    cryptoProcess.force = force === true
    cryptoProcess.running = true
  }

  // Shape contract for shell.summon/hide/toggle routing (see Bar.findPanelWidget).
  readonly property bool opened: panelLoader.item ? panelLoader.item.opened === true : false

  function open() {
    if (panelLoader.item) panelLoader.item.open()
  }

  function close() {
    if (panelLoader.item) panelLoader.item.close()
  }

  function toggle() {
    if (panelLoader.item) panelLoader.item.toggle()
  }

  readonly property bool popoutSwitchClosing: panelLoader.item ? panelLoader.item.popoutSwitchClosing === true : false

  function closeForPopoutSwitch() {
    if (panelLoader.item) panelLoader.item.closeForPopoutSwitch()
  }

  function injectPanel() {
    var target = panelLoader.item
    if (!target) return
    if ("bar" in target) target.bar = root.bar
    if ("settings" in target) target.settings = root.settings
    if ("anchorItem" in target) target.anchorItem = button
    if ("hostWidget" in target) target.hostWidget = root
  }

  implicitWidth: button.implicitWidth
  implicitHeight: button.implicitHeight

  onBarChanged: injectPanel()
  onSettingsChanged: injectPanel()
  Component.onCompleted: {
    refreshRates(false)
    refreshCrypto(false)
  }

  Loader {
    id: panelLoader
    active: true
    source: Qt.resolvedUrl("Panel.qml")
    visible: false
    onLoaded: {
      root.injectPanel()
      Qt.callLater(root.injectPanel)
    }
  }

  BarIconButton {
    id: button
    anchors.fill: parent
    bar: root.bar
    text: "⇄"
    // The plain ⇄ glyph renders optically smaller than the nerd-font glyphs
    // used by neighboring widgets; scale it up to match.
    fontSize: Style.bar.iconFont * 1.35
    slotSize: Style.bar.iconSlot
    tooltipText: root.ratesStatus === "ok" && root.cryptoStatus === "ok"
      ? "Converter — rates loaded"
      : (root.ratesStatus === "error" && root.cryptoStatus === "error"
        ? "Converter — rates unavailable"
        : "Converter — loading rates…")

    onPressed: function(mouseButton) {
      if (mouseButton === Qt.RightButton) root.refresh()
      else root.toggle()
    }
  }

  Process {
    id: ratesProcess
    property bool force: false
    command: force ? [root.ratesScript, "USD", "--force"] : [root.ratesScript, "USD"]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyRates(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.ratesFetchedAt === 0) root.ratesStatus = "error"
    }
  }

  Process {
    id: cryptoProcess
    property bool force: false
    command: force
      ? [root.cryptoScript, root.cryptoIdList.join(","), "--force"]
      : [root.cryptoScript, root.cryptoIdList.join(",")]

    stdout: StdioCollector {
      waitForEnd: true
      onStreamFinished: root.applyCrypto(text)
    }
    onExited: function(exitCode) {
      if (exitCode !== 0 && root.cryptoFetchedAt === 0) root.cryptoStatus = "error"
    }
  }

  function applyRates(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (data && data.ok && data.rates) {
        currencyRates = data.rates
        ratesFetchedAt = Number(data.fetched_at || 0)
        ratesStatus = "ok"
      } else if (ratesFetchedAt === 0) {
        ratesStatus = "error"
      }
    } catch (error) {
      if (ratesFetchedAt === 0) ratesStatus = "error"
    }
  }

  function applyCrypto(raw) {
    try {
      var data = JSON.parse(String(raw || "{}"))
      if (data && data.ok && data.prices) {
        cryptoPrices = data.prices
        cryptoFetchedAt = Number(data.fetched_at || 0)
        cryptoStatus = "ok"
      } else if (cryptoFetchedAt === 0) {
        cryptoStatus = "error"
      }
    } catch (error) {
      if (cryptoFetchedAt === 0) cryptoStatus = "error"
    }
  }

  Timer {
    interval: 300000
    running: true
    repeat: true
    onTriggered: {
      root.refreshRates(false)
      root.refreshCrypto(false)
    }
  }
}
