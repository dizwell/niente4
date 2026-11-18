#!/usr/bin/env bash
####################################################################
#
# nenintegritynd: routine for checking the state of embedded
# album art within known FLACs. Same as main integrity check but
# without any graphical output.
#
# A FULL check = visit every row in the tracks table and recheck everything
# A DIFFERENTIAL = visit rows in tracks which have errors & recheck everything
# A LOGICAL = visit every row in the tracks table and recheck logical issues only
#
# Logical tests everything except where hash values are involved
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

function integrity_check {
if [ -z "$DBNAME" ]; then return; fi
tput civis;
FSSCAN=X

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Non-interactive integrity check aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a $CHECKTYPE integrity check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# The files to examine come from the same shared list the menu's checks use
integrity_candidates "$CONFDIR/tmp/nienterecs.txt"
RESCAN_COUNT=$(wc -l < "$CONFDIR/tmp/nienterecs.txt"); RESCAN_COUNT=${RESCAN_COUNT//[[:space:]]/}

if [ $RESCAN_COUNT -eq 0 ]; then
  release_lock
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Cancelling a $CHECKTYPE integrity check, as no records to process');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit
fi

# If we get this far, we have at least one file to process
readarray -t recheck < "$CONFDIR/tmp/nienterecs.txt"
COUNTER=0

for f in "${recheck[@]}"; do
  echo -ne "."
  fileid=$(echo "$f" | awk -F'|' '{print $1}')
  filename=$(echo "$f" | awk -F'|' '{print $2}')
  COUNTER=$((COUNTER+1))
  BITDEPTH=$("$METAFLAC" $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$("$METAFLAC" $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG sample_rate | awk '{print $2}')
  HASHORIG=$("$METAFLAC" $UTFCHARS --show-md5sum "$filename" 2>/dev/null)
  HASHNEW=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select hash_new from tracks where id='$fileid'")
  LASTCHECK=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select last_check_date from tracks where id='$fileid'")
  ALBUM=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
  DATETAG=$("$METAFLAC" $UTFCHARS --show-tag=DATE "$filename" 2>/dev/null | sed s/.*=//g)
  ALBUMYEAR=${ALBUM: -5:4} # If album contains a year, should be 5th, 4th, 3rd and 2nd characters from the end
  COMMENT=$("$METAFLAC" $UTFCHARS --show-tag=COMMENT "$filename" 2>/dev/null | sed s/.*=//g)
  PERFORMER=$("$METAFLAC" $UTFCHARS --show-tag=PERFORMER "$filename" 2>/dev/null | sed s/.*=//g)
  TRACKNO=$("$METAFLAC" $UTFCHARS --show-tag=TRACKNUMBER "$filename" 2>/dev/null | sed s/.*=//g)
  ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
  ARTISTNAME=$("$METAFLAC" $UTFCHARS --show-tag=ARTIST "$filename" 2>/dev/null | sed s/.*=//g)
  COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed s/.*=//g)
  GENRENAME=$("$METAFLAC" $UTFCHARS --show-tag=GENRE "$filename" 2>/dev/null | sed s/.*=//g)
  TRACKTITLE=$("$METAFLAC" $UTFCHARS --show-tag=TITLE "$filename" 2>/dev/null | sed s/.*=//g)
  REPLAYGAIN=$("$METAFLAC" $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_GAIN "$filename" 2>/dev/null | sed s/.*=//g)
  THISDATE=$(date +"%Y-%m-%d")

  # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
  # Double quotes are replaced by a meaningless string for now...
  PERFORMER=${PERFORMER//\'/\'\'}; PERFORMER="${PERFORMER//\"/##@##}"
  COMMENT=${COMMENT//\'/\'\'}; COMMENT="${COMMENT//\"/##@##}"
  ALBUMNAME=${ALBUMNAME//\'/\'\'}; ALBUMNAME="${ALBUMNAME//\"/##@##}"
  ARTISTNAME=${ARTISTNAME//\'/\'\'}; ARTISTNAME="${ARTISTNAME//\"/##@##}"
  COMPOSERNAME=${COMPOSERNAME//\'/\'\'}; COMPOSERNAME="${COMPOSERNAME//\"/##@##}"
  GENRENAME=${GENRENAME//\'/\'\'}; GENRENAME="${GENRENAME//\"/##@##}"
  TRACKTITLE="${TRACKTITLE//\'/\'\'}"; TRACKTITLE="${TRACKTITLE//\"/##@##}"

  if [ $CHECKTYPE == "logic" ]; then    # If we're only doing logical tests, we skip the hash calculation
    SQLSTR="Update tracks set BITDEPTH='$BITDEPTH', SAMPLE_RATE='$SAMPLERATE', HASH_ORIG='$HASHORIG', LAST_CHECK_DATE='$THISDATE',ALBUM_YEAR='$ALBUMYEAR', DATE_TAG='$DATETAG', PERFORMER='$PERFORMER', COMMENT='$COMMENT', TRACKNUMBER='$TRACKNO', ALBUMNAME='$ALBUMNAME', ARTISTNAME='$ARTISTNAME', COMPOSERNAME='$COMPOSERNAME', GENRENAME='$GENRENAME', TRACKTITLE='$TRACKTITLE', REPLAYGAIN='$REPLAYGAIN' where id='$fileid';"
  else                                  # Differential and Full checks require hashes to be re-calculated
    if ! [ -z $BITDEPTH ] && [ $BITDEPTH == "16" ]; then
      FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
    elif ! [ -z $BITDEPTH ] && [ $BITDEPTH == "24" ]; then
      FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s24le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
    elif ! [ -z $BITDEPTH ]; then FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
	else
	  FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
    fi
	SQLSTR="Update tracks set BITDEPTH='$BITDEPTH', SAMPLE_RATE='$SAMPLERATE', HASH_ORIG='$HASHORIG', HASH_NEW='$FRESHHASH', LAST_CHECK_DATE='$THISDATE',ALBUM_YEAR='$ALBUMYEAR', DATE_TAG='$DATETAG', PERFORMER='$PERFORMER', COMMENT='$COMMENT', TRACKNUMBER='$TRACKNO', ALBUMNAME='$ALBUMNAME', ARTISTNAME='$ARTISTNAME', COMPOSERNAME='$COMPOSERNAME', GENRENAME='$GENRENAME', TRACKTITLE='$TRACKTITLE', REPLAYGAIN='$REPLAYGAIN' where id='$fileid';"
  fi

  # And now to do the actual database update
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"
done

# If there were dodgy characters which were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update tracks set performer=replace(performer,'##@##','\"'), comment=replace(comment,'##@##','\"'), albumname=replace(albumname,'##@##','\"'), artistname=replace(artistname,'##@##','\"'), composername=replace(composername,'##@##','\"'),  genrename=replace(genrename,'##@##','\"'), tracktitle=replace(tracktitle,'##@##','\"');"  >/dev/null 2>&1

# Update the activities log and remove the scan lock
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a $CHECKTYPE integrity check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock
rm -rf "$CONFDIR/tmp/nienterecs.txt" >/dev/null 2>&1
tput cvvis
}

if [ -z "$1" ]; then CHECKTYPE="full"; else CHECKTYPE=$1; fi
integrity_check
echo -ne " - Finished"; sleep 10
