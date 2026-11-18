#!/usr/bin/env bash
####################################################################
#
# nenrefreshdb: routine for re-scanning music files and
# re-populating the database with their metadata details
#
####################################################################

function refresh_database {
tput civis;
FSSCAN=X

if [ -z "$DBNAME" ]; then
  dialog --stdout --backtitle "Niente Scan for Music" --title " No database specified " --msgbox "\\nThis Niente session is not configured to use a database, so nothing meaningful can be achieved.\\n\\nClick OK to return to the main menu." 12 80
  return
fi

if [ -z "$MUSICDIR" ]; then
  dialog --stdout --backtitle "Niente Scan for Music" --title " No music folder specified " --msgbox "\\nYou haven't specified a folder containing FLACs to scan, so nothing can be added to the database at this time.\\n\\nClick OK to return to the main menu." 12 80
  return
fi

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
  dialog --stdout --backtitle "Niente Scan for Music" --title " Application lock present! " --msgbox "\\nAnother Niente session is currently running a scan or check, so this one cannot proceed.\\n\\nPlease try again when it has finished. Click OK to return to the main menu." 12 80
  return
fi

tput civis
rm -f "$CONFDIR/txt/fsalbums.txt" 2>/dev/null
rm -f "$CONFDIR/txt/fsalbums-sorted.txt" > /dev/null 2>&1
INSERTCOUNT=0

# Begin the file system search for FLACs
tput cup 25 4; tput setaf $MAINTEXT; echo -en "Scanning for new/changed files: "
MESSAGE="Please wait..."

if [ "$FDPROG" == "fd" ]; then
  fd -j $THREADS -t f -e flac . "$MUSICDIR" >> "$CONFDIR/txt/fsalbums.txt" & spinner $!
else
  find "$MUSICDIR" -name "*.flac" >> "$CONFDIR/txt/fsalbums.txt" & spinner $!
fi

sort "$CONFDIR/txt/fsalbums.txt" | uniq > "$CONFDIR/txt/fsalbums-sorted.txt"

# Load the whole thing into the loadfiles table, having wiped the existing contents first
SQLSTMT="delete from loadfiles"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd ".separator '|'" -cmd ".import $CONFDIR/txt/fsalbums-sorted.txt loadfiles" .exit

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

# Finally, count number of records in the TRACKS table
SQLSTMT="select count(*) from tracks"
RECCOUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit)
dialog --stdout --backtitle "Niente Database Refresh" --title " File Scan and Database Refresh Complete! " --msgbox "\\nYour music files have been scanned and added to the database, which now knows of $RECCOUNT separate FLACs.\\n\\nUse the Integrity Checking menu to analyse these files in detail.\\n\\nClick OK to return to the main menu." 12 80

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

function check_existing_recordcount {
dialog --stdout --backtitle "Niente Scan for Music" --title " Scanning for Music " --infobox "\\nChecking your music folder: please hold on..." 8 80
RECCOUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "select count(*) from tracks"); RECCOUNT=$((RECCOUNT))
FLACCOUNT=$(find "$MUSICDIR" -type f -iname '*.flac' | wc -l);FLACCOUNT=$((FLACCOUNT))
# Check if FLACCOUNT is more than 80% smaller than RECCOUNT. That is, FLACCOUNT < 20% of RECCOUNT
THRESHOLD=$(( RECCOUNT / 5 ))  # 20% of RECCOUNT

if (( FLACCOUNT < THRESHOLD )); then
  dialog --stdout --backtitle "Niente Scan for Music" --title " Data Loss Warning! " --yesno "\\nThe music folder selected appears to have considerably fewer records than already exist in the database: this will result in substantial data loss.\\n\\nAre you sure you want to continue?" 12 80

  if [[ $? -ne 0 ]]; then  # 0 = Yes, so anything other than a positive selection of 'yes' is taken to mean 'abort'.
      dialog --stdout --backtitle "Niente Scan for Music" --title " Scan Cancelled! " --msgbox "\\nThe proposed scan for new music files has been cancelled.\\n\\nNothing about your existing Niente database has been altered." 12 80
  else
    refresh_database
  fi
else
  refresh_database
fi
}

if [ -z "$MUSICDIR" ]; then source "$CONFDIR/bin/nennodb.sh" folder; fi
check_existing_recordcount

