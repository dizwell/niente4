#!/usr/bin/env bash
####################################################################
#
# nenintegrity: routine for checking the state of embedded
# album art within known FLACs
#
# A FULL check = visit every row in the tracks table and recheck everything
# A DIFFERENTIAL = visit rows in tracks which have errors & recheck everything
# A LOGICAL = visit every row in the tracks table and recheck logical issues only
#
# Logical tests everything except where hash values are involved
#
# The general structure of these checks is:
# (
#   do work
#   calculate percentage done
#   echo the percentage done
# ) | dialog guage form
#
# The opening/close brackets allow the work to be done to happen
# in a sub-shell and for the results of that work to be piped out
# to dialog.
#
####################################################################
SECONDS=0

# Here are the SQL statements which generate results that match the AggStats report
# and which will therefore be the basis of saying, in a differential check, 'these
# were problems that need revisiting'. They could all be unioned and issued as a 
# single query: that would be efficient. It also makes it extremely difficult to
# maintain if the logic of any individual query needs modifying. So we're going 
# for slightly less efficiency and rather more maintainability! 

: <<'END'
GENERAL REPORTS
===============
select filename from tracks where hash_orig<>hash_new or hash_orig is null or hash_new is null

select filename from tracks where (bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle='')

select filename from tracks where ((bitdepth IS NULL OR bitdepth='') OR (sample_rate IS NULL OR sample_rate='') OR (hash_orig IS NULL OR hash_orig='') OR (hash_new IS NULL OR hash_new='') OR (album_year IS NULL OR album_year='') OR (date_tag IS NULL OR date_tag='') OR (performer IS NULL OR performer='') OR (comment IS NULL OR comment='') OR (albumname IS NULL OR albumname='') OR (artistname IS NULL OR artistname='') OR (composername IS NULL OR composername='') OR (genrename IS NULL OR genrename='') OR (tracktitle IS NULL OR tracktitle='')) AND NOT ((bitdepth IS NULL OR bitdepth='') AND (sample_rate IS NULL OR sample_rate='') AND (hash_orig IS NULL OR hash_orig='') AND (hash_new IS NULL OR hash_new='') AND (album_year IS NULL OR album_year='') AND (date_tag IS NULL OR date_tag='') AND (performer IS NULL OR performer='') AND (comment IS NULL OR comment='') AND (albumname IS NULL OR albumname='') AND (artistname IS NULL OR artistname='') AND (composername IS NULL OR composername='') AND (genrename IS NULL OR genrename='') AND (tracktitle IS NULL OR tracktitle=''))

LOGICAL REPORTS
===============
select filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0
select filename from (select * from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)
select filename from tracks where not instr(comment, performer)
select filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '('))))
select filename from tracks where artistname<>composername
select filename from tracks where bitdepth=16 and sample_rate>48000 union select filename from tracks where bitdepth=24 and sample_rate<48000

OTHER REPORTS
=============
select filename from albumart where (albumartheight < $SMALLART or albumartwidth < $SMALLART) or (albumartheight > $LARGEART or albumartwidth > $LARGEART) or (albumartheight <> albumartwidth) or (albumartheight is null or albumartheight = '') or (albumartwidth is null or albumartwidth = '')
select $FOLDERSQL from maxvolumes group by $FOLDERSQL having min(boost) > $VOLUMETHRESHOLD
select filename from tracks where replaygain is null or replaygain=''
select filename from (select filename, bitdepth, sample_rate, instr(filename, computed_bitdepth||'-'||computed_samplerate) as intest, computed_bitdepth, computed_samplerate from ( select filename, bitdepth, sample_rate, ifnull(bitdepth, 1) as computed_bitdepth, ifnull(sample_rate,1) as computed_samplerate from tracks ) where intest=0)
select filename from (select filename, rtrim(filename, replace(filename, '/', '')), composername, albumname, count(*) from tracks group by rtrim(filename, replace(filename, '/', '')), composername, albumname having count(*) > 1)
select filename from (select filename, hash_orig from tracks where hash_orig in (select hash_orig from tracks group by hash_orig having count(*)>1))
END

