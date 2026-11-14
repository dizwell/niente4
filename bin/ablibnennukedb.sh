#!/usr/bin/env bash
####################################################################
#
# ablibnennukedb: routine for wiping a database of all of its
# contents
#
####################################################################

function nuke_database {
check_database
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
