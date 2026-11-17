#!/usr/bin/env bash
####################################################################
#
# nenparse: routine for parsing the persistent configuration
# file and deriving sensible values from whatever is supplied there.
#
####################################################################
NUM='^[0-9]+$'

if [ -f "$CONFDIR/txt/niente.conf" ]; then
  source "$CONFDIR/txt/niente.conf"                       # Read the configuration file and pick up all its values

  # If UTFCHARS is set, check yes or no, interpreted as 1 or 0, and set to 0 by default if not
  # -----------------------------------------------------------------------------
  if [ ! -z $UTFCHARS ]; then
    if [[ ${UTFCHARS,,} == "yes" ]] ; then
      UTFCHARS="--no-utf8-convert"
    else
      UTFCHARS=""
    fi
  else
    UTFCHARS=""
  fi

  # If PARALLELISM is set, check it's numeric and set to 2 by default if not
  # -----------------------------------------------------------------------------
  if [ ! -z $PARALLELISM ]; then
    if ! [[ $PARALLELISM =~ $NUM ]] ; then
      PARALLELISM=2
    fi
  else
    PARALLELISM=2
  fi

  # If SMALLART or LARGEART dimensions have been supplied, make sure they
  # are valid numbers and change them to defaults (300 and 1600) if not.
  # -----------------------------------------------------------------------------
  if [ ! -z $SMALLART ]; then
    if ! [[ $SMALLART =~ $NUM ]] ; then
      SMALLART=300
    fi
  else
    SMALLART=300
  fi

  if [ ! -z $LARGEART ]; then
    if ! [[ $LARGEART =~ $NUM ]] ; then
      LARGEART=1600
    fi
  else
    LARGEART=1600
  fi

  # If large and small art thresholds are the wrong way round, reverse them
  if [ $SMALLART -gt $LARGEART ]; then TMPART=$SMALLART; SMALLART=$LARGEART; LARGEART=$TMPART; fi

  # If SQUAREART is set, check yes or no, interpreted as 1 or 0, and set to 1 by default if not
  if [ ! -z $SQUAREART ]; then
    if [[ ${SQUAREART,,} == "no" ]] ; then
      SQUAREART=0
    else
      SQUAREART=1
    fi
  else
    SQUAREART=1
  fi

  # If VOLUMETHRESHOLD is set, check it's numeric and set to 2 by default if not.
  if [ ! -z $VOLUMETHRESHOLD ]; then
    if ! [[ $VOLUMETHRESHOLD =~ $NUM ]] ; then
      VOLUMETHRESHOLD=2
    fi
  else
    VOLUMETHRESHOLD=2
  fi

  # Dialog colour theme: must be one of the supplied themes (anything else, including blank, gets 'standard'), as in
  # Giocoso and Semplice. Exported here, so a theme chosen in the configuration editor takes effect as soon as it is saved.
  if [[ ${DIATHEME,,} =~ ^(standard|red|green|yellow|magenta)$ ]]; then DIATHEME=${DIATHEME,,}; else DIATHEME=standard; fi
  export DIALOGRC="$CONFDIR/txt/$DIATHEME.conf"

  # The logo size must be a whole number of pixels from 100 to 400 (written as NxN): anything else gives the default, 110
  LOGOSIZE="${LOGOSIZE%%x*}"
  if [[ $LOGOSIZE =~ ^[0-9]{1,4}$ ]] && (( 10#$LOGOSIZE >= 100 && 10#$LOGOSIZE <= 400 )); then LOGOSIZE="$((10#$LOGOSIZE))x$((10#$LOGOSIZE))"; else LOGOSIZE="110x110"; fi

  # The small menu logos (release and beta) are made from the full-size icons with the bundled ImageMagick, if
  # they don't exist yet; saving the configuration makes them again at the configured size
  for smalllogo in nienteico nienteicobeta; do
    if [[ ! -f "$CONFDIR/art/${smalllogo/ico/icosmall}.png" && -x $CONVPROG ]]; then
      "$CONVPROG" "$CONFDIR/art/$smalllogo.png" -resize "$LOGOSIZE" "$CONFDIR/art/${smalllogo/ico/icosmall}.png" 2>/dev/null
    fi
  done
  unset smalllogo

else
echo "# New Niente Configuration File, created $(date),
# Colour Constants (alter at your peril!)
# ====================================================================	
HOTKEY=11
DRAWLINES=2
MAINTEXT=15
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

# General Parameters
# ====================================================================
UTFCHARS=yes
PARALLELISM=0
BROWSER=
LOGOSIZE=110
LOGOPOS=0
WEZTHEME=\"Wild Cherry (Gogh)\"
WEZFNTSZ=12
DIATHEME=\"standard\"

# Database Parameters
# ====================================================================
DBNAME=niente
MUSICDIR=$HOME/Music/classical

# Reporting threshold/limit parameters
# ====================================================================
SMALLART=300
LARGEART=1600
SQUAREART=1
VOLUMETHRESHOLD=2
NAMEBITS=yes
REPORTMAXV=yes
" > "$CONFDIR/txt/niente.conf"
  chmod 775 "$CONFDIR/txt/niente.conf"
  parse_config
fi
