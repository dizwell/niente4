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
rm -f "$CONFDIR/txt/programvariables.txt" >/dev/null 2>&1;
if [[ -t 1 ]]; then
  tput cvvis
  tput sgr0
  clear
  reset
fi
exit 0
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
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nennukedbnd.sh" quiet; source "$CONFDIR/bin/nenrefreshdbnd.sh"; clear; exit_program;;
    --scan-new)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenrefreshdbnd.sh"; clear; exit_program;;
    --check-full)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenintegritynd.sh" full; clear; exit_program;;
    --check-differential)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenintegritynd.sh" diff; clear; exit_program;;
    --check-fast)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenintegritynd.sh" logic; clear; exit_program;;
    --check-art)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenartscannd.sh"; clear; exit_program;;
    --check-volume)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenvolchknd.sh" full; clear; exit_program;;
    --aggstats)
      parse_config; check_database; source "$CONFDIR/bin/nenoscheck.sh"; source "$CONFDIR/txt/programvariables.txt"; source "$CONFDIR/bin/nenaggstatnd.sh" full; clear; exit_program;;
  esac
done

tput civis; printf '\e[8;28;103t'			# Setting terminal virtual size to 103x28, regardless of what it's actually set to
parse_config

source "$CONFDIR/bin/nenoscheck.sh"
source "$CONFDIR/txt/programvariables.txt"																# Apply particular program variables that are needed, and which are OS-dependent

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
