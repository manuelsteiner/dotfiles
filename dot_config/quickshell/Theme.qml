pragma Singleton
import Quickshell
import QtQuick

Singleton {
    readonly property color base:          "#191724"
    readonly property color surface:       "#1f1d2e"
    readonly property color overlay:       "#26233a"
    readonly property color muted:         "#6e6a86"
    readonly property color subtle:        "#908caa"
    readonly property color text:          "#e0def4"
    readonly property color love:          "#eb6f92"
    readonly property color loveDim:       "#c04a6e"
    readonly property color gold:          "#f6c177"
    readonly property color goldDim:       "#d4a844"
    readonly property color rose:          "#ebbcba"
    readonly property color roseDim:       "#c49896"
    readonly property color pine:          "#31748f"
    readonly property color pineDim:       "#245568"
    readonly property color foam:          "#9ccfd8"
    readonly property color foamDim:       "#74a8b0"
    readonly property color iris:          "#c4a7e7"
    readonly property color irisDim:       "#9c7ec0"

    readonly property color accent:    _accentMap[Config.accentColor] ?? gold
    readonly property color accentDim: _accentDimMap[Config.accentColor] ?? goldDim

    readonly property var _accentMap: ({
        "love": love, "gold": gold, "rose": rose,
        "pine": pine, "foam": foam, "iris": iris
    })
    readonly property var _accentDimMap: ({
        "love": loveDim, "gold": goldDim, "rose": roseDim,
        "pine": pineDim, "foam": foamDim, "iris": irisDim
    })

    readonly property color volumeColor:      _accentMap[Config.volumeAccent] ?? iris
    readonly property color microphoneColor:   _accentMap[Config.microphoneAccent] ?? iris
    readonly property color bluetoothColor:    _accentMap[Config.bluetoothAccent] ?? foam
    readonly property color ethernetColor:     _accentMap[Config.ethernetAccent] ?? pine
    readonly property color wirelessColor:     _accentMap[Config.wirelessAccent] ?? pine
    readonly property color wireguardColor:    _accentMap[Config.wireguardAccent] ?? pine
    readonly property color brightnessColor:   _accentMap[Config.brightnessAccent] ?? gold
    readonly property color notificationColor: _accentMap[Config.notificationAccent] ?? rose
    readonly property color powerColor:        _accentMap[Config.powerAccent] ?? love
    readonly property color urgentColor:       _accentMap[Config.urgentAccent] ?? love
    readonly property color highlightLow:  "#21202e"
    readonly property color highlightMed:  "#403d52"
    readonly property color highlightHigh: "#524f67"
}
