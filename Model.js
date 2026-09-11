// Pure conversion data and math for the converter plugin.
// No QML imports: this file is unit-testable with plain node.
//
// Rate model: every value is converted through a USD pivot.
//   fiat:   rates[code]  = currency units per 1 USD (open.er-api.com shape)
//   crypto: prices[id].usd = USD per 1 coin (CoinGecko shape)

var UNIT_CATEGORIES = {
  length: {
    label: "Length",
    units: {
      m: { factor: 1, label: "Meter (m)" },
      ft: { factor: 0.3048, label: "Foot (ft)" },
      km: { factor: 1000, label: "Kilometer (km)" },
      mi: { factor: 1609.344, label: "Mile (mi)" },
      cm: { factor: 0.01, label: "Centimeter (cm)" },
      mm: { factor: 0.001, label: "Millimeter (mm)" },
      in: { factor: 0.0254, label: "Inch (in)" },
      yd: { factor: 0.9144, label: "Yard (yd)" },
      nmi: { factor: 1852, label: "Nautical mile (nmi)" }
    }
  },
  mass: {
    label: "Mass",
    units: {
      kg: { factor: 1, label: "Kilogram (kg)" },
      lb: { factor: 0.45359237, label: "Pound (lb)" },
      g: { factor: 0.001, label: "Gram (g)" },
      mg: { factor: 0.000001, label: "Milligram (mg)" },
      t: { factor: 1000, label: "Metric ton (t)" },
      oz: { factor: 0.028349523125, label: "Ounce (oz)" },
      st: { factor: 6.35029318, label: "Stone (st)" }
    }
  },
  temperature: {
    label: "Temperature",
    special: "temperature",
    units: {
      C: { label: "Celsius (°C)" },
      F: { label: "Fahrenheit (°F)" },
      K: { label: "Kelvin (K)" }
    }
  },
  volume: {
    label: "Volume",
    units: {
      l: { factor: 1, label: "Liter (L)" },
      galUS: { factor: 3.785411784, label: "Gallon (US)" },
      ml: { factor: 0.001, label: "Milliliter (mL)" },
      m3: { factor: 1000, label: "Cubic meter (m³)" },
      flozUS: { factor: 0.0295735295625, label: "Fluid ounce (US)" },
      cupUS: { factor: 0.2365882365, label: "Cup (US)" },
      ptUS: { factor: 0.473176473, label: "Pint (US)" },
      qtUS: { factor: 0.946352946, label: "Quart (US)" },
      galUK: { factor: 4.54609, label: "Gallon (UK)" }
    }
  },
  area: {
    label: "Area",
    units: {
      m2: { factor: 1, label: "Square meter (m²)" },
      ft2: { factor: 0.09290304, label: "Square foot (ft²)" },
      km2: { factor: 1000000, label: "Square kilometer (km²)" },
      ha: { factor: 10000, label: "Hectare (ha)" },
      acre: { factor: 4046.8564224, label: "Acre" },
      cm2: { factor: 0.0001, label: "Square centimeter (cm²)" },
      in2: { factor: 0.00064516, label: "Square inch (in²)" },
      mi2: { factor: 2589988.110336, label: "Square mile (mi²)" }
    }
  },
  speed: {
    label: "Speed",
    units: {
      kmh: { factor: 1 / 3.6, label: "Kilometer/hour (km/h)" },
      mph: { factor: 0.44704, label: "Mile/hour (mph)" },
      mps: { factor: 1, label: "Meter/second (m/s)" },
      kn: { factor: 0.5144444444444445, label: "Knot (kn)" },
      fps: { factor: 0.3048, label: "Foot/second (ft/s)" }
    }
  },
  data: {
    label: "Data",
    units: {
      MB: { factor: 1000000, label: "Megabyte (MB)" },
      MiB: { factor: 1048576, label: "Mebibyte (MiB)" },
      GB: { factor: 1000000000, label: "Gigabyte (GB)" },
      GiB: { factor: 1073741824, label: "Gibibyte (GiB)" },
      B: { factor: 1, label: "Byte (B)" },
      KB: { factor: 1000, label: "Kilobyte (kB)" },
      KiB: { factor: 1024, label: "Kibibyte (KiB)" },
      TB: { factor: 1000000000000, label: "Terabyte (TB)" },
      TiB: { factor: 1099511627776, label: "Tebibyte (TiB)" },
      bit: { factor: 0.125, label: "Bit (b)" }
    }
  }
}

