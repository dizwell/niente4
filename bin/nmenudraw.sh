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
tput cup 11 60; echo " | |\  | |  __/ | | | ||  4̲_/ "
tput cup 12 60; echo " |_| \_|_|\___|_| |_|\__\___| "
}

function sixel_logo {
wordlogo
tput cup 14 59; tput setaf $SPINNER; echo -en "♬♪ "; tput setaf $INFOTEXT; echo -en "The Music Integrity Manager"; tput setaf $SPINNER; echo -en " ♬♪"
tput cup 16 $LOGO_POSITION; "$SIXEL" -w "${LOGOSIZE%x*}" "$LOGO_PATH" 2>/dev/null; printf "%s\n"
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

if [[ -z $LOGOSIZE ]]; then LOGOSIZE="110x110"; fi

if [[ -z $LOGOPOS ]]; then LOGOPOS=0; fi
LOGO_POSITION=$((70 + $LOGOPOS ))      # Centred in the right-hand panel at the default size (as Giocoso and Semplice)

tput cup  1 4; tput setaf $LOGO; echo "♬♪ Niente: The Digital Music Integrity Manager ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT, Version $PROGVERSION"

sixel_logo