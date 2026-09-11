import QtQuick
import Quickshell
import Quickshell.Io
import qs.Commons
import qs.Ui
import "Model.js" as Model

Panel {
  id: root
  moduleName: "dguillerm.omarchy-converter"
  ipcTarget: "dguillerm.omarchy-converter"
  manageIpc: false

  property var anchorItem: null
  property var hostWidget: null

  property string activeTab: "currency" // currency | crypto | units
  property string lastEditedSide: "top"

  property string currencyFrom: "EUR"
  property string currencyTo: "USD"
  property string cryptoFrom: "bitcoin"
  property string cryptoTo: "USD"
  property string unitCategory: "length"
  property string unitFrom: "m"
  property string unitTo: "ft"

  readonly property var barIdentity: hostWidget || root
  readonly property var rateTable: hostWidget ? hostWidget.currencyRates : ({})
  readonly property var cryptoTable: hostWidget ? hostWidget.cryptoPrices : ({})
  readonly property color foreground: Color.popups.text
  readonly property color muted: Qt.darker(foreground, 1.4)
  property int nowSec: 0

  // Settings arrive via injectPanel after construction; apply them until the
  // user picks a pair themselves this session.
  onSettingsChanged: {
    if (currencyPair.touched || cryptoPair.touched) return
    currencyFrom = String(setting("defaultCurrencyFrom", currencyFrom))
    currencyTo = String(setting("defaultCurrencyTo", currencyTo))
    currencyPair.syncValues()
  }

  Component.onCompleted: nowSec = Math.floor(Date.now() / 1000)

  Timer {
    interval: 30000
    running: true
    repeat: true
    onTriggered: root.nowSec = Math.floor(Date.now() / 1000)
  }

  onRateTableChanged: if (root.activeTab !== "units") root.recompute()
  onCryptoTableChanged: if (root.activeTab !== "units") root.recompute()
  onActiveTabChanged: {
    root.lastEditedSide = "top"
    root.recompute()
  }

  // Keyboard-first: when the KeyboardPanel primes focus on the key catcher,
  // hand focus straight to the active tab's amount field so typing just works.
  // Chaining off the catcher's focus event avoids racing the host's prime.
  readonly property var activePair: activeTab === "units" ? unitPair
    : (activeTab === "crypto" ? cryptoPair : currencyPair)

  function focusAmountField() {
    if (opened) Qt.callLater(function() {
      if (opened) activePair.topInput.forceActiveFocus()
    })
  }

  function computeConverted(value) {
    if (activeTab === "units") return Model.convertUnit(value, unitCategory, unitFrom, unitTo)
    if (activeTab === "crypto") return Model.convertCross(value, cryptoFrom, cryptoTo, rateTable, cryptoTable)
    return Model.convertCross(value, currencyFrom, currencyTo, rateTable, cryptoTable)
  }

  function recompute() {
    var pair = activeTab === "units" ? unitPair : (activeTab === "crypto" ? cryptoPair : currencyPair)
    var source = lastEditedSide === "bottom" ? pair.bottomInput : pair.topInput
    var target = lastEditedSide === "bottom" ? pair.topInput : pair.bottomInput
    var value = Model.parseAmount(source.text)
    target.text = isFinite(value) ? Model.formatResult(computeConverted(value)) : ""
  }

  function currencyOptions() {
    var codes = []
    var table = rateTable || {}
    for (var code in table) if (table.hasOwnProperty(code)) codes.push(code)
    codes = codes.length > 0 ? codes.sort() : Model.FALLBACK_CURRENCIES.slice().sort()
    var majors = []
    var rest = []
    for (var i = 0; i < codes.length; i++) {
      if (Model.MAJOR_CURRENCIES.indexOf(codes[i]) !== -1) majors.push(codes[i])
      else rest.push(codes[i])
    }
    var ordered = majors.concat(rest)
    var out = []
    for (var j = 0; j < ordered.length; j++) {
      var c = ordered[j]
      var name = Model.CURRENCY_NAMES[c]
      out.push({ value: c, label: name ? name + " (" + c + ")" : c, description: c })
    }
    return out
  }

  function cryptoOptions() {
    var out = []
    for (var i = 0; i < Model.CRYPTO_LIST.length; i++) {
      var coin = Model.CRYPTO_LIST[i]
      out.push({ value: coin.id, label: coin.name + " (" + coin.symbol + ")", description: coin.symbol })
    }
    return out.concat(currencyOptions())
  }

  function unitCategoryOptions() {
    var out = []
    for (var key in Model.UNIT_CATEGORIES) {
      if (Model.UNIT_CATEGORIES.hasOwnProperty(key))
        out.push({ value: key, label: Model.UNIT_CATEGORIES[key].label, description: key })
    }
    return out
  }

  function unitOptions() {
    var cat = Model.UNIT_CATEGORIES[unitCategory]
    if (!cat) return []
    var out = []
    for (var key in cat.units) {
      if (cat.units.hasOwnProperty(key))
        out.push({ value: key, label: cat.units[key].label, description: key })
    }
    return out
  }

  function setUnitCategory(category) {
    if (!Model.UNIT_CATEGORIES[category]) return
    unitCategory = category
    var keys = Object.keys(Model.UNIT_CATEGORIES[category].units)
    unitFrom = keys[0]
    unitTo = keys.length > 1 ? keys[1] : keys[0]
    unitCategoryDropdown.value = category
    unitPair.syncValues()
    lastEditedSide = "top"
    recompute()
  }

  function ageSuffix(fetchedAt) {
    if (!fetchedAt) return "no data"
    var mins = Math.max(0, Math.round((nowSec - fetchedAt) / 60))
    if (mins < 1) return "just now"
    if (mins < 60) return mins + " min ago"
    return Math.floor(mins / 60) + " h " + (mins % 60) + " min ago"
  }

  function statusText() {
    var ratesStatus = hostWidget ? hostWidget.ratesStatus : "loading"
    var cryptoStatus = hostWidget ? hostWidget.cryptoStatus : "loading"
    var fiat = ratesStatus === "ok" ? "Fiat rates " + ageSuffix(hostWidget.ratesFetchedAt)
      : (ratesStatus === "loading" ? "Fiat rates loading…" : "Fiat rates unavailable")
    var crypto = cryptoStatus === "ok" ? "Crypto " + ageSuffix(hostWidget.cryptoFetchedAt)
      : (cryptoStatus === "loading" ? "Crypto loading…" : "Crypto unavailable")
    return fiat + "   ·   " + crypto + "   ·   v1.2"
  }

  component MiniIconButton: Rectangle {
    id: mini
    property string glyph: ""
    signal activated()
    width: Style.space(24)
    height: width
    radius: width / 2
    color: miniMouse.containsMouse ? Util.alpha(root.foreground, 0.1) : "transparent"
    border.width: 1
    border.color: Util.alpha(root.foreground, 0.2)
    Text {
      anchors.centerIn: parent
      text: mini.glyph
      textFormat: Text.PlainText
      color: root.foreground
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
    }

    MouseArea {
      id: miniMouse
      anchors.fill: parent
      hoverEnabled: true
      cursorShape: Qt.PointingHandCursor
      onClicked: mini.activated()
    }
  }

  component TabHeader: Item {
    id: tab
    property string label: ""
    property bool active: false
    signal selected()
    width: tabLabel.implicitWidth + Style.space(18)
    height: Style.space(26)

    Text {
      id: tabLabel
      anchors.centerIn: parent
      text: tab.label
      textFormat: Text.PlainText
      color: tab.active ? Color.accent : root.muted
      font.family: root.bar ? root.bar.fontFamily : Style.font.family
      font.pixelSize: Style.font.body
      font.bold: tab.active
    }

    Rectangle {
      anchors.bottom: parent.bottom
      anchors.horizontalCenter: parent.horizontalCenter
      width: parent.width - Style.space(10)
      height: 2
      radius: 1
      color: Color.accent
      visible: tab.active
    }

    MouseArea {
      anchors.fill: parent
      cursorShape: Qt.PointingHandCursor
      onClicked: tab.selected()
    }
  }

  // Bidirectional amount editor: two amount fields with a From/To picker row.
  // The parent owns conversion state; this component only reports intent.
  component PairEditor: Column {
    id: pair
    property var options: []
    property string fromValue: ""
    property string toValue: ""
    property string topPlaceholder: "Enter amount"
    property string bottomPlaceholder: "Result (editable)"
    property bool touched: false
    readonly property bool anyFieldActive: topInput.activeFocus || bottomInput.activeFocus
    readonly property bool anyPopupOpen: fromDropdown.popupOpen || toDropdown.popupOpen
    readonly property alias topInput: topField
    readonly property alias bottomInput: bottomField

    signal fromChanged(string value)
    function handleFieldKey(field, side, event) {
      if (event.key === Qt.Key_Escape) {
        root.close()
        event.accepted = true
        return
      }
      // Numpad digits arrive as different keys depending on numlock state
      // and protocol: Key_KP_0..KP_9 (text sometimes empty) when numlock is
      // on, or the navigation keys (Key_Clear, Key_Home, ...) tagged with
      // KeypadModifier when it is off. Map all of them to digits.
      var keypadDigit = null
      if (event.key >= Qt.Key_KP_0 && event.key <= Qt.Key_KP_9) {
        keypadDigit = String(event.key - Qt.Key_KP_0)
      } else if (event.text === "" && (event.modifiers & Qt.KeypadModifier)) {
        switch (event.key) {
          case Qt.Key_Insert: keypadDigit = "0"; break
          case Qt.Key_End: keypadDigit = "1"; break
          case Qt.Key_Down: keypadDigit = "2"; break
          case Qt.Key_PageDown: keypadDigit = "3"; break
          case Qt.Key_Left: keypadDigit = "4"; break
          case Qt.Key_Clear: keypadDigit = "5"; break
          case Qt.Key_Right: keypadDigit = "6"; break
          case Qt.Key_Home: keypadDigit = "7"; break
          case Qt.Key_Up: keypadDigit = "8"; break
          case Qt.Key_PageUp: keypadDigit = "9"; break
        }
      }
      if (keypadDigit !== null) {
        // Typing over a selection must replace it, like native text input.
        if (field.selectedText !== "")
          field.remove(field.selectionStart, field.selectionEnd)
        field.insert(field.cursorPosition, keypadDigit)
        event.accepted = true
        // Programmatic insert() does not emit textEdited, so report the
        // side manually — conversion state must follow the last typed field.
        pair.touched = true
        pair.edited(side)
      }
    }
    signal toChanged(string value)
    signal swapped()
    signal edited(string side)

    function syncValues() {
      fromDropdown.value = pair.fromValue
      toDropdown.value = pair.toValue
    }

    width: parent ? parent.width : 0
    spacing: Style.space(6)
    readonly property int unitWidth: Style.space(168)

    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: topField
        width: parent.width - pair.unitWidth - Style.space(8)
        placeholderText: pair.topPlaceholder
        verticalPadding: Style.space(5)
        onTextEdited: {
          pair.touched = true
          pair.edited("top")
        }
        Keys.onPressed: function(event) { pair.handleFieldKey(topField, "top", event) }
      }

      SearchableDropdown {
        id: fromDropdown
        width: pair.unitWidth
        showLabel: false
        anchors.verticalCenter: parent.verticalCenter
        options: pair.options
        value: pair.fromValue
        onChanged: function(value) {
          pair.touched = true
          pair.fromChanged(value)
        }
      }
    }

    // Separator row: thin rules flanking the swap control.
    Item {
      width: parent.width
      height: Style.space(24)

      Rectangle {
        anchors.left: parent.left
        anchors.right: swapButton.left
        anchors.rightMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Util.alpha(root.foreground, 0.15)
      }

      Rectangle {
        id: swapButton
        anchors.centerIn: parent
        width: Style.space(22)
        height: width
        radius: width / 2
        color: swapMouse.containsMouse ? Util.alpha(root.foreground, 0.1) : Color.popups.background
        border.width: 1
        border.color: Util.alpha(root.foreground, 0.25)

        Text {
          anchors.centerIn: parent
          text: "⇅"
          textFormat: Text.PlainText
          color: root.foreground
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.body
        }

        MouseArea {
          id: swapMouse
          anchors.fill: parent
          hoverEnabled: true
          cursorShape: Qt.PointingHandCursor
          onClicked: {
            pair.touched = true
            pair.swapped()
          }
        }
      }

      Rectangle {
        anchors.left: swapButton.right
        anchors.right: parent.right
        anchors.leftMargin: Style.space(10)
        anchors.verticalCenter: parent.verticalCenter
        height: 1
        color: Util.alpha(root.foreground, 0.15)
      }
    }

    Row {
      width: parent.width
      spacing: Style.space(8)

      TextField {
        id: bottomField
        width: parent.width - pair.unitWidth - Style.space(8)
        placeholderText: pair.bottomPlaceholder
        verticalPadding: Style.space(5)
        onTextEdited: {
          pair.touched = true
          pair.edited("bottom")
        }
        Keys.onPressed: function(event) { pair.handleFieldKey(bottomField, "bottom", event) }
      }

      SearchableDropdown {
        id: toDropdown
        width: pair.unitWidth
        showLabel: false
        anchors.verticalCenter: parent.verticalCenter
        options: pair.options
        value: pair.toValue
        onChanged: function(value) {
          pair.touched = true
          pair.toChanged(value)
        }
      }
    }
  }

  KeyboardPanel {
    id: panel
    anchorItem: root.anchorItem
    owner: root.barIdentity
    bar: root.bar
    open: root.opened
    focusTarget: keyCatcher
    contentWidth: panel.fittedContentWidth(Style.space(400))
    contentHeight: panel.fittedContentHeight(contentColumn.implicitHeight)

    PanelKeyCatcher {
      id: keyCatcher
      anchors.fill: parent
      blocked: currencyPair.anyFieldActive || currencyPair.anyPopupOpen
        || cryptoPair.anyFieldActive || cryptoPair.anyPopupOpen
        || unitPair.anyFieldActive || unitPair.anyPopupOpen
        || unitCategoryDropdown.popupOpen
      onCloseRequested: root.close()
      onTabRequested: function(direction) { root.switchPanel(direction) }
      onActiveFocusChanged: if (activeFocus) root.focusAmountField()

      Column {
        id: contentColumn
        width: parent.width
        spacing: Style.space(10)

        Text {
          text: "Converter"
          textFormat: Text.PlainText
          color: Color.accent
          font.family: root.bar ? root.bar.fontFamily : Style.font.family
          font.pixelSize: Style.font.title
          font.bold: true
        }

        Row {
          width: parent.width
          height: Style.space(26)
          spacing: Style.space(2)

          TabHeader {
            label: "Currency"
            active: root.activeTab === "currency"
            onSelected: root.activeTab = "currency"
          }
          TabHeader {
            label: "Crypto"
            active: root.activeTab === "crypto"
            onSelected: root.activeTab = "crypto"
          }
          TabHeader {
            label: "Units"
            active: root.activeTab === "units"
            onSelected: root.activeTab = "units"
          }
        }

        SearchableDropdown {
          id: unitCategoryDropdown
          visible: root.activeTab === "units"
          width: parent.width
          label: "Category"
          options: root.unitCategoryOptions()
          value: root.unitCategory
          onChanged: function(value) { root.setUnitCategory(value) }
        }

        PairEditor {
          id: currencyPair
          visible: root.activeTab === "currency"
          options: root.currencyOptions()
          fromValue: root.currencyFrom
          toValue: root.currencyTo
          topPlaceholder: "Amount in " + root.currencyFrom
          bottomPlaceholder: "Amount in " + root.currencyTo
          onFromChanged: function(value) {
            root.currencyFrom = value
            root.recompute()
          }
          onToChanged: function(value) {
            root.currencyTo = value
            root.recompute()
          }
          onSwapped: {
            var f = root.currencyFrom
            root.currencyFrom = root.currencyTo
            root.currencyTo = f
            currencyPair.syncValues()
            root.recompute()
          }
          onEdited: function(side) {
            root.lastEditedSide = side
            root.recompute()
          }
        }

        PairEditor {
          id: cryptoPair
          visible: root.activeTab === "crypto"
          options: root.cryptoOptions()
          fromValue: root.cryptoFrom
          toValue: root.cryptoTo
          onFromChanged: function(value) {
            root.cryptoFrom = value
            root.recompute()
          }
          onToChanged: function(value) {
            root.cryptoTo = value
            root.recompute()
          }
          onSwapped: {
            var f = root.cryptoFrom
            root.cryptoFrom = root.cryptoTo
            root.cryptoTo = f
            cryptoPair.syncValues()
            root.recompute()
          }
          onEdited: function(side) {
            root.lastEditedSide = side
            root.recompute()
          }
        }

        PairEditor {
          id: unitPair
          visible: root.activeTab === "units"
          options: root.unitOptions()
          fromValue: root.unitFrom
          toValue: root.unitTo
          topPlaceholder: "Value"
          bottomPlaceholder: "Value"
          onFromChanged: function(value) {
            root.unitFrom = value
            root.recompute()
          }
          onToChanged: function(value) {
            root.unitTo = value
            root.recompute()
          }
          onSwapped: {
            var f = root.unitFrom
            root.unitFrom = root.unitTo
            root.unitTo = f
            unitPair.syncValues()
            root.recompute()
          }
          onEdited: function(side) {
            root.lastEditedSide = side
            root.recompute()
          }
        }

        Rectangle {
          width: parent.width
          height: 1
          color: Util.alpha(root.foreground, 0.12)
        }

        Item {
          width: parent.width
          height: Style.space(22)

          Text {
            anchors.left: parent.left
            anchors.right: footerRefresh.left
            anchors.verticalCenter: parent.verticalCenter
            text: root.statusText()
            textFormat: Text.PlainText
            color: root.muted
            font.family: root.bar ? root.bar.fontFamily : Style.font.family
            font.pixelSize: Style.font.caption
            elide: Text.ElideRight
          }

          MiniIconButton {
            id: footerRefresh
            anchors.right: parent.right
            anchors.verticalCenter: parent.verticalCenter
            glyph: "↻"
            onActivated: if (root.hostWidget) root.hostWidget.refresh()
          }
        }
      }
    }
  }
}
