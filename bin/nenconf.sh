#!/usr/bin/env bash
####################################################################
#
# A function to construct a configuration file, based on replies
# to prompts.
#
# Prompts get suggested values which (a) can be determined by
# examining the system; or (b) are sensible defaults; or (c)
# are values read-in from the existing configuration file
#
####################################################################
SCREENSIZE=$(xdpyinfo | $GREPPROG dimensions | $SEDPROG -r 's/^[^0-9]*([0-9]+x[0-9]+).*$/\1/')
SCREENW=$(echo $SCREENSIZE | awk -Fx '{print $1}'); SCREENH=$(echo $SCREENSIZE | awk -Fx '{print $2}')
if [ -z $SCREENW ]; then SCREENW=1920; fi
if [ -z $SCREENH ]; then SCREENH=1080; fi
if ! [ -d "$CONFDIR/tmp" ]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
CONFFILE="$CONFDIR/txt/niente.conf"

# Read parameters from an existing config file, if present
# ====================================================================
if [ -f "$CONFFILE" ]; then
  confaccents=$(cat "$CONFFILE" | $GREPPROG -i UTFCHARS= | awk -F= '{print $2}'); if [ -z $confaccents ]; then confaccents='no'; fi
  confparallel=$(cat "$CONFFILE" | $GREPPROG -i PARALLELISM= | awk -F= '{print $2}'); if [ -z $confparallel ]; then confparallel=2; fi
  confdbname=$(cat "$CONFFILE" | $GREPPROG -i DBNAME= | awk -F= '{print $2}')
  confmusdir=$(cat "$CONFFILE" | $GREPPROG -i MUSICDIR= | awk -F= '{print $2}')
  confsmart=$(cat "$CONFFILE" | $GREPPROG -i SMALLART= | awk -F= '{print $2}'); if [ -z $confsmart ]; then confsmart=300; fi
  conflgart=$(cat "$CONFFILE" | $GREPPROG -i LARGEART= | awk -F= '{print $2}'); if [ -z $conflgart ]; then conflgart=1600; fi
  confsqart=$(cat "$CONFFILE" | $GREPPROG -i SQUAREART= | awk -F= '{print $2}'); if [ -z $confsqart ]; then confsqart='yes'; fi
  confmaxv=$(cat "$CONFFILE" | $GREPPROG -i VOLUMETHRESHOLD= | awk -F= '{print $2}'); if [ -z $confmaxv ]; then confmaxv=2; fi
  confrepmaxv=$(cat "$CONFFILE" | $GREPPROG -i MAXV= | awk -F= '{print $2}'); if [ -z $confrepmaxv ]; then confrepmaxv='yes'; fi
  confnbits=$(cat "$CONFFILE" | $GREPPROG -i NAMEBITS= | awk -F= '{print $2}'); if [ -z $confnbits ]; then confnbits='yes'; fi
  confbrowz=$(cat "$CONFFILE" | $GREPPROG -i BROWSER= | awk -F= '{print $2}')
  conflogosize=$(cat "$CONFFILE" | $GREPPROG -i LOGOSIZE= | awk -F= '{print $2}'); if [ -z $conflogosize ]; then conflogosize=110; elif [[ $conflogosize == *"x"* ]]; then conflogosize=$(echo "$conflogosize" | awk -Fx '{print $1}'); fi
  conflogopos=$(cat "$CONFFILE" | $GREPPROG -i LOGOPOS= | awk -F= '{print $2}'); if [ -z $conflogopos ]; then conflogopos=0; fi  
  confweztheme=$(cat "$CONFFILE" | $GREPPROG -i WEZTHEME= | awk -F= '{print $2}' | tr -d '"'); if [[ -z $confweztheme ]]; then confweztheme="Wild Cherry (Gogh)"; fi
  confwezfntsz=$(cat "$CONFFILE" | $GREPPROG -i WEZFNTSZ= | awk -F= '{print $2}'); if [[ -z $confwezfntsz ]]; then confwezfntsz=12; fi
