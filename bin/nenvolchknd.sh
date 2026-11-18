#!/usr/bin/env bash
####################################################################
#
# nenvolchknd: routine for checking the peak volumes of music
# within a FLAC mentioned in the Niente music database. Same as then
# main module for doing this, but with no output to screen.
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH
POSSIBLE_BOOSTS=0

trap ctrl_c INT  # Trap to quit nicely if Ctrl+C issued

function ctrl_c() {
  release_lock
  exit_program
}

function volumeboost_scan {
tput civis
check_database
SQLSTMT="create table if not exists maxvolumes_load (ID integer not null, FILENAME text, BOOST numeric, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Non-interactive Volume Boost scan aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a $SCANTYPE Volume Boost check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name in ('maxvolumes_load','maxvolumes')"
if [ $SCANTYPE == "full" ]; then
  VOLSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
  VOLSCAN_SQL="select id, filename from tracks order by filename"
  sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes"
else
  # Note the horror SQL needed to extract only the folder name from a folder/file full path name!
  VOLSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where substr(filename, 1, instr(filename,replace(filename, rtrim(filename, replace(filename, '/', '')), ''))-2) not in (select filename from maxvolumes)")
  VOLSCAN_SQL="select id, filename from tracks where substr(filename, 1, instr(filename,replace(filename, rtrim(filename, replace(filename, '/', '')), ''))-2) not in (select filename from maxvolumes) order by filename"
fi

if [ $VOLSCAN_COUNT -eq 0 ]; then
  exit
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$VOLSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t volcheck < "$CONFDIR/txt/nienterecs.txt"
COUNTER=0

for f in "${volcheck[@]}"; do
  fileid=$(echo "$f" | awk -F'|' '{print $1}')
  filename=$(echo "$f" | awk -F'|' '{print $2}')
  COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed s/.*=//g)
  ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
  COUNTER=$((COUNTER+1))
  if [ -z "$filename" ]; then filename='QxQxQx'; fi
  if [ -f "$filename" ]; then
    dirname=$(dirname "$filename")
    MAXV=$("$FFMPEG" -nostdin -i "$filename" -af "volumedetect" -vn -sn -dn -f null - 2>&1 | $GREPPROG -m 1 max_volume | $GREPPROG -oP '\-\K.+')
    if [ -z "$MAXV" ]; then
      MAXV=0.0              # Special case: if max_volume is 0.0, then ffmpeg displays no '+' against it, so the return from the above is null. This sets it back to being 0.0
    else
      MAXV=${MAXV%" dB"}	# Strip the 'dB' suffix from the return: we want only numbers, otherwise we can't do maths with them later
    fi

    # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    volfilename=${dirname//\'/\'\'}
    volfilename="${volfilename//\"/##@##}"
    SQLSTR="insert into maxvolumes_load (filename, boost) values ('$volfilename','$MAXV')"
    sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"
  fi

  if [ $((COUNTER%10)) -eq  0 ]; then
    sqlite3 "$CONFDIR/db/$DBNAME.db" "update maxvolumes_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into maxvolumes select * from maxvolumes_load"
    sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"
  fi
done

# Since we've only been inserting every tenth row in the loop, the last up-to-nine rows in maxvolumes_load are left hanging
# A final insert makes sure the last few rows are transferred too.
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into maxvolumes select * from maxvolumes_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"

# If dodgy characters were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update maxvolumes_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into maxvolumes select * from maxvolumes_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing the volume boost check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock
}

if [ -z "$1" ]; then SCANTYPE="full"; else SCANTYPE=$1; fi
volumeboost_scan
