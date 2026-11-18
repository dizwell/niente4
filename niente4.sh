#!/usr/bin/env bash
# Niente is a FLAC checker. It tests for physical corruption internal to the
# FLAC file itself; it also checks for logical inconsistencies in the way
# the COMMENT, PERFORMER, ALBUM and YEAR tags have been entered.
#
# Full documentation available at:
# https://absolutelybaching.com/niente-version-4-the-user-manual/
#
# Copyright © Howard Rogers 2019-2026
# Version 4.1 - release date not yet set (??)
#
# This program is free software: you can redistribute it and/or modify
# it under the terms of the GNU General Public License as published by
# the Free Software Foundation, version 2.0 only of the License.
#
# This program is distributed in the hope that it will be useful,
# but WITHOUT ANY WARRANTY; without even the implied warranty of
# MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
# GNU General Public License for more details.
#
# A copy of the GNU General Public License can be  can be displayed by running the program
# and selecting the Miscellaneous menu, Option 2.
#
# The `tput` wrapper used throughout Niente is taken from https://github.com/bahamas10/bash-tput
# with grateful thanks to Dave Eddy and much appreciation: it speeds things up immensely!
#
# Version History
# ---------------
# 1.00  Initial Release                                                01.07.21
# 2.00  Enhancements and bug-fixes                                     01.11.21
# 3.00  Major re-write and enhancement to functionality                26.02.23
# 4.00  Significant code refactoring and workflow enhancements         10.09.24
# 4.01  Enhancement: Sample Rate collected & used as well as bit-depth 08.10.24
# 4.02  Bug-fixes: environment variables not set correctly             12.10.24
# 4.03  A few bug-fixes and enhancements                               10.04.25
# 4.04  Significant re-write to run on macOS and improve performance   28.02.26
# 4.05  Bug fix in Integrity Check regarding ReplayGain, changed
#       menus and colour-picker capability                             28.03.26
# ==============================================================================================================
# If the folder Niente was started from no longer exists (moved or deleted since the Terminal was in it), start in the home folder instead
if [[ ! -d $PWD ]]; then cd "$HOME" 2>/dev/null || exit 1; fi
PROGFILE="${BASH_SOURCE[0]}"                      # This script's own path (a symlink such as /usr/local/bin/niente is fine)
if ! sed -n '10p' "$PROGFILE" | grep -q '?'; then PROGVERSION="4.1"; else PROGVERSION="4.1-beta"; fi
echo -ne "\033]0;Niente: The Music Integrity Manager\007"
CONFDIR="$HOME/.local/share/niente4"  OLDIFS=$IFS  NODIALOG=0
mkdir -p "$CONFDIR" "$CONFDIR/txt" "$CONFDIR/bin" "$CONFDIR/tmp" "$CONFDIR/art" "$CONFDIR/db" 2>/dev/null	   # Create a folder structure, if it doesn't already exist (and suppress errors if it does!)
trap ctrl_c INT  # Trap to quit nicely if Ctrl+C issued

function parse_config {
source "$CONFDIR/bin/nenparse.sh"
}

function exit_program {
# As Semplice: restore the cursor and colours and clear the screen (no 'reset', which is slow and wipes the scrollback)
if [[ -t 1 ]]; then tput cvvis; tput sgr0; clear; fi
exit 0
}

