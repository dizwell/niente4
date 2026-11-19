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
# Take the program lock first, in both modes, so a wipe never runs underneath another scan or check
if [ "$callmode" == "quiet" ] && ! music_folder_ok; then return 1; fi   # Wipe & re-load needs a real music folder
if ! take_lock; then
  dialog --stdout --backtitle "Niente Database Wipe" --title " Application lock present! " --msgbox "\\nAnother Niente session is currently running a scan or check, so this one cannot proceed.\\n\\nPlease try again when it has finished. Click OK to return to the main menu." 12 80
  return 1
fi
# Wipe & re-load only: check the music folder first. If more than a fifth of the database's tracks weren't found,
# warn before anything is wiped (a plain wipe, option 4, deliberately empties the database, so isn't checked)
if [ "$callmode" == "quiet" ]; then
  tput cup 25 4; tput setaf $MAINTEXT
  MESSAGE="Checking your music folder: please wait..."
  list_music_folder
  tidy_music_list
  if ! check_data_loss; then
    if ! dialog --backtitle "Niente Database Wipe" --title " Data Loss Warning! " --no-mouse --defaultno --yesno "$LOSSWARN" 14 80; then
      release_lock
      return 1
    fi
  fi
fi
# Only ask when there's something to lose: a database with no tracks (one just created, say) is wiped without asking
WIPETRACKS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "select count(*) from tracks" 2>/dev/null); WIPETRACKS=$((WIPETRACKS))
if (( WIPETRACKS > 0 )); then
  if ! dialog --backtitle "Niente Database Wipe" --title " Confirm Database Wipe " --no-mouse --defaultno --yesno "$WIPEWARN\n\n$WIPEASK" 14 80; then
    release_lock
    return 1
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

release_lock
if [ "$callmode" == "verbose" ]; then
 dialog --stdout --backtitle "Niente Database Wipe" --title " Database wiped! " --msgbox "\\nThe $DBNAME database has been successfully wiped. \\n\\nIt can be re-populated by running a fresh data reload at any time. Click OK to return to the main menu." 12 80
fi
}

if [ -z "$1" ]; then callmode="verbose"; else callmode=$1; fi
nuke_database