function integrity_check {
if [ -z "$DBNAME" ]; then return; fi
tput civis;
FSSCAN=X
PROCESSFILES="$CONFDIR/tmp/integritycheckfiles.txt"
TMPFILES="$CONFDIR/tmp/integritycheckfiles-tmp.txt"
rm -f "$PROCESSFILES" 2>/dev/null
rm -f "$TMPFILES" 2>/dev/null

# A full check redoes every track, which can take hours: if any track has been checked before (every check of any type
# records a LAST_CHECK_DATE, and loading never does), ask first, defaulting to No. A never-checked database goes straight ahead
if [[ $CHECKTYPE == "full" ]]; then
  CHECKEDBEFORE=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where last_check_date is not null and last_check_date <> ''")
  if [[ ${CHECKEDBEFORE:-0} -gt 0 ]]; then
    ALLTRACKS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
    if ! dialog --backtitle "Niente Integrity Check" --title " Confirm Full Integrity Check " --no-mouse --defaultno --yesno "\nThis is a full integrity check: it will re-examine every one of the $(thousands "$ALLTRACKS") FLACs in database '$DBNAME', recalculating their checksums and re-extracting every piece of metadata they contain, which can take many hours.\n\nAre you sure you want to proceed?" 12 80; then
      return
    fi
  fi
fi

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  dialog --stdout --backtitle "Niente Integrity Check" --title " Application lock present! " --msgbox "\\nAnother Niente session is currently running a scan or check, so this one cannot proceed.\\n\\nPlease try again when it has finished. Click OK to return to the main menu." 12 80
  return
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a $CHECKTYPE integrity check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

if [[ ! -f $PROCESSFILES ]]; then touch "$PROCESSFILES"; fi
if [[ ! -f $TMPFILES ]]; then touch "$TMPFILES"; fi

case $CHECKTYPE in
  full) DISPLAYCHECK="(Complete)" ;;
  diff) DISPLAYCHECK="(Differential)" ;;
  logic) DISPLAYCHECK="(Logical)" ;;
esac
integrity_candidates "$PROCESSFILES"