var CRYPTO_LIST = [
  { id: "bitcoin", symbol: "BTC", name: "Bitcoin" },
  { id: "ethereum", symbol: "ETH", name: "Ethereum" },
  { id: "tether", symbol: "USDT", name: "Tether" },
  { id: "binancecoin", symbol: "BNB", name: "BNB" },
  { id: "solana", symbol: "SOL", name: "Solana" },
  { id: "ripple", symbol: "XRP", name: "XRP" },
  { id: "usd-coin", symbol: "USDC", name: "USD Coin" },
  { id: "cardano", symbol: "ADA", name: "Cardano" },
  { id: "dogecoin", symbol: "DOGE", name: "Dogecoin" },
  { id: "tron", symbol: "TRX", name: "TRON" },
  { id: "litecoin", symbol: "LTC", name: "Litecoin" },
  { id: "polkadot", symbol: "DOT", name: "Polkadot" },
  { id: "chainlink", symbol: "LINK", name: "Chainlink" },
  { id: "avalanche-2", symbol: "AVAX", name: "Avalanche" },
  { id: "monero", symbol: "XMR", name: "Monero" }
]

var MAJOR_CURRENCIES = [
  "USD", "EUR", "CHF", "GBP", "JPY", "CAD", "AUD", "CNY", "INR", "BRL",
  "MXN", "SEK", "NOK", "DKK", "PLN", "CZK", "HUF", "TRY", "ZAR", "SGD",
  "HKD", "KRW", "NZD", "THB", "AED", "SAR", "ILS", "RUB", "IDR", "MYR",
  "PHP", "VND", "CLP", "COP", "PEN", "ARS", "RON", "BGN", "ISK", "UAH"
]

var CURRENCY_NAMES = {
  USD: "US Dollar", EUR: "Euro", CHF: "Swiss Franc", GBP: "British Pound",
  JPY: "Japanese Yen", CAD: "Canadian Dollar", AUD: "Australian Dollar",
  CNY: "Chinese Yuan", INR: "Indian Rupee", BRL: "Brazilian Real",
  MXN: "Mexican Peso", SEK: "Swedish Krona", NOK: "Norwegian Krone",
  DKK: "Danish Krone", PLN: "Polish Zloty", CZK: "Czech Koruna",
  HUF: "Hungarian Forint", TRY: "Turkish Lira", ZAR: "South African Rand",
  SGD: "Singapore Dollar", HKD: "Hong Kong Dollar", KRW: "South Korean Won",
  NZD: "New Zealand Dollar", THB: "Thai Baht", AED: "UAE Dirham",
  SAR: "Saudi Riyal", ILS: "Israeli Shekel", RUB: "Russian Ruble",
  IDR: "Indonesian Rupiah", MYR: "Malaysian Ringgit", PHP: "Philippine Peso",
  VND: "Vietnamese Dong", CLP: "Chilean Peso", COP: "Colombian Peso",
  PEN: "Peruvian Sol", ARS: "Argentine Peso", RON: "Romanian Leu",
  BGN: "Bulgarian Lev", ISK: "Icelandic Krona", UAH: "Ukrainian Hryvnia"
}

// Shown before the first successful rates fetch.
var FALLBACK_CURRENCIES = MAJOR_CURRENCIES

var CRYPTO_BY_ID = (function() {
  var map = {}
  for (var i = 0; i < CRYPTO_LIST.length; i++) map[CRYPTO_LIST[i].id] = CRYPTO_LIST[i]
  return map
})()

function isCrypto(key) {
  return CRYPTO_BY_ID.hasOwnProperty(key)
}

