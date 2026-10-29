import QtQuick
import SylStack
import qs.services

Scope {
    Binding {
        target: Tokens
        property: "radiusScale"
        value: Look.radius
    }

    Binding {
        target: Tokens
        property: "corners"
        value: Look.corners
    }

    Binding {
        target: Tokens
        property: "densityScale"
        value: Look.density
    }

    Binding {
        target: Tokens
        property: "fontUiName"
        value: Look.fonts.ui
    }

    Binding {
        target: Tokens
        property: "fontMonoName"
        value: Look.fonts.mono
    }

    Binding {
        target: Tokens
        property: "fontDisplayName"
        value: Look.fonts.display
    }

    Binding {
        target: Tokens
        property: "titleWeight"
        value: Look.weight
    }

    Binding {
        target: Tokens
        property: "toggleStyle"
        value: Look.values.controls.toggle
    }

    Binding {
        target: Tokens
        property: "sliderStyle"
        value: Look.values.controls.slider
    }

    Binding {
        target: Tokens
        property: "segmentedStyle"
        value: Look.values.controls.segmented
    }

    Binding {
        target: Tokens
        property: "buttonStyle"
        value: Look.values.controls.button
    }

    Binding {
        target: Tokens
        property: "cardStyle"
        value: Look.values.controls.card
    }

    Binding {
        target: Tokens
        property: "hoverStyle"
        value: Look.values.controls.hover
    }

    Binding {
        target: Tokens
        property: "iconStyle"
        value: Look.values.controls.icon
    }

    Binding {
        target: Tokens
        property: "dividerStyle"
        value: Look.values.controls.divider
    }

    Binding {
        target: Tokens
        property: "labelCase"
        value: Look.labelCase
    }

    Binding {
        target: Tokens
        property: "tracking"
        value: Look.values.tracking
    }

    Binding {
        target: Tokens
        property: "borderWidth"
        value: Look.values.border
    }

    Binding {
        target: Tokens
        property: "accentStrength"
        value: Look.values.accentStrength
    }
}