TOTALRECORDS=$(wc -l < "$PROCESSFILES")
TOTALRECORDS=${TOTALRECORDS//[[:space:]]/}

if [[ $TOTALRECORDS -eq 0 ]]; then
  release_lock
  dialog --stdout --backtitle "Niente Integrity Check" --title " No records to process " --msgbox "\\nThere are no recordings mentioned in the database that Niente needs to process for this sort of integrity check.\\n\\nClick OK to return to the main menu." 12 80
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Cancelling a $CHECKTYPE integrity check, as there are no recordings that need processing.')"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  return
fi

# If we get this far, we have at least one file to process
readarray -t recheck < "$PROCESSFILES"
COUNTER=0
  
(
for f in "${recheck[@]}"; do
  fileid="${f%%|*}"; filename="${f#*|}"                 # Split at the first pipe only: a filename may contain one
  COUNTER=$((COUNTER+1))
  HOURS=$(( SECONDS / 3600 ))
  MINS=$(( (SECONDS % 3600) / 60 ))
  SECS=$(( SECONDS % 60 ))
  ELAPSED=$(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)
  BITDEPTH=$("$METAFLAC" $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$("$METAFLAC" $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG sample_rate | awk '{print $2}')
  HASHORIG=$("$METAFLAC" $UTFCHARS --show-md5sum "$filename" 2>/dev/null)
  
  # Calculate ETA (HH:MM:SS)
  if (( COUNTER > 1 )); then
    if (( COUNTER % 25 == 0 )); then
      REMAINING_SECONDS=$(( (TOTALRECORDS - COUNTER) * SECONDS / COUNTER ))
      ETA_H=$(( REMAINING_SECONDS / 3600 ))
      ETA_M=$(( (REMAINING_SECONDS % 3600) / 60 ))
      ETA_S=$(( REMAINING_SECONDS % 60 ))
      ETA=$(printf "%02d:%02d:%02d" $ETA_H $ETA_M $ETA_S)
    fi
  else
    ETA="--:--:--"
  fi
  
  # Compute new HASH, but only if NOT a logical integrity check
  if [[ $CHECKTYPE == "logic" ]]; then
    :
  else
      if [[ $BITDEPTH == "16" ]]; then
        FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed 's/^[^=]*=//')
      elif [[ $BITDEPTH == "24" ]]; then
        FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s24le -map 0:a -f md5 - 2>/dev/null | sed 's/^[^=]*=//')
      else
        FRESHHASH=$("$FFMPEG" -nostdin -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed 's/^[^=]*=//')
      fi
  fi
  
  LASTCHECK=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select last_check_date from tracks where id='$fileid'")
  ALBUM=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  DATETAG=$("$METAFLAC" $UTFCHARS --show-tag=DATE "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  ALBUMYEAR=${ALBUM: -5:4} # If album contains a year, should be 5th, 4th, 3rd and 2nd characters from the end
  COMMENT=$("$METAFLAC" $UTFCHARS --show-tag=COMMENT "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  PERFORMER=$("$METAFLAC" $UTFCHARS --show-tag=PERFORMER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  TRACKNO=$("$METAFLAC" $UTFCHARS --show-tag=TRACKNUMBER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  ARTISTNAME=$("$METAFLAC" $UTFCHARS --show-tag=ARTIST "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  GENRENAME=$("$METAFLAC" $UTFCHARS --show-tag=GENRE "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  TRACKTITLE=$("$METAFLAC" $UTFCHARS --show-tag=TITLE "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  REPLAYGAIN=$("$METAFLAC" $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_GAIN "$filename" 2>/dev/null | sed 's/^[^=]*=//')
  THISDATE=$(date +"%Y-%m-%d")
  LINELENGTH=75

  # For display purposes, we truncate bits of information and strip out carriage returns and newlinefeed characters (which shouldn't be there, but ours is not to correct that now)
  DISPCOMPOSERNAME="${COMPOSERNAME:0:$LINELENGTH}"; DISPCOMPOSERNAME=$(echo $DISPCOMPOSERNAME | tr -d '\r'); DISPCOMPOSERNAME=$(echo $DISPCOMPOSERNAME | tr -d '\n')
  DISPALBUMNAME="${ALBUMNAME:0:$LINELENGTH}"; DISPALBUMNAME=$(echo $DISPALBUMNAME | tr -d '\r'); DISPALBUMNAME=$(echo $DISPALBUMNAME | tr -d '\n')
  DISPPERFORMER="${PERFORMER:0:$LINELENGTH}"; DISPPERFORMER=$(echo $DISPPERFORMER | tr -d '\r'); DISPPERFORMER=$(echo $DISPPERFORMER | tr -d '\n')
  DISPGENRENAME="${GENRENAME:0:$LINELENGTH}"; DISPGENRENAME=$(echo $DISPGENRENAME | tr -d '\r'); DISPGENRENAME=$(echo $DISPGENRENAME | tr -d '\n')
  DISPAUDIODATA="$BITDEPTH bit - $SAMPLERATE Hz"
  DISPDATETAG="${DATETAG:0:$LINELENGTH}"; DISPDATETAG=$(echo $DISPDATETAG | tr -d '\r'); DISPDATETAG=$(echo $DISPDATETAG | tr -d '\n')

  # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
  # Double quotes are replaced by a meaningless string for now...
  PERFORMER="${PERFORMER//\'/\'\'}"; PERFORMER="${PERFORMER//\"/##@##}"
  COMMENT="${COMMENT//\'/\'\'}"; COMMENT="${COMMENT//\"/##@##}"
  ALBUMNAME="${ALBUMNAME//\'/\'\'}"; ALBUMNAME="${ALBUMNAME//\"/##@##}"
  ARTISTNAME="${ARTISTNAME//\'/\'\'}"; ARTISTNAME="${ARTISTNAME//\"/##@##}"
  COMPOSERNAME="${COMPOSERNAME//\'/\'\'}"; COMPOSERNAME="${COMPOSERNAME//\"/##@##}"
  GENRENAME="${GENRENAME//\'/\'\'}"; GENRENAME="${GENRENAME//\"/##@##}"
  TRACKTITLE="${TRACKTITLE//\'/\'\'}"; TRACKTITLE="${TRACKTITLE//\"/##@##}"
  PERCENTAGE=$(( 100 * COUNTER / TOTALRECORDS ))

  if [[ $CHECKTYPE == "logic" ]]; then    # If we're only doing logical tests, we skip the hash calculation
  # Don't mess with the indentation (or lack thereof!) here, as it affects actual display output
  echo -e "XXX\n$(printf '\u00a0')\n\
 Composer   : $DISPCOMPOSERNAME\\n\
 Recording  : $DISPALBUMNAME\\n\
 Year       : $DISPDATETAG\\n\
 Performer  : $DISPPERFORMER\\n\
 Genre      : $DISPGENRENAME\\n\
 Audio Data : $DISPAUDIODATA\\n\
 ReplayGain : $REPLAYGAIN\\n\
 Elapsed    : $(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)\n\
 ETA        : $ETA\n\n\
Processing file $COUNTER of $TOTALRECORDS" 13 95  
    SQLSTR="Update tracks set BITDEPTH='$BITDEPTH', SAMPLE_RATE='$SAMPLERATE', HASH_ORIG='$HASHORIG', LAST_CHECK_DATE='$THISDATE',ALBUM_YEAR='$ALBUMYEAR', DATE_TAG='$DATETAG', PERFORMER='$PERFORMER', COMMENT='$COMMENT', TRACKNUMBER='$TRACKNO', ALBUMNAME='$ALBUMNAME', ARTISTNAME='$ARTISTNAME', COMPOSERNAME='$COMPOSERNAME', GENRENAME='$GENRENAME', TRACKTITLE='$TRACKTITLE', REPLAYGAIN='$REPLAYGAIN' where id='$fileid'"
    echo "$PERCENTAGE" 
  else 

    # Don't mess with the indentation (or lack thereof!) here, as it affects actual display output
  echo -e "XXX\n$(printf '\u00a0')\n\
 Composer   : $DISPCOMPOSERNAME\\n\
 Recording  : $DISPALBUMNAME\\n\
 Year       : $DISPDATETAG\\n\
 Performer  : $DISPPERFORMER\\n\
 Genre      : $DISPGENRENAME\\n\
 Audio Data : $DISPAUDIODATA\\n\
 ReplayGain : $REPLAYGAIN\\n\
 MD5 Hash   : $FRESHHASH\\n\
 Elapsed    : $(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)\n\
 ETA        : $ETA\n\n\
 Processing file $COUNTER of $TOTALRECORDS\nXXX" #14 95 
	SQLSTR="Update tracks set BITDEPTH='$BITDEPTH', SAMPLE_RATE='$SAMPLERATE', HASH_ORIG='$HASHORIG', HASH_NEW='$FRESHHASH', LAST_CHECK_DATE='$THISDATE',ALBUM_YEAR='$ALBUMYEAR', DATE_TAG='$DATETAG', PERFORMER='$PERFORMER', COMMENT='$COMMENT', TRACKNUMBER='$TRACKNO', ALBUMNAME='$ALBUMNAME', ARTISTNAME='$ARTISTNAME', COMPOSERNAME='$COMPOSERNAME', GENRENAME='$GENRENAME', TRACKTITLE='$TRACKTITLE', REPLAYGAIN='$REPLAYGAIN' where id='$fileid' AND (BITDEPTH, SAMPLE_RATE, HASH_ORIG, LAST_CHECK_DATE, ALBUM_YEAR, DATE_TAG, PERFORMER, COMMENT, TRACKNUMBER, ALBUMNAME, ARTISTNAME, COMPOSERNAME, GENRENAME, TRACKTITLE, REPLAYGAIN) 
    IS NOT ('$BITDEPTH', '$SAMPLERATE', '$HASHORIG', '$THISDATE', '$ALBUMYEAR', '$DATETAG', '$PERFORMER', '$COMMENT', '$TRACKNO', '$ALBUMNAME', '$ARTISTNAME', '$COMPOSERNAME', '$GENRENAME', '$TRACKTITLE','$REPLAYGAIN');"
	echo "$PERCENTAGE" 
  fi

  # And now to do the actual database update
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR" >/dev/null 2>&1
done
) | dialog --backtitle "Niente Integrity Check ${CHECKTYPE^}" \
           --title " Analysing Music Files " \
           --no-collapse \
           --gauge "Initialising..." 19 95 0

# If there were dodgy characters which were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update tracks set performer=replace(performer,'##@##','\"'), comment=replace(comment,'##@##','\"'), albumname=replace(albumname,'##@##','\"'), artistname=replace(artistname,'##@##','\"'), composername=replace(composername,'##@##','\"'),  genrename=replace(genrename,'##@##','\"'), tracktitle=replace(tracktitle,'##@##','\"');"  >/dev/null 2>&1

# Update the activities log and remove the scan lock
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a $CHECKTYPE integrity check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock
rm -rf "$CONFDIR/tmp/nienterecs.txt" >/dev/null 2>&1
tput cvvis
rm -f "$PROCESSFILES" 2>/dev/null
rm -f "$TMPFILES"
# Only a check that has actually run to the end says so (as the album art and volume checks do)
dialog --stdout --backtitle "Niente Integrity Check Completed" --title " Check Complete! " --msgbox "\\nThe integrity check has completed successfully.\\n\\nReports can now be run to process and display the results. Click OK to return to the main menu." 12 80
}

rm -rf "$CONFDIR/tmp/nienterecs.txt" >/dev/null 2>&1
if [ -z "$1" ]; then CHECKTYPE="full"; else CHECKTYPE=$1; fi
integrity_check