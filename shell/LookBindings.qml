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
}
