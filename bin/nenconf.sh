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
if ! [ -d "$CONFDIR/tmp" ]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
CONFFILE="$CONFDIR/txt/niente.conf"

function conf_text {
# Print the value of key $1 from the config file, minus any surrounding double quotes (as Giocoso's editor does);
# copes with '=' inside a value, and only matches the key at the start of a line
$GREPPROG -i -m1 "^$1=" "$CONFFILE" | $SEDPROG -e 's/^[^=]*=//' -e 's/^"//' -e 's/"$//'
}

# Read parameters from an existing config file, if present
# ====================================================================
if [ -f "$CONFFILE" ]; then
  confaccents=$(conf_text UTFCHARS); if [ -z $confaccents ]; then confaccents='no'; fi
  confdbname=$(conf_text DBNAME)
  confmusdir=$(conf_text MUSICDIR)
  confsmart=$(conf_text SMALLART); if [ -z $confsmart ]; then confsmart=300; fi
  conflgart=$(conf_text LARGEART); if [ -z $conflgart ]; then conflgart=1600; fi
  confsqart=$(conf_text SQUAREART); if [ -z $confsqart ]; then confsqart='yes'; fi
  confmaxv=$(conf_text VOLUMETHRESHOLD); if [ -z $confmaxv ]; then confmaxv=2; fi
  confrepmaxv=$(conf_text REPORTMAXV); if [ -z $confrepmaxv ]; then confrepmaxv='yes'; fi
  confnbits=$(conf_text NAMEBITS); if [ -z $confnbits ]; then confnbits='yes'; fi
  confbrowz=$(conf_text BROWSER)
  conflogosize=$(conf_text LOGOSIZE); if [ -z $conflogosize ]; then conflogosize=110; elif [[ $conflogosize == *"x"* ]]; then conflogosize=$(echo "$conflogosize" | awk -Fx '{print $1}'); fi
  conflogopos=$(conf_text LOGOPOS); if [ -z $conflogopos ]; then conflogopos=0; fi  
  confweztheme=$(conf_text WEZTHEME); if [[ -z $confweztheme ]]; then confweztheme="Wild Cherry (Gogh)"; fi
  confwezfntsz=$(conf_text WEZFNTSZ); if [[ -z $confwezfntsz ]]; then confwezfntsz=12; fi
  confdiatheme=$(conf_text DIATHEME); if [[ -z $confdiatheme ]]; then confdiatheme="standard"; fi
fi

# Prompt for the parameters: two pages, so that each fits on screen. OK on the first page moves on to the second;
# OK on the second saves both. Cancel or Esc on either page changes nothing at all: the configuration file (and
# ~/.niente.lua and the logos) stay exactly as they were.
# ====================================================================
dialog --backtitle "Niente Configuration File Editor" --title " Program Configuration " --form "Program Settings:" 17 90 10 \
"Default music folder " 1 1 "$confmusdir" 1 45 40 0 \
"Default music database name " 2 1 "$confdbname" 2 45 25 0 \
"Stop accented characters conversion" 3 1 "$confaccents" 3 45 6 0 \
"Preferred browser" 4 1 "$confbrowz" 4 45 30 0 \
"Size of the Program Logo" 5 1  "$conflogosize"     5 45 9 0 \
"Program Logo position (- or +)" 6 1  "$conflogopos"     6 45 9 0 \
"Niente colour theme name" 7 1 "$confweztheme" 7 45 40 0 \
"Niente font size (in points)" 8 1 "$confwezfntsz" 8 45 6 0 \
"Dialog colour theme name" 9 1 "$confdiatheme" 9 45 10 0 \
2>"$CONFDIR/tmp/confparams"
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  rm -f "$CONFDIR/tmp/confparams" 2>/dev/null
  return
fi
readarray -t progparams < "$CONFDIR/tmp/confparams" 2>/dev/null

