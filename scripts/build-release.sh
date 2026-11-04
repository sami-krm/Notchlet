#!/bin/bash
# Construit l'app de diffusion et son zip dans build/, puis vérifie le résultat.
# L'app reste signée en ad hoc : voir la section Installation du README.
set -euo pipefail

cd "$(dirname "$0")/.."
OUTPUT="build"
APP="$OUTPUT/DerivedData/Build/Products/Release/Notchlet.app"

rm -rf "$OUTPUT"
xcodebuild build -quiet \
    -project Notchlet.xcodeproj -scheme Notchlet -configuration Release \
    -destination 'generic/platform=macOS' -derivedDataPath "$OUTPUT/DerivedData"

fail() { echo "ÉCHEC : $1" >&2; exit 1; }

plist="$APP/Contents/Info.plist"
version=$(/usr/libexec/PlistBuddy -c 'Print :CFBundleShortVersionString' "$plist")
[ "$(/usr/libexec/PlistBuddy -c 'Print :CFBundleIdentifier' "$plist")" = "com.samikrim.Notchlet" ] || fail "identifiant inattendu"
[ "$(/usr/libexec/PlistBuddy -c 'Print :LSMinimumSystemVersion' "$plist")" = "13.0" ] || fail "version minimale de macOS inattendue"

archs=$(lipo -archs "$APP/Contents/MacOS/Notchlet")
case "$archs" in *arm64*) ;; *) fail "architecture arm64 absente" ;; esac
case "$archs" in *x86_64*) ;; *) fail "architecture x86_64 absente" ;; esac

# Un certificat personnel exposerait son adresse e-mail dans l'app publique.
signature=$(codesign -dv "$APP" 2>&1)
case "$signature" in *"Signature=adhoc"*) ;; *) fail "l'app doit être signée en ad hoc" ;; esac
codesign --verify --deep --strict "$APP" || fail "signature invalide"

ZIP="$OUTPUT/Notchlet-$version.zip"
# `ditto` conserve la signature et les attributs de l'app, contrairement à d'autres outils.
ditto -c -k --sequesterRsrc --keepParent "$APP" "$ZIP"

echo "Paquet prêt : $ZIP ($(du -h "$ZIP" | cut -f1), $archs)"
shasum -a 256 "$ZIP"
