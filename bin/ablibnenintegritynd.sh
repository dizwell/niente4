#!/usr/bin/env bash
####################################################################
#
# ablibnenintegritynd: routine for checking the state of embedded
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
if ! [ -f "$CONFDIR/tmp/nientelock" ]; then
  touch "$CONFDIR/tmp/nientelock"
else
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Non-interactive integrity check aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a $CHECKTYPE integrity check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# This SQL gets the filenames of every dodgy FLAC in the database, in one hit. We run it twice so we
# can determine the *number* of records that need re-scanning.

if [ $CHECKTYPE == "full" ]; then
  RESCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
  RESCAN_SQL="select distinct id, filename from tracks order by filename"
elif [ $CHECKTYPE == "diff" ]; then
  if [ "$NAMEBITS" == "yes" ]; then     # We only count filenames not including bit-depth data as a problem if NAMEBITS is switched on
    RESCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (
    select filename from tracks where hash_orig<>hash_new union
    select filename from tracks where hash_new is null or length(hash_new)=0 union
    select filename from tracks where length(artistname)=0 or artistname is null union
    select filename from tracks where length(albumname)=0 or albumname is null union
    select filename from tracks where length(composername)=0 or composername is null union
    select filename from tracks where length(performer)=0 or performer is null union
    select filename from tracks where length(genrename)=0 or genrename is null union
    select filename from tracks where length(comment)=0 or comment is null union
    select filename from tracks where length(date_tag)=0 or date_tag is null union
    select filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select filename from tracks where not instr(comment, performer) union
    select filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select filename from tracks where artistname<>composername)")

    RESCAN_SQL="select distinct id, filename from (
    select id, filename from tracks where hash_orig<>hash_new union
    select id, filename from tracks where hash_new is null or length(hash_new)=0 union
    select id, filename from tracks where length(artistname)=0 or artistname is null union
    select id, filename from tracks where length(albumname)=0 or albumname is null union
    select id, filename from tracks where length(composername)=0 or composername is null union
    select id, filename from tracks where length(performer)=0 or performer is null union
    select id, filename from tracks where length(genrename)=0 or genrename is null union
    select id, filename from tracks where length(comment)=0 or comment is null union
    select id, filename from tracks where length(date_tag)=0 or date_tag is null union
    select id, filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select id, filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select id, filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select id, filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select id, filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select id, filename from tracks where not instr(comment, performer) union
    select id, filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select id, filename from tracks where artistname<>composername)
    order by filename"
  else
    RESCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (
    select filename from tracks where ifnull(hash_orig,'X')<>ifnull(hash_new,'Y') union
    select filename from tracks where length(artistname)=0 or artistname is null union
    select filename from tracks where length(albumname)=0 or albumname is null union
    select filename from tracks where length(composername)=0 or composername is null union
    select filename from tracks where length(performer)=0 or performer is null union
    select filename from tracks where length(genrename)=0 or genrename is null union
    select filename from tracks where length(comment)=0 or comment is null union
    select filename from tracks where length(date_tag)=0 or date_tag is null union
    select filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select filename from tracks where not instr(comment, performer) union
    select filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select filename from tracks where artistname<>composername)")

    RESCAN_SQL="select distinct id, filename from (
    select id, filename from tracks where ifnull(hash_orig,'X')<>ifnull(hash_new,'Y') union
    select id, filename from tracks where length(artistname)=0 or artistname is null union
    select id, filename from tracks where length(albumname)=0 or albumname is null union
    select id, filename from tracks where length(composername)=0 or composername is null union
    select id, filename from tracks where length(performer)=0 or performer is null union
    select id, filename from tracks where length(genrename)=0 or genrename is null union
    select id, filename from tracks where length(comment)=0 or comment is null union
    select id, filename from tracks where length(date_tag)=0 or date_tag is null union
    select id, filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select id, filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select id, filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select id, filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select id, filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select id, filename from tracks where not instr(comment, performer) union
    select id, filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select id, filename from tracks where artistname<>composername)
    order by filename"
  fi