dialog --backtitle "Niente Configuration File Editor" --title " Program Configuration " --form "Reporting Settings:" 17 90 10 \
"Threshold (pixels) for small art " 1 1 "$confsmart" 1 45 6 0 \
"Threshold (pixels) for large art " 2 1 "$conflgart" 2 45 6 0 \
"Should album art be square? " 3 1 "$confsqart" 3 45 6 0 \
"Threshold (dB) for volume boosts " 4 1 "$confmaxv" 4 45 6 0 \
"Report on volume boosts" 5 1 "$confrepmaxv" 5 45 6 0 \
"Report filenames without bitdepth data" 6 1 "$confnbits" 6 45 6 0 \
2>"$CONFDIR/tmp/confparams"
exitStatus=$?
if [[ $exitStatus -eq 1 || $exitStatus -eq 255 ]]; then
  rm -f "$CONFDIR/tmp/confparams" 2>/dev/null
  return
fi
readarray -t reptparams < "$CONFDIR/tmp/confparams" 2>/dev/null

CONFMUSDIR="${progparams[0]}"
CONFDBNAME=$(clean_dbname "${progparams[1]}")              # NTFS-safe and Niente-usable, as when a database is created
CONFACCENTS="${progparams[2]}"; if [ -z "$CONFACCENTS" ]; then CONFACCENTS="no"; fi
CONFBROWZ="${progparams[3]}"
CONFLOGOSIZE="${progparams[4]}"
  if [[ $CONFLOGOSIZE =~ ^[0-9]{1,4}$ ]] && (( 10#$CONFLOGOSIZE >= 100 && 10#$CONFLOGOSIZE <= 400 )); then CONFLOGOSIZE=$((10#$CONFLOGOSIZE)); else CONFLOGOSIZE=110; fi   # 100 to 400: default 110
  CONFLOGOSIZE=$CONFLOGOSIZE"x"$CONFLOGOSIZE
CONFLOGOPOS="${progparams[5]}"
  if [[ $((CONFLOGOPOS)) != "$CONFLOGOPOS" ]]; then CONFLOGOPOS=0; fi
CONFSMART="${reptparams[0]}"; if [ -z "$CONFSMART" ]; then CONFSMART=300; fi
CONFLGART="${reptparams[1]}"; if [ -z "$CONFLGART" ]; then CONFLGART=1600; fi
CONFSQART="${reptparams[2]}"; if [ -z "$CONFSQART" ]; then CONFSQART="yes"; fi
CONFMAXV="${reptparams[3]}"; if [ -z "$CONFMAXV" ]; then CONFMAXV=2; fi
CONFREPMAXV="${reptparams[4]}"; if [ -z "$CONFREPMAXV" ]; then CONFREPMAXV=yes; fi
CONFNBITS="${reptparams[5]}"; if [ -z "$CONFNBITS" ]; then CONFNBITS=yes; fi
CONFWEZTHEME="${progparams[6]}"; CONFWEZTHEME="${CONFWEZTHEME//\"/}"        # WezTerm colour scheme: no double quotes, as it's written in quotes
  if [[ -z $CONFWEZTHEME ]]; then CONFWEZTHEME="Wild Cherry (Gogh)"; fi
CONFWEZFNTSZ="${progparams[7]}"
  if [[ $CONFWEZFNTSZ =~ ^[0-9]+$ ]] && (( 10#$CONFWEZFNTSZ >= 8 && 10#$CONFWEZFNTSZ <= 32 )); then CONFWEZFNTSZ=$((10#$CONFWEZFNTSZ)); else CONFWEZFNTSZ=12; fi   # 8 to 32 points: default 12

CONFDIATHEME="${progparams[8]}"
# Make sure CONFDIATHEME is one of standard, red, green, yellow or magenta. If not, it's standard
if [[ ${CONFDIATHEME,,} =~ ^(standard|red|green|yellow|magenta)$ ]]; then CONFDIATHEME=${CONFDIATHEME,,}; else CONFDIATHEME=standard; fi

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

# Text values are written inside double quotes and the file is later sourced, so strip anything that would break
# out of (or be expanded inside) those quotes: " $ ` and backslash (as Giocoso and Semplice do)
# ====================================================================
BADCHARS='[\"$`\\]'
for v in CONFMUSDIR CONFDBNAME CONFBROWZ CONFWEZTHEME; do
  printf -v "$v" '%s' "${!v//$BADCHARS/}"
done

# Keep the colours already chosen (via the colour picker): read each from the existing file, falling back
# to its default if missing or not a whole number from 0 to 255 (as Giocoso and Semplice do)
# ====================================================================
for colourpair in HOTKEY:11 DRAWLINES:2 MAINTEXT:15 LOGO:6 INFOTEXT:11 SPINNER:12 ALERT:1; do
  colname="${colourpair%%:*}"; coldefault="${colourpair##*:}"
  colvalue=$($GREPPROG -i -m1 "^$colname=" "$CONFFILE" 2>/dev/null | $SEDPROG -e "s/^[^=]*=//" -e "s/[[:space:]]*$//")
  if ! [[ $colvalue =~ ^[0-9]+$ && $colvalue -le 255 ]]; then colvalue=$coldefault; fi
  printf -v "KEEP_$colname" "%s" "$colvalue"
done

# Back up the existing configuration file, keeping only the ten most recent backups (as Giocoso and Semplice do)
# ====================================================================
if [[ -f "$CONFDIR/txt/niente.conf" ]]; then
  cp "$CONFDIR/txt/niente.conf" "$CONFDIR/txt/niente.conf-$(date +%F-%T).bkp"
  BKPS=("$CONFDIR/txt"/niente.conf-*.bkp)                                 # The names carry the date and time,
  if [[ ${#BKPS[@]} -gt 10 && -f ${BKPS[0]} ]]; then                         # so name order is age order
    rm -f "${BKPS[@]:0:${#BKPS[@]}-10}"
  fi
fi

cat > "$CONFDIR/txt/niente.conf" <<CONFEOF
# New Niente Configuration File, created $(date)
# ====================================================================

# Colour Constants (alter at your peril!)
# ====================================================================
HOTKEY=$KEEP_HOTKEY
DRAWLINES=$KEEP_DRAWLINES
MAINTEXT=$KEEP_MAINTEXT
LOGO=$KEEP_LOGO
INFOTEXT=$KEEP_INFOTEXT
SPINNER=$KEEP_SPINNER
ALERT=$KEEP_ALERT

# General Parameters (text values double-quoted, since they may contain spaces)
# ====================================================================
UTFCHARS=$CONFACCENTS
BROWSER="$CONFBROWZ"
LOGOSIZE=$CONFLOGOSIZE
LOGOPOS=$CONFLOGOPOS
WEZTHEME="$CONFWEZTHEME"
WEZFNTSZ=$CONFWEZFNTSZ
DIATHEME="$CONFDIATHEME"

# Database Parameters
# ====================================================================
DBNAME="$CONFDBNAME"
MUSICDIR="$CONFMUSDIR"

# Reporting threshold/limit parameters
# ====================================================================
SMALLART=$CONFSMART
LARGEART=$CONFLGART
SQUAREART=$CONFSQART
VOLUMETHRESHOLD=$CONFMAXV
NAMEBITS=$CONFNBITS
REPORTMAXV=$CONFREPMAXV
CONFEOF

rm -f "$CONFDIR/tmp/confparams" 2>/dev/null
"$CONVPROG" "$CONFDIR/art/nienteicobeta.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/nienteicosmallbeta.png" 2>/dev/null     # The small menu logos, at the (perhaps new) size
"$CONVPROG" "$CONFDIR/art/nienteico.png" -resize "$CONFLOGOSIZE" "$CONFDIR/art/nienteicosmall.png" 2>/dev/null
source "$CONFDIR/bin/nenparse.sh"
