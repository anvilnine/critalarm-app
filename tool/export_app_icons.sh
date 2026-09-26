#!/bin/sh
# Renders the three Pro app icons from their SVG masters in assets/icon/src.
#
# The default icon still comes from flutter_launcher_icons (see pubspec.yaml),
# which has no idea alternate icons exist. This covers the other three:
#
#   iOS      ios/Runner/Assets.xcassets/AppIconPro*.appiconset, one 1024 image
#            each, opaque, square. iOS draws the rounded corners itself.
#   Android  mipmap-*/ic_launcher_pro_*.png for launchers without adaptive
#            icons, and drawable-*/ic_launcher_foreground_pro_*.png for the
#            adaptive icon. The background colour and the monochrome layer are
#            shared with the default icon, so they are not exported here.
#   Picker   assets/app_icons/*.png, the tiles on the App icon screen. The
#            default icon gets one too, so the four tiles match.
#
# Needs rsvg-convert (librsvg): `brew install librsvg` or
# `apt-get install librsvg2-bin`. Run it after editing any SVG in
# assets/icon/src and commit what it writes.
set -eu

cd "$(dirname "$0")/.."

command -v rsvg-convert >/dev/null 2>&1 || {
  echo "rsvg-convert not found. Install librsvg (brew install librsvg)." >&2
  exit 1
}

SRC=assets/icon/src
RES=android/app/src/main/res
XCASSETS=ios/Runner/Assets.xcassets
BACKGROUND='#FF8A1F'
TMP=$(mktemp -d)
trap 'rm -rf "$TMP"' EXIT

# The masters carry the rounded badge the site shows. The stores want a full
# square, and Android's adaptive foreground wants no background at all.
square() {
  sed -e 's/ clip-path="url(#squircle)"//' \
    -e '/id="badge-bg"/s/ rx="230" ry="230"//' "$1"
}
foreground() {
  sed -e 's/ clip-path="url(#squircle)"//' -e '/id="badge-bg"/d' "$1"
}

# name in the SVG file, name of the iOS icon set, Android resource suffix.
while read -r svg set suffix; do
  square "$SRC/$svg.svg" >"$TMP/square.svg"
  foreground "$SRC/$svg.svg" >"$TMP/foreground.svg"

  if [ "$set" != "-" ]; then
    dir="$XCASSETS/$set.appiconset"
    mkdir -p "$dir"
    rsvg-convert -w 1024 -h 1024 -b "$BACKGROUND" "$TMP/square.svg" \
      -o "$dir/Icon-1024.png"
    cat >"$dir/Contents.json" <<JSON
{
  "images" : [
    {
      "filename" : "Icon-1024.png",
      "idiom" : "universal",
      "platform" : "ios",
      "size" : "1024x1024"
    }
  ],
  "info" : {
    "author" : "xcode",
    "version" : 1
  }
}
JSON

    for density in mdpi:48:108 hdpi:72:162 xhdpi:96:216 xxhdpi:144:324 xxxhdpi:192:432; do
      name=${density%%:*}
      sizes=${density#*:}
      legacy=${sizes%%:*}
      adaptive=${sizes#*:}
      rsvg-convert -w "$legacy" -h "$legacy" -b "$BACKGROUND" "$TMP/square.svg" \
        -o "$RES/mipmap-$name/ic_launcher_$suffix.png"
      rsvg-convert -w "$adaptive" -h "$adaptive" "$TMP/foreground.svg" \
        -o "$RES/drawable-$name/ic_launcher_foreground_$suffix.png"
    done

    cat >"$RES/mipmap-anydpi-v26/ic_launcher_$suffix.xml" <<XML
<?xml version="1.0" encoding="utf-8"?>
<adaptive-icon xmlns:android="http://schemas.android.com/apk/res/android">
  <background android:drawable="@color/ic_launcher_background"/>
  <foreground>
      <inset
          android:drawable="@drawable/ic_launcher_foreground_$suffix"
          android:inset="16%" />
  </foreground>
  <monochrome>
      <inset
          android:drawable="@drawable/ic_launcher_monochrome"
          android:inset="16%" />
  </monochrome>
</adaptive-icon>
XML
  fi

  mkdir -p assets/app_icons
  rsvg-convert -w 192 -h 192 -b "$BACKGROUND" "$TMP/square.svg" \
    -o "assets/app_icons/$svg.png"
done <<LIST
app_icon - -
app_icon_pro_crowned AppIconProCrowned pro_crowned
app_icon_pro_shades AppIconProShades pro_shades
app_icon_pro_shades_crown AppIconProShadesCrown pro_shades_crown
LIST

echo "Exported the Pro app icons and the picker tiles."
