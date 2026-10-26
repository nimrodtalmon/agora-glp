#!/bin/bash
# Registers the AGORA contract in the GLP repository's cascade.sh (one case line),
# so that `bash cascade.sh agora` runs the whole cascade on it, plays included.
set -e
G="${1:-.}"
grep -q '^    agora)' "$G/cascade.sh" && exit 0
sed -i '/^    gai)  FILE=GAI;/a\    agora) FILE=AGORA; OWNER="programs/agora";          PAPER="";                          PLAYDIR="agora"; PLAYLIMIT=100000000 ;;' "$G/cascade.sh"
grep -q '^    agora)' "$G/cascade.sh"