elif [ $CHECKTYPE == "logic" ]; then
  if [ "$NAMEBITS" == "yes" ]; then     # We only count filenames not including bit-depth data as a problem if NAMEBITS is switched on
    RESCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (
    select filename from tracks where length(artistname)=0 or artistname is null union
    select filename from tracks where length(albumname)=0 or albumname is null union
    select filename from tracks where length(composername)=0 or composername is null union
    select filename from tracks where length(performer)=0 or performer is null union
    select filename from tracks where length(genrename)=0 or genrename is null union
    select filename from tracks where length(comment)=0 or comment is null union
    select filename from tracks where length(date_tag)=0 or date_tag is null union
    select filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select filename from tracks where not instr(comment, performer) union
    select filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select filename from tracks where artistname<>composername union
  select filename from tracks where instr(filename, ifnull(bitdepth, 'xxQxx'))=1)")

    RESCAN_SQL="select distinct id, filename from (
    select id, filename from tracks where length(artistname)=0 or artistname is null union
    select id, filename from tracks where length(albumname)=0 or albumname is null union
    select id, filename from tracks where length(composername)=0 or composername is null union
    select id, filename from tracks where length(performer)=0 or performer is null union
    select id, filename from tracks where length(genrename)=0 or genrename is null union
    select id, filename from tracks where length(comment)=0 or comment is null union
    select id, filename from tracks where length(date_tag)=0 or date_tag is null union
    select id, filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select id, filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select id, filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select id, filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select id, filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select id, filename from tracks where not instr(comment, performer) union
    select id, filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select id, filename from tracks where artistname<>composername union
    select id, filename from tracks where instr(filename, ifnull(bitdepth, 'xxQxx'))=1)
    order by filename"
  else
    RESCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from (
    select filename from tracks where length(artistname)=0 or artistname is null union
    select filename from tracks where length(albumname)=0 or albumname is null union
    select filename from tracks where length(composername)=0 or composername is null union
    select filename from tracks where length(performer)=0 or performer is null union
    select filename from tracks where length(genrename)=0 or genrename is null union
    select filename from tracks where length(comment)=0 or comment is null union
    select filename from tracks where length(date_tag)=0 or date_tag is null union
    select filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select filename from tracks where not instr(comment, performer) union
    select filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select filename from tracks where artistname<>composername)")

    RESCAN_SQL="select distinct id, filename from (
    select id, filename from tracks where length(artistname)=0 or artistname is null union
    select id, filename from tracks where length(albumname)=0 or albumname is null union
    select id, filename from tracks where length(composername)=0 or composername is null union
    select id, filename from tracks where length(performer)=0 or performer is null union
    select id, filename from tracks where length(genrename)=0 or genrename is null union
    select id, filename from tracks where length(comment)=0 or comment is null union
    select id, filename from tracks where length(date_tag)=0 or date_tag is null union
    select id, filename from tracks where length(tracknumber)=0 or tracknumber is null or tracknumber=0 union
    select id, filename from tracks where album_year<>date_tag and length(DATE_TAG)>0 and length(ALBUM_YEAR)>0 union
    select id, filename from tracks where bitdepth=16 and ifnull(sample_rate,999999)>48000 union select id, filename from tracks where bitdepth=24 and ifnull(sample_rate,0)<48000 union
    select id, filename from tracks where id in (select id from (select  id from tracks t, (select albumname from tracks group by albumname having min(cast(tracknumber as int)) <> 1) b where b.albumname=t.albumname)) union
    select id, filename from tracks where not instr(comment, performer) union
    select id, filename from tracks where not instr(performer, substr(albumname,instr(albumname,'(')+1,(length(albumname)-8)-(instr(albumname, '(')))) union
    select id, filename from tracks where artistname<>composername)
    order by filename"
  fi
fi

if [ $RESCAN_COUNT -eq 0 ]; then
  rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Cancelling a $CHECKTYPE integrity check, as no records to process');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit
fi

# If we get this far, we have at least one file to process
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$RESCAN_SQL" > "$CONFDIR/tmp/nienterecs.txt"
readarray -t recheck < "$CONFDIR/tmp/nienterecs.txt"
COUNTER=0

for f in "${recheck[@]}"; do
  echo -ne "."
  fileid=$(echo "$f" | awk -F'|' '{print $1}')
  filename=$(echo "$f" | awk -F'|' '{print $2}')
  COUNTER=$((COUNTER+1))
  BITDEPTH=$(metaflac $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG bits-per-sample | awk '{print $2}')
  SAMPLERATE=$(metaflac $UTFCHARS --list "$filename" 2>/dev/null | $GREPPROG sample_rate | awk '{print $2}')
  HASHORIG=$(metaflac $UTFCHARS --show-md5sum "$filename" 2>/dev/null)
  HASHNEW=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select hash_new from tracks where id='$fileid'")
  LASTCHECK=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select last_check_date from tracks where id='$fileid'")
  ALBUM=$(metaflac $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
  DATETAG=$(metaflac $UTFCHARS --show-tag=DATE "$filename" 2>/dev/null | sed s/.*=//g)
  ALBUMYEAR=${ALBUM: -5:4} # If album contains a year, should be 5th, 4th, 3rd and 2nd characters from the end
  COMMENT=$(metaflac $UTFCHARS --show-tag=COMMENT "$filename" 2>/dev/null | sed s/.*=//g)
  PERFORMER=$(metaflac $UTFCHARS --show-tag=PERFORMER "$filename" 2>/dev/null | sed s/.*=//g)
  TRACKNO=$(metaflac $UTFCHARS --show-tag=TRACKNUMBER "$filename" 2>/dev/null | sed s/.*=//g)
  ALBUMNAME=$(metaflac $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
  ARTISTNAME=$(metaflac $UTFCHARS --show-tag=ARTIST "$filename" 2>/dev/null | sed s/.*=//g)
  COMPOSERNAME=$(metaflac $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed s/.*=//g)
  GENRENAME=$(metaflac $UTFCHARS --show-tag=GENRE "$filename" 2>/dev/null | sed s/.*=//g)
  TRACKTITLE=$(metaflac $UTFCHARS --show-tag=TITLE "$filename" 2>/dev/null | sed s/.*=//g)
  REPLAYGAIN=$(metaflac $UTFCHARS --show-tag=REPLAYGAIN_ALBUM_GAIN "$filename" 2>/dev/null | sed s/.*=//g)
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
      FRESHHASH=$(ffmpeg -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
    elif ! [ -z $BITDEPTH ] && [ $BITDEPTH == "24" ]; then
      FRESHHASH=$(ffmpeg -i "$filename" -c:a pcm_s24le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
    elif ! [ -z $BITDEPTH ]; then FRESHHASH=$(ffmpeg -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
	else
	  FRESHHASH=$(ffmpeg -i "$filename" -c:a pcm_s16le -map 0:a -f md5 - 2>/dev/null | sed s/.*=//g)
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
rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
rm -rf "$CONFDIR/tmp/nienterecs.txt" >/dev/null 2>&1
tput cvvis
}

if [ -z "$1" ]; then CHECKTYPE="full"; else CHECKTYPE=$1; fi
integrity_check
echo -ne " - Finished"; sleep 10
