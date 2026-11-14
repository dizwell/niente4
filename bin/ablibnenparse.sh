#!/usr/bin/env bash
####################################################################
#
# ablibnenparse: routine for parsing the persistent configuration
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

  # The Use Kitty Graphics parameter, if set, should be yes or no, defaulting to no.
  if [[ -z $USEKITTY ]]; then
    USEKITTY=0
  elif  [[ ${USEKITTY^^} == YES ]]; then
    USEKITTY=1
  else
    USEKITTY=0
  fi
  
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
USEKITTY=no
LOGOSIZE=220
LOGOPOS=0

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