function take_lock {
# One program lock (tmp/nientelock) is shared by every scan and check, menu or unattended, and holds the process
# number of the Niente session that took it. A lock whose process is still running (and is Niente) is genuine:
# refuse (return 1). A lock whose process has gone, or is no longer Niente, is a leftover: remove it, note that
# in the log, and take a new lock for this session.
local LOCKFILE="$CONFDIR/tmp/nientelock" LOCKPID
if ( set -o noclobber; echo "$$" > "$LOCKFILE" ) 2>/dev/null; then return 0; fi
LOCKPID=$(head -n 1 "$LOCKFILE" 2>/dev/null); LOCKPID=${LOCKPID//[^0-9]/}
if [[ $LOCKPID == "$$" ]]; then return 0; fi                                       # Already this session's own lock
if [[ -n $LOCKPID ]] && ps -p "$LOCKPID" -o args= 2>/dev/null | grep -qi "niente"; then return 1; fi
rm -f "$LOCKFILE" >/dev/null 2>&1
if [[ -n $DBNAME && -f "$CONFDIR/db/$DBNAME.db" ]]; then
  sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into refresh_logs values ('$(date +"%Y-%m-%d : %H:%M:%S")','Removed a leftover program lock (its Niente session${LOCKPID:+, process $LOCKPID,} is no longer running)');" .exit >/dev/null 2>&1
fi
if ( set -o noclobber; echo "$$" > "$LOCKFILE" ) 2>/dev/null; then return 0; fi
return 1
}

function release_lock {
# Only ever remove this session's own lock, never one held by another Niente session
local LOCKPID
LOCKPID=$(head -n 1 "$CONFDIR/tmp/nientelock" 2>/dev/null); LOCKPID=${LOCKPID//[^0-9]/}
if [[ $LOCKPID == "$$" ]]; then rm -f "$CONFDIR/tmp/nientelock" >/dev/null 2>&1; fi
}

function ctrl_c() {
  exit_program
}

function nmenuoptions {
tput civis
source "$CONFDIR/bin/nmenudraw.sh"
source "$CONFDIR/bin/nmenuoptions.sh"
}

function nsubmenuoptions {
tput civis; clear
source "$CONFDIR/bin/nmenudraw.sh"
source "$CONFDIR/bin/nsubmenuoptions.sh"
}

function menu_display {
clear; nmenuoptions database; clear
}

# A function to display a progress indicator
# -----------------------------------------------------------------------------
function spinner {
tput civis
tput cup 25 1; printf $LINEDRAW2%.0s {1..101}
spin=()
pid=$!    # Process Id of the previous running command
spin[0]="◐";spin[1]="◓";spin[2]="◑";spin[3]="◒"
MSGLENGTH=${#MESSAGE}
tput cup 25 4; echo -en "                                                                                               "
tput cup 25 4; tput setaf $INFOTEXT; echo -en "$MESSAGE"; tput setaf $SPINNER; 
while kill -0 $pid 2>/dev/null;
do
  for i in "${spin[@]}"
  do
    tput cup 25 $((MSGLENGTH+6)); echo -ne "$i"
    sleep .1
  done
done
tput cvvis
}

# Functions for the data-loss guard (used by every refresh and by Wipe & re-load, menu and unattended alike)
# -----------------------------------------------------------------------------
function list_music_folder {
# Find every FLAC in the music folder and load the list into the loadfiles table
rm -f "$CONFDIR/txt/fsalbums.txt" "$CONFDIR/txt/fsalbums-sorted.txt" >/dev/null 2>&1
if [ "$FDPROG" == "fd" ]; then
  fd -j $THREADS -t f -e flac . "$MUSICDIR" >> "$CONFDIR/txt/fsalbums.txt" & spinner $!
else
  find "$MUSICDIR" -name "*.flac" >> "$CONFDIR/txt/fsalbums.txt" & spinner $!
fi
sort "$CONFDIR/txt/fsalbums.txt" | uniq > "$CONFDIR/txt/fsalbums-sorted.txt"
sqlite3 "$CONFDIR/db/$DBNAME.db" "delete from loadfiles" .exit > /dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd ".separator '|'" -cmd ".import $CONFDIR/txt/fsalbums-sorted.txt loadfiles" .exit
}

function check_data_loss {
# Compare the database with the list just loaded by list_music_folder. If more than a fifth of the database's tracks
# were not found in the music folder (an unmounted or partly available share, say), return 1 and leave the counts in
# DBTRACKS and LOSTTRACKS, plus a ready-made warning (LOSSWARN) and log line (LOSSLOG). An empty database can never trip it.
DBTRACKS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "select count(*) from tracks" 2>/dev/null); DBTRACKS=$((DBTRACKS))
LOSTTRACKS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "select count(*) from tracks t where not exists (select 1 from loadfiles where filename=t.filename)" 2>/dev/null); LOSTTRACKS=$((LOSTTRACKS))
LOSSWARN="\\n$LOSTTRACKS of the $DBTRACKS tracks in the database could not be found in your music folder. Continuing would remove them from the database, along with their integrity-check results. Is your music folder fully available?\\n\\nAre you sure you want to continue?"
LOSSLOG="Unattended scan refused: $LOSTTRACKS of $DBTRACKS tracks in the database were not found in the music folder (more than a fifth), so nothing has been changed. If they really have gone, run a refresh from the menu."
if (( DBTRACKS > 0 && LOSTTRACKS * 5 > DBTRACKS )); then return 1; fi
return 0
}

function tidy_music_list {
rm -f "$CONFDIR/txt/fsalbums.txt" "$CONFDIR/txt/fsalbums-sorted.txt" >/dev/null 2>&1
}

# A function to test that a named database exists and is usable
# -----------------------------------------------------------------------------
function check_database {
if [ -z "$DBNAME" ]; then
  dialog --stdout --backtitle "Niente Database Management" --title " No database specified " --msgbox "\\nThis Niente session is not configured to use a database, so nothing meaningful can be achieved.\\n\\nQuitting back to the main menu in the meantime." 12 80
  menu_display
elif [ ! -f "$CONFDIR/db/$DBNAME.db" ]; then
  dialog --stdout --backtitle "Niente Database Management" --title " Music Database doesn't exist! " --msgbox "\\nYour persistent configuration file mentions a database called $DBNAME but no such database appears to exist. Use the Database menu to create a database of that name before proceeding. \\n\\nQuitting back to the main menu in the meantime." 12 80
  menu_display
fi

# If you get this far, a database has been specified and exists, but is it valid?
# -----------------------------------------------------------------------------
VALIDDB=$(sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd "PRAGMA schema_version;" .exit 2>&1)
if [[ ${VALIDDB^^} == *"ERROR"* ]] || [[ $VALIDDB -eq 0 ]]; then
  dialog --stdout --backtitle "Niente Database Management" --title " Music Database is invalid! " --msgbox "\\nYour persistent configuration file mentions a database called $DBNAME and whilst a file of that name exists, it isn't a valid database. Use the Administration menu to configure Niente to use a valid database. \\n\\nQuitting back to the main menu in the meantime." 12 80
  menu_display
  VALIDDATABASE=0
else
  VALIDDATABASE=1
fi
}

function tracks_trigger {
if [[ -f $CONFDIR/db/$DBNAME.db ]]; then
  # Check if REPLAYGAIN column exists for the tracks table
  COLUMN_EXISTS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "SELECT count(*) FROM pragma_table_info('TRACKS') WHERE name='REPLAYGAIN';")

  # Add the column only if the count is 0
  if [ "$COLUMN_EXISTS" -eq 0 ]; then
    sqlite3 "$CONFDIR/db/$DBNAME.db" "ALTER TABLE TRACKS ADD COLUMN REPLAYGAIN TEXT;"
  fi
fi
}