fi

# Prompt for all parameters
# ====================================================================
dialog --backtitle "Niente Configuration File Editor" --title " Configuration Parameters " --form "" 21 95 16 \
"Default music folder " 1 1 "$confmusdir" 1 45 40 0 \
"Default music database name " 2 1 "$confdbname" 2 45 25 0 \
"Stop accented characters conversion" 3 1 "$confaccents" 3 45 6 0 \
"Default degree of parallelism " 4 1 "$confparallel" 4 45 6 0 \
"Threshold (pixels) for small art " 5 1 "$confsmart" 5 45 6 0 \
"Threshold (pixels) for large art " 6 1 "$conflgart" 6 45 6 0 \
"Should album art be square? " 7 1 "$confsqart" 7 45 6 0 \
"Threshold (dB) for volume boosts " 8 1 "$confmaxv" 8 45 6 0 \
"Report on volume boosts" 9 1 "$confrepmaxv" 9 45 6 0 \
"Report filenames without bitdepth data" 10 1 "$confnbits" 10 45 6 0 \
"Preferred browser" 11 1 "$confbrowz" 11 45 30 0 \
"Size of the Program Logo" 12 1  "$conflogosize"     12 45 9 0 \
"Program Logo position (- or +)" 13 1  "$conflogopos"     13 45 9 0 \
"Niente colour theme name" 14 1 "$confweztheme" 14 45 40 0 \
"Niente font size (in points)" 15 1 "$confwezfntsz" 15 45 6 0 \
2>"$CONFDIR/tmp/confparams"

readarray -t confparams < "$CONFDIR/tmp/confparams" 2>/dev/null

