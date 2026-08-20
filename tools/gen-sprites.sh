#!/usr/bin/env bash
# Convert the 16x16 text grids in tools/sprites/ into white-on-transparent
# PNGs in assets/sprites/. Requires ImageMagick. Dev-only: the generated
# PNGs are committed, users never run this.
set -euo pipefail
cd "$(dirname "$0")/sprites"
out="../../assets/sprites"

for txt in *.txt; do
  name="${txt%.txt}"
  { echo "P1"; echo "16 16"; tr 'X.' '10' < "$txt"; } > "/tmp/omagotchi-$name.pbm"
  magick "/tmp/omagotchi-$name.pbm" -transparent white -fill '#FFFFFF' -opaque black "PNG32:$out/$name.png"
  rm "/tmp/omagotchi-$name.pbm"
  echo "$out/$name.png"
done