# ===========================================================================================================
# The actual program control code
# ===========================================================================================================
clear
source "$CONFDIR/bin/nentput.sh"                     # The fast tput wrapper (installed with Niente, like every other script)

# Check if parameters have been passed. If so, run non-interactively. Otherwise launch program normally
for i in "$@"; do
  case $i in
    --scan-full)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nennukedbnd.sh" quiet && source "$CONFDIR/bin/nenrefreshdbnd.sh"; clear; exit_program;;
    --scan-new)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenrefreshdbnd.sh"; clear; exit_program;;
    --check-full)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenintegritynd.sh" full; clear; exit_program;;
    --check-differential)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenintegritynd.sh" diff; clear; exit_program;;
    --check-fast)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenintegritynd.sh" logic; clear; exit_program;;
    --check-art)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenartscannd.sh"; clear; exit_program;;
    --check-volume)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenvolchknd.sh" full; clear; exit_program;;
    --aggstats)
      source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; parse_config; check_database; source "$CONFDIR/bin/nenaggstatnd.sh" full; clear; exit_program;;
  esac
done

tput civis; printf '\e[8;28;103t'			# Setting terminal virtual size to 103x28, regardless of what it's actually set to
source "$CONFDIR/bin/nenoscheck.sh"
source "$CONFDIR/txt/programvariables.txt"																# Apply particular program variables that are needed, and which are OS-dependent
parse_config                                                          # As Semplice: read the configuration only once the bundled programs are known

# If at this point we discover database name is null, we need to prompt for one to
# use as 'the session database'.
if [ -z "$DBNAME" ]; then source "$CONFDIR/bin/nennodb.sh" database; fi

# If a database name is specified, check it's valid
if [[ ! -z $DBNAME ]]; then
  check_database
  if [[ $VALIDDATABASE -eq 1 ]]; then
    # Check for version 4.03 that TRACKTITLE exists as a column
    TRACKTITLESQL="select count(*) from pragma_table_info('TRACKS') where name='TRACKTITLE'"
    TRACKTITLE_EXISTS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "$TRACKTITLESQL" .exit)
    if [[ $TRACKTITLE_EXISTS -eq 0 ]]; then
      SQLSTMT="alter table TRACKS add column TRACKTITLE text"
      sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
    fi

    # Adds the SAMPLE_RATE column to the selected Niente database if it's not already present
    SRATESQL="select count(*) from pragma_table_info('TRACKS') where name='SAMPLE_RATE'"
    SRATE_EXISTS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "$SRATESQL" .exit)
    if [ $SRATE_EXISTS -eq 0 ]; then
      SQLSTMT="alter table TRACKS add column SAMPLE_RATE integer"
      sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
    fi
  fi
fi

tracks_trigger
nmenuoptions database
exit_program
tput cvvis
exit 0
# ===========================================================================================================
# Thank you for using Niente. I hope it helps you keep your digital music in good shape.
# ===========================================================================================================
