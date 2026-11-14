#!/usr/bin/env bash
####################################################################
#
# ablibnennodb: routine to set a working database if a default database
# and/or music folder has not been configured. These set per-session
# working values if not.
#
####################################################################

function select_working_database {
# Check if any databases exist we might use for this session
DBCOUNT=$(ls "$CONFDIR/db/"*.db 2>/dev/null | wc -l)

if [ $DBCOUNT -gt 0 ]; then
  dialog --stdout --backtitle "Niente Change Working Database" --title " Change this session's database " --msgbox "\\nSelect one of the following database(s) to act as this session's working database.\\n\\nClick OK to continue." 12 80
  for i in "$CONFDIR/db/"*.db; do
    DBNM="$(basename $i)"; DBNM="${DBNM%.*}"
    DBLIST=$(echo $DBLIST $DBNM $DBNM off)
  done

  CHOSENDB=$(dialog --no-tags --backtitle "Niente set Working Database" --radiolist "Enter the name of the database to be used:" 15 90 0 $DBLIST  3>&1 1>&2 2>&3 3>&- )
  exitStatus=$?
  if [ $exitStatus -eq 1 ]; then
    GOODSOURCE=0
  else
    SOURCEDB="$CHOSENDB"
    GOODSOURCE=1
  fi

  if [ -z "$SOURCEDB" ]; then           # If Cancel is pressed, we need to make sure the database name is set back to null
    SOURCEDB=""
    GOODSOURCE=0
  fi

  unset DBLIST
  unset DBNM
  unset CHOSENDB

  if [ $GOODSOURCE -eq 1 ]; then
    /usr/bin/dialog --stdout --backtitle "Niente Working Database Selection" --msgbox "Database '$SOURCEDB' will now be used as this session's working database. \\n\\nPress OK to continue." 8 80
    DBNAME="$SOURCEDB"
  else
    /usr/bin/dialog --stdout --backtitle "Niente Working Database Selection" --msgbox "No database has been selected for this session. You'll need to create or select one before you can meaningfully use Niente further.\\n\\nPress OK to continue." 8 80
  fi

  # Adds the SAMPLE_RATE column to the selected Niente database if it's not already present
  SRATESQL="select count(*) from pragma_table_info('TRACKS') where name='SAMPLE_RATE'"
  SRATE_EXISTS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "$SRATESQL" .exit)
  if [ $SRATE_EXISTS -eq 0 ]; then
    SQLSTMT="alter table TRACKS add column SAMPLE_RATE integer"
    sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  fi

  # Check for version 4.03 that TRACKTITLE exists as a column, add it if not
  TRACKTITLESQL="select count(*) from pragma_table_info('TRACKS') where name='TRACKTITLE'"
  TRACKTITLE_EXISTS=$(sqlite3 "$CONFDIR/db/$DBNAME.db" "$TRACKTITLESQL" .exit)
  if [[ $TRACKTITLE_EXISTS -eq 0 ]]; then
    SQLSTMT="alter table TRACKS add column TRACKTITLE text"
    sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  fi

else
  # There are no databases we can use, so just warn and return
  dialog --stdout --backtitle "Niente Working Database Selection" --title " No working database " --msgbox "\\nThis Niente session is not using a database: you'll need to create one before you can meaningfully use Niente further.\\n\\nClick OK to continue." 12 80
  GOODSOURCE=0
  return
fi
}

function select_working_musicfolder {
# If there is no default music folder, check if DBNAME is set. If it is, we can usefully prompt for a music folder. Otherwise, just return
if ! [ -z "$DBNAME" ]; then
  tput cvvis
  FLACCOUNT=0; CHOSENFOLDER="$(pwd)"

  while [ $FLACCOUNT -eq 0 ]; do
    NEWDIR=$(dialog --backtitle "Niente set Working Music Folder" --title " Please choose a folder containing one or more FLACs " --dselect "$CHOSENFOLDER" 12 80  3>&1 1>&2 2>&3 3>&- )
    exitStatus=$?
    if [ $exitStatus -eq 1 ] || [ $exitStatus -eq 255 ]; then break; fi
    FLACCOUNT=$(find "$CHOSENFOLDER" -type f -name "*.flac" 2>/dev/null | wc -l)
    if [ $FLACCOUNT -eq 0 ]; then
      CHOSENFOLDER="$NEWDIR"
    fi
  done
  MUSICDIR="$NEWDIR"
  tput civis
  return
else
  return
fi
}

if [[ $1 == "database" ]]; then select_working_database; fi
if [[ $1 == "folder" ]]; then select_working_musicfolder; fi
