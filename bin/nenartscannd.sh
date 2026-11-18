#!/usr/bin/env bash
####################################################################
#
# nenartscan: routine for checking the state of embedded
# album art within known FLACs. Same as main artscan process, but
# with no output to screen.
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

function full_art_checkonly {
FSSCAN=X
check_database

SQLSTMT="create table if not exists albumart_load (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Non-interactive Album Art scan aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting an Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

ARTSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
ARTSCAN_SQL="select id, filename from tracks order by filename"

if [ $ARTSCAN_COUNT -eq 0 ]; then
  release_lock
  return
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$ARTSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t artcheck < "$CONFDIR/txt/nienterecs.txt"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name='albumart_load'"
COUNTER=0

for f in "${artcheck[@]}"; do
  fileid="${f%%|*}"; filename="${f#*|}"                 # Split at the first pipe only: a filename may contain one
  COUNTER=$((COUNTER+1))
  if [ -z "$filename" ]; then filename='QxQxQx'; fi
  if [ -f "$filename" ]; then
    COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    ARTWIDTH=$("$METAFLAC" --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 width | awk '{print $2}'); if [ -z "$ARTWIDTH" ]; then ARTWIDTH=9999; fi
    ARTHEIGHT=$("$METAFLAC" --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 height | awk '{print $2}'); if [ -z "$ARTHEIGHT" ]; then ARTHEIGHT=9999; fi

	# Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    artfilename=${filename//\'/\'\'}
    artfilename="${artfilename//\"/##@##}"
	SQLSTR="insert into albumart_load (filename, albumartheight, albumartwidth) values ('$artfilename','$ARTHEIGHT','$ARTWIDTH')"
	sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"  >/dev/null 2>&1
  fi
done

# If there were dodgy characters that were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update albumart_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name='albumart'"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into albumart select * from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a full Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock
}

function diff_art_checkonly {
FSSCAN=X
check_database

SQLSTMT="create table if not exists albumart_load (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Non-interactive Album Art scan aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a differential Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

ARTSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where filename not in (select filename from albumart)")
ARTSCAN_SQL="select id, filename from tracks where filename not in (select filename from albumart) order by filename"

if [ $ARTSCAN_COUNT -eq 0 ]; then
  release_lock
  return
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$ARTSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t artcheck < "$CONFDIR/txt/nienterecs.txt"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name='albumart_load'"
COUNTER=0

for f in "${artcheck[@]}"; do
  fileid="${f%%|*}"; filename="${f#*|}"                 # Split at the first pipe only: a filename may contain one
  COUNTER=$((COUNTER+1))
  if [ -z "$filename" ]; then filename='QxQxQx'; fi
  if [ -f "$filename" ]; then
    COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    ARTWIDTH=$("$METAFLAC" --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 width | awk '{print $2}'); if [ -z "$ARTWIDTH" ]; then ARTWIDTH=9999; fi
    ARTHEIGHT=$("$METAFLAC" --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 height | awk '{print $2}'); if [ -z "$ARTHEIGHT" ]; then ARTHEIGHT=9999; fi

	# Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    artfilename=${filename//\'/\'\'}
    artfilename="${artfilename//\"/##@##}"
	SQLSTR="insert into albumart_load (filename, albumartheight, albumartwidth) values ('$artfilename','$ARTHEIGHT','$ARTWIDTH')"
	sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"  >/dev/null 2>&1
  fi
done

# If there were dodgy characters that were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update albumart_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into albumart select * from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a differential Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock
}

if [ -z "$1" ]; then CHECKTYPE="full"; else CHECKTYPE=$1; fi
if [ $CHECKTYPE == "full" ]; then
  full_art_checkonly
else
  diff_art_checkonly
fi
