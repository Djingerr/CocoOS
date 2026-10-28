#!/usr/bin/env bash
# Planche de 12 images d'une animation du harnais, au format de ../reference/filmstrip/ :
# l'instant k vaut k × cycle / 12 (après `start` ms, le temps que l'accueil finisse d'entrer).
#
#   ./filmstrip.sh /tmp/nav.png 10200 view=HomeDemo order=ha,ce,hk,mc,fh,sv,er,zl,p2 start=1500 \
#       script=1600:right,3160:right,…
#   (puis la comparer à ../reference/filmstrip/MotionNavigation.png, côte à côte)
set -euo pipefail
here="$(cd "$(dirname "$0")" && pwd)"
out="$1"; cycle="$2"; shift 2
start=0
for a in "$@"; do case "$a" in start=*) start="${a#start=}";; esac; done
tmp="$(mktemp -d)"
trap 'rm -rf "$tmp"' EXIT
for k in $(seq 0 11); do
    t=$(( k * cycle / 12 ))
    "$here/shot.sh" "$tmp/$k.png" delay=$(( start + t )) "$@"
    label=$(printf '00:00:%02d.%03d' $(( t / 1000 )) $(( t % 1000 )))
    magick "$tmp/$k.png" -resize 320x200 -fill white -pointsize 16 -annotate +12+20 "$label" "$tmp/s$k.png"
done
magick montage $(for k in $(seq 0 11); do echo "$tmp/s$k.png"; done) -tile 4x3 -geometry 320x200+1+1 -background black "$out"