CONFMUSDIR="${confparams[0]}"
CONFDBNAME="${confparams[1]}"
CONFACCENTS="${confparams[2]}"; if [ -z "$CONFACCENTS" ]; then CONFACCENTS="no"; fi
CONFPARALLEL="${confparams[3]}"; if [ -z "$CONFCONFPARALLEL" ]; then CONFPARALLEL=2; fi
CONFSMART="${confparams[4]}"; if [ -z "$CONFSMART" ]; then CONFSMART=300; fi
CONFLGART="${confparams[5]}"; if [ -z "$CONFLGART" ]; then CONFLGART=1600; fi
CONFSQART="${confparams[6]}"; if [ -z "$CONFSQART" ]; then CONFSQART="yes"; fi
CONFMAXV="${confparams[7]}"; if [ -z "$CONFMAXV" ]; then CONFMAXV=2; fi
CONFREPMAXV="${confparams[8]}"; if [ -z "$CONFREPMAXV" ]; then CONFREPMAXV=yes; fi
CONFNBITS="${confparams[9]}"; if [ -z "$CONFNBITS" ]; then CONFNBITS=yes; fi
CONFBROWZ="${confparams[10]}"
CONFLOGOSIZE="${confparams[11]}"
  if [[ $CONFLOGOSIZE =~ ^[0-9]+$ ]] && (( 10#$CONFLOGOSIZE >= 100 )); then CONFLOGOSIZE=$((10#$CONFLOGOSIZE)); else CONFLOGOSIZE=110; fi   # At least 100: default 110
  CONFLOGOSIZE=$CONFLOGOSIZE"x"$CONFLOGOSIZE
CONFLOGOPOS="${confparams[12]}"
  if [[ $((CONFLOGOPOS)) != "$CONFLOGOPOS" ]]; then CONFLOGOPOS=0; fi
CONFWEZTHEME="${confparams[13]}"; CONFWEZTHEME="${CONFWEZTHEME//\"/}"        # WezTerm colour scheme: no double quotes, as it's written in quotes
  if [[ -z $CONFWEZTHEME ]]; then CONFWEZTHEME="Wild Cherry (Gogh)"; fi
CONFWEZFNTSZ="${confparams[14]}"
  if [[ $CONFWEZFNTSZ =~ ^[0-9]+$ ]] && (( 10#$CONFWEZFNTSZ >= 8 && 10#$CONFWEZFNTSZ <= 32 )); then CONFWEZFNTSZ=$((10#$CONFWEZFNTSZ)); else CONFWEZFNTSZ=12; fi   # 8 to 32 points: default 12

# WezTerm's own settings file for Niente gets the colour scheme and font size, as Giocoso's and Semplice's do
if [[ -f $HOME/.niente.lua ]]; then
  WEZSED="${CONFWEZTHEME//\\/\\\\}"; WEZSED="${WEZSED//&/\\&}"; WEZSED="${WEZSED//|/\\|}"
  $SEDPROG -i "s|^config\.color_scheme = '.*'\$|config.color_scheme = '$WEZSED'|" "$HOME/.niente.lua"
  $SEDPROG -i "s|^config\.font_size = .*\$|config.font_size = $CONFWEZFNTSZ|" "$HOME/.niente.lua"
fi

# Check for legal values and replace with defaults if not legal
# ====================================================================
# Numeric parameters must, if set at all, be actual numbers
NUM='^[0-9]+$'
if ! [[ $CONFPARALLEL =~ $NUM ]] ; then CONFPARALLEL=2; fi
if ! [[ $CONFSMART =~ $NUM ]] ; then CONFSMART=300; fi
if ! [[ $CONFLGART =~ $NUM ]] ; then CONFLGART=1600; fi
if ! [[ $CONFMAXV =~ $NUM ]] ; then CONFMAXV=2; fi

# Yes/No parameters must, if set at all, be either 'yes' or 'no', all in lower case
if [[ ${CONFACCENTS,,} == "yes" ]] || [[ ${CONFACCENTS,,} == "no" ]]; then CONFACCENTS=${CONFACCENTS,,}; else CONFACCENTS="no"; fi
if [[ ${CONFSQART,,} == "yes" ]] || [[ ${CONFSQART,,} == "no" ]]; then CONFSQART=${CONFSQART,,}; else CONFSQART="yes"; fi
if [[ ${CONFNBITS,,} == "yes" ]] || [[ ${CONFNBITS,,} == "no" ]]; then CONFNBITS=${CONFNBITS,,}; else CONFNBITS="yes"; fi
if [[ ${CONFREPMAXV,,} == "yes" ]] || [[ ${CONFREPMAXV,,} == "no" ]]; then CONFREPMAXV=${CONFREPMAXV,,}; else CONFREPMAXV="yes"; fi

# If large and small art thresholds are the wrong way round, reverse them
if [ $CONFSMART -gt $CONFLGART ]; then TMPART=$CONFSMART; CONFSMART=$CONFLGART; CONFLGART=$TMPART; fi

echo "# New Niente Configuration File, created $(date)
# ====================================================================

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
UTFCHARS=$CONFACCENTS
PARALLELISM=$CONFPARALLEL
BROWSER=$CONFBROWZ
LOGOSIZE=$CONFLOGOSIZE
LOGOPOS=$CONFLOGOPOS
WEZTHEME=\"$CONFWEZTHEME\"
WEZFNTSZ=$CONFWEZFNTSZ

# Database Parameters
# ====================================================================
DBNAME=$CONFDBNAME
MUSICDIR=$CONFMUSDIR

# Reporting threshold/limit parameters
# ====================================================================
SMALLART=$CONFSMART
LARGEART=$CONFLGART
SQUAREART=$CONFSQART
VOLUMETHRESHOLD=$CONFMAXV
NAMEBITS=$CONFNBITS
REPORTMAXV=$CONFREPMAXV" > "$CONFDIR/txt/niente.conf"

rm -f "$CONFDIR/tmp/confparams" 2>/dev/null
"$CONVPROG" "$CONFDIR/art/nienteicobeta.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/nienteicosmallbeta.png" 2>/dev/null     # The small menu logos, at the (perhaps new) size
"$CONVPROG" "$CONFDIR/art/nienteico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/nienteicosmall.png" 2>/dev/null
source "$CONFDIR/bin/nenparse.sh"