// "1 234,56" / "1_234.56" / "1,234.56" all parse. A single comma without a
// dot is a decimal separator; otherwise commas are thousands separators.
function parseAmount(text) {
  var raw = String(text === undefined || text === null ? "" : text).trim()
  if (raw === "") return NaN
  raw = raw.replace(/[\s_'’]/g, "")
  var hasDot = raw.indexOf(".") !== -1
  var firstComma = raw.indexOf(",")
  if (firstComma !== -1 && !hasDot && raw.indexOf(",", firstComma + 1) === -1) {
    raw = raw.slice(0, firstComma) + "." + raw.slice(firstComma + 1)
  } else {
    raw = raw.split(",").join("")
  }
  var value = Number(raw)
  return isFinite(value) ? value : NaN
}

// Compact human-readable result: bounded digits, no trailing zeros,
// exponential form only for absurd magnitudes.
function formatResult(value) {
  if (typeof value !== "number" || !isFinite(value)) return "—"
  var abs = Math.abs(value)
  if (abs !== 0 && (abs >= 1e12 || abs < 1e-6)) return value.toExponential(4)
  var digits = abs >= 1000 ? 2 : abs >= 1 ? 4 : 6
  var s = value.toFixed(digits)
  if (s.indexOf(".") !== -1) s = s.replace(/0+$/, "").replace(/\.$/, "")
  return s
}

function toCelsius(value, unit) {
  if (unit === "C") return value
  if (unit === "F") return (value - 32) * 5 / 9
  if (unit === "K") return value - 273.15
  return NaN
}

function fromCelsius(celsius, unit) {
  if (unit === "C") return celsius
  if (unit === "F") return celsius * 9 / 5 + 32
  if (unit === "K") return celsius + 273.15
  return NaN
}

function convertUnit(value, category, from, to) {
  var cat = UNIT_CATEGORIES[category]
  if (!cat || !cat.units.hasOwnProperty(from) || !cat.units.hasOwnProperty(to)) return NaN
  if (cat.special === "temperature") return fromCelsius(toCelsius(value, from), to)
  var f = cat.units[from].factor
  var t = cat.units[to].factor
  return value * f / t
}

function toUsd(value, key, rates, cryptoPrices) {
  if (key === "USD") return value
  if (isCrypto(key)) {
    var price = cryptoPrices && cryptoPrices[key] ? Number(cryptoPrices[key].usd) : NaN
    return isFinite(price) && price > 0 ? value * price : NaN
  }
  var rate = rates ? Number(rates[key]) : NaN
  return isFinite(rate) && rate > 0 ? value / rate : NaN
}

function fromUsd(usd, key, rates, cryptoPrices) {
  if (key === "USD") return usd
  if (isCrypto(key)) {
    var price = cryptoPrices && cryptoPrices[key] ? Number(cryptoPrices[key].usd) : NaN
    return isFinite(price) && price > 0 ? usd / price : NaN
  }
  var rate = rates ? Number(rates[key]) : NaN
  return isFinite(rate) && rate > 0 ? usd * rate : NaN
}

// Any pair (fiat or crypto on either side) via the USD pivot.
function convertCross(value, from, to, rates, cryptoPrices) {
  var usd = toUsd(value, from, rates, cryptoPrices)
  if (!isFinite(usd)) return NaN
  return fromUsd(usd, to, rates, cryptoPrices)
}

if (typeof module !== "undefined" && module.exports) {
  module.exports = {
    UNIT_CATEGORIES: UNIT_CATEGORIES,
    CRYPTO_LIST: CRYPTO_LIST,
    MAJOR_CURRENCIES: MAJOR_CURRENCIES,
    CURRENCY_NAMES: CURRENCY_NAMES,
    FALLBACK_CURRENCIES: FALLBACK_CURRENCIES,
    parseAmount: parseAmount,
    formatResult: formatResult,
    convertUnit: convertUnit,
    convertCross: convertCross,
    toUsd: toUsd,
    fromUsd: fromUsd
  }
}
