#!/usr/bin/env bash
####################################################################
# smenudraw: Clear screen drawing routine
####################################################################
source "$CONFDIR/bin/nenparse.sh"
source "$CONFDIR/bin/nentput.sh"
if [[ $PROGVERSION == *"beta"* ]]; then LOGO_PATH="$CONFDIR/art/nienteicosmallbeta.png"; else LOGO_PATH="$CONFDIR/art/nienteicosmall.png"; fi
clear; tput cup 0 0

function wordlogo { 
tput setaf $LOGO 
tput cup  8 60; echo "  _   _ _            _        "
tput cup  9 60; echo " | \ | (_) ___ _ __ | |_ ___  "
tput cup 10 60; echo " |  \| | |/ _ \ '_ \| __/ _ \ "
tput cup 11 60; echo " | |\  | |  __/ | | | || 4̲__/ "
tput cup 12 60; echo " |_| \_|_|\___|_| |_|\__\___| "
}

function kitty_logo {
wordlogo
tput cup 14 59; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $INFOTEXT; echo -en "The Music Integrity Checker"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 16 68; 

# 1. Capture dimensions and split into variables
IFS='x' read -r PX_W PX_H COLS ROWS < <(kitty +kitten icat --print-window-size)

# 2. Calculate pixel width of a single cell
# Uses 10 as a fallback to prevent division by zero
PX_PER_COL=$(( ${PX_W:-1000} / ${COLS:-100} ))

# 3. Set coordinates and calculate cell-based width for ~220 pixels
IMAGE_LEFT=$LOGO_POSITION
IMAGE_TOP=16
IMAGE_CELL_COLS=$(( 220 / PX_PER_COL ))

# 4. Set rows high to ensure width is the constraining factor for aspect ratio
IMAGE_CELL_ROWS=99

# 5. Execute
kitty +kitten icat --place "${IMAGE_CELL_COLS}x${IMAGE_CELL_ROWS}@${IMAGE_LEFT}x${IMAGE_TOP}" "$LOGO_PATH"
}

function sixel_logo {
wordlogo
tput cup 14 59; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $INFOTEXT; echo -en "The Music Integrity Manager"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 16 $LOGO_POSITION; img2sixel "$LOGO_PATH" 2>/dev/null; printf "%s\n"
}

if [ "$1" == "short" ]; then
  tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
elif  [ "$1" == "playing" ]; then
  tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
else
  tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
├───────────────────────────────────────────────────────────────────────────────────────────────────┤
│                                                                                                   │
├─────────────────────────────────────────────────┬─────────────────────────────────────────────────┤
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
│                                                 │                                                 │
├─────────────────────────────────────────────────┴─────────────────────────────────────────────────┤
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
fi

if [[ -z $LOGOSIZE ]]; then LOGOSIZE="220x220"; fi
# The small menu logos (release and beta) are made on each computer from the full-size icons, at the configured size
for smalllogo in nienteico nienteicobeta; do
  if ! [[ -f "$CONFDIR/art/${smalllogo/ico/icosmall}.png" ]]; then
    if [[ $CONVPROG == convert ]]; then
      convert "$CONFDIR/art/$smalllogo.png" -resize "$LOGOSIZE" "$CONFDIR/art/${smalllogo/ico/icosmall}.png" 2>/dev/null
    elif [[ $CONVPROG == magick ]]; then
      magick "$CONFDIR/art/$smalllogo.png" -resize "$LOGOSIZE" "$CONFDIR/art/${smalllogo/ico/icosmall}.png" 2>/dev/null
    fi
  fi
done
unset smalllogo

if [[ -z $LOGOPOS ]]; then LOGOPOS=0; fi
LOGO_POSITION=$((69 + $LOGOPOS ))

tput cup  1 4; tput setaf $LOGO; echo "♬♪ Niente: The Digital Music Integrity Checker ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © Howard Rogers 2021-2025, Version $PROGVERSION"

if [[ $USEKITTY -eq 1 ]]; then
  kitty_logo
else
  sixel_logo
fi