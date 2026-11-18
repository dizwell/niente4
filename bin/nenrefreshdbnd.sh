#!/usr/bin/env bash
####################################################################
#
# nenrefreshdb: routine for re-scanning music files and
# re-populating the database with their metadata details. Same as
# the main refresh module, but with no output to screen.
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

function refresh_database {
tput civis;
check_database

# Check the database has a loadfiles, logging, maxvolumes, messages and albumart table and an index on filename
SQLSTMT="create table if not exists refresh_logs (OPERATION_DATE text, OPERATION text);"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
SQLSTMT="create table if not exists albumart (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
SQLSTMT="create table if not exists maxvolumes (ID integer not null, FILENAME text, BOOST numeric, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
SQLSTMT="create table if not exists loadfiles (FILENAME text);"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
SQLSTMT="create index if not exists idx_tracks_filename on tracks(filename);"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
SQLSTMT="create index if not exists idx_loadfiles_filename on loadfiles(filename);"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a database refresh');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Database refresh aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

tput civis
INSERTCOUNT=0

# Begin the file system search for FLACs, loading the list into the loadfiles table
list_music_folder

# Data-loss guard: if more than a fifth of the database's tracks weren't found, change nothing and say why in the log
if ! check_data_loss; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into refresh_logs values ('$TODAYDATE','$LOSSLOG');" .exit > /dev/null 2>&1
  tidy_music_list
  release_lock
  return 1
fi

# At this point, the loadfiles text file contains a list of every FLAC found to be extant on the file system.
# With SQL, we can find things in it which aren't in the TRACKS table: these are new recordings.
# And if there are things in TRACKS which aren't in loadfiles, these are old recordings which are no longer
# extant on the file system and which should therefore be deleted from the TRACKS table.

# So, first: load newly discovered files into TRACKS
SQLSTMT="insert into tracks (filename) select filename from loadfiles l where not exists (select 1 from tracks where filename=l.filename)"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# And now: delete anything in TRACKS which no longer exists on disk
SQLSTMT="delete from tracks where filename in (select filename from tracks t where not exists (select 1 from loadfiles where filename=t.filename))"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a database refresh');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Tidy Up
rm -f "$CONFDIR/txt/fsalbums.txt" 2>/dev/null
rm -f "$CONFDIR/txt/fsalbums-sorted.txt" > /dev/null 2>&1
release_lock
rm -f "$CONFDIR/txt/nienterecs.txt" >/dev/null 2>&1
tput cvvis
}

refresh_database
