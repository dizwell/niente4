#!/usr/bin/env bash
####################################################################
#
# nennukedb: routine for wiping a database of all of its
# contents
#
####################################################################

function nuke_database {
check_database
# A wipe can't be undone, so say what is about to happen and default to No (as Giocoso's restore does).
# 'verbose' is the plain wipe (Database option 4); 'quiet' is the wipe before a full re-load (option 2)
WIPEWARN="\nThis will delete everything in the '$DBNAME' database: every track, its stored hashes and check history, the album-art and volume results, and the refresh logs. It can be re-populated by a fresh scan, but all the integrity checks that Niente performs for a populated database can only be re-created by performing a fresh, lengthy integrity check."
if [ "$callmode" == "quiet" ]; then
  WIPEASK="Are you sure you want to wipe it and re-load it from scratch with a full scan?"
else
  WIPEASK="Are you sure you want to wipe it?"
fi
if ! dialog --backtitle "Niente Database Wipe" --title " Confirm Database Wipe " --no-mouse --defaultno --yesno "$WIPEWARN\n\n$WIPEASK" 14 80; then
  return 1
fi
# Place a lock on disk, so no competing sessions can run
if ! [ -f "$CONFDIR/tmp/nientelock" ]; then
  touch "$CONFDIR/tmp/nientelock"
else
  if [ "$callmode" == "verbose" ]; then
    dialog --stdout --backtitle "Niente Database Wipe" --title " Application lock present! " --msgbox "\\nOnly one file-scanning option can run at a time, but you appear to be already running one. This new one cannot therefore proceed. \\n\\nManually remove the program lock (by tapping the 'L' key) if you think this message has appeared in error. Click OK to return to the main menu." 12 80
    return
  fi
fi

sqlite3 "$CONFDIR/db/$DBNAME.db" << EOF
begin transaction;
delete from tracks;
delete from loadfiles;
delete from refresh_logs;
delete from albumart;
delete from maxvolumes;
update sqlite_sequence set seq=0;
commit;
EOF

rm -f "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
if [ "$callmode" == "verbose" ]; then
 dialog --stdout --backtitle "Niente Database Wipe" --title " Database wiped! " --msgbox "\\nThe $DBNAME database has been successfully wiped. \\n\\nIt can be re-populated by running a fresh data reload at any time. Click OK to return to the main menu." 12 80
fi
}

if [ -z "$1" ]; then callmode="verbose"; else callmode=$1; fi
nuke_database
