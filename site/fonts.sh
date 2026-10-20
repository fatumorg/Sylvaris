#!/usr/bin/env bash
set -euo pipefail
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$here/assets/fonts"
mkdir -p "$out"
py="$(nix build --no-link --print-out-paths --impure --expr '((builtins.getFlake "nixpkgs").legacyPackages.${builtins.currentSystem}).python3.withPackages (p: [ p.fonttools p.brotli ])')"
spdx="$(nix build --no-link --print-out-paths nixpkgs#spdx-license-list-data.text)"
pkg() { nix build --no-link --print-out-paths "nixpkgs#$1"; }
fraunces="$(pkg fraunces)/share/fonts/opentype"
atkinson="$(pkg atkinson-hyperlegible-next)/share/fonts/opentype"
jetbrains="$(pkg jetbrains-mono)/share/fonts/opentype"
unicodes="U+0020-007E,U+00A0-00FF,U+0100-017F,U+2010-2027,U+2030-203A,U+2039-203A,U+20AC,U+2122,U+2190-2193,U+2212,U+2260,U+2264-2265"
subset() {
    "$py/bin/pyftsubset" "$1" --output-file="$out/$2.woff2" --flavor=woff2 --unicodes="$unicodes" --layout-features+=ss01,ss02,zero --name-IDs='*'
}
subset "$fraunces/Fraunces144pt-SemiBold.otf" fraunces-600
subset "$fraunces/Fraunces144pt-LightItalic.otf" fraunces-300i
subset "$atkinson/AtkinsonHyperlegibleNext-Regular.otf" atkinson-400
subset "$atkinson/AtkinsonHyperlegibleNext-Italic.otf" atkinson-400i
subset "$atkinson/AtkinsonHyperlegibleNext-Bold.otf" atkinson-700
subset "$jetbrains/JetBrainsMono-Regular.otf" jetbrains-400
{
    printf 'The fonts in this folder are subsets of these families, each under the SIL Open Font License 1.1 below.\n\n'
    for f in "$fraunces/Fraunces144pt-SemiBold.otf" "$atkinson/AtkinsonHyperlegibleNext-Regular.otf" "$jetbrains/JetBrainsMono-Regular.otf"; do
        "$py/bin/python3" -c 'import sys; from fontTools.ttLib import TTFont; n = TTFont(sys.argv[1])["name"]; print(n.getDebugName(1) + ": " + n.getDebugName(0))' "$f"
    done
    printf '\n'
    cat "$(find "$spdx" -name OFL-1.1.txt | head -1)"
} >"$out/OFL.txt"
