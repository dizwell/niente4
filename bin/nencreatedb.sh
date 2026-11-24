#!/usr/bin/env bash
####################################################################
#
# nencreatedb: routine for creating a music database for
# Niente to work with
#
####################################################################
GOODDB=0; EXISTINGDB="$DBNAME"

function create_database {
  while [ $GOODDB -eq 0 ]; do
    DBNAME=$(dialog --stdout --backtitle "Niente Database Creation" --inputbox "Enter the name of a database to be created:" 8 80 )
    exitStatus=$?
    DBNAME=$(clean_dbname "$DBNAME")                         # NTFS-safe and Niente-usable: "Music Master" becomes "Music_Master"
    # If they cancel or escape, quit out of the loop
    if [ $exitStatus -eq 1 ]  || [ $exitStatus -eq 255 ]; then
      GOODDB=0
      DBNAME="$EXISTINGDB"
      break
    fi

    # If they submit a name already in use, warn and keep prompting
    if [ -f "$CONFDIR/db/$DBNAME.db" ] && [ ! -z "$DBNAME" ]; then
      dialog --stdout --backtitle "Niente Database Creation" --title " Music database already exists! " --msgbox "\\nA database with the configured name appears to already exist. Whilst that could be *refreshed*, it can't be recreated from scratch. Quitting back to the main menu in the meantime." 12 80
      GOODDB=0
    fi

    # If they submit a blank database name, warn and keep prompting
    if [ -z "$DBNAME" ]; then
      dialog --stdout --backtitle "Niente Database Creation" --title " A music database name has not been specified! " --msgbox "\\nYou cannot leave the database name blank: try again!" 12 80
      GOODDB=0
    fi

    if [ ! -z "$DBNAME" ] &&  [ ! -f "$CONFDIR/db/$DBNAME.db" ]; then
      GOODDB=1
    fi
  done

# Should only get this far with GOODDB set to 1
if [ $GOODDB -eq 1 ]; then
  sqlite3 "$CONFDIR/db/$DBNAME.db" << EOF
  create table tracks (ID integer not null, FILENAME text, BITDEPTH integer, SAMPLE_RATE integer, LAST_CHECK_DATE text, HASH_ORIG text, HASH_NEW text, ALBUM_YEAR text, DATE_TAG text, PERFORMER text, COMMENT text, TRACKNUMBER text, ALBUMNAME text, ARTISTNAME text, COMPOSERNAME text, GENRENAME text, TRACKTITLE text, REPLAYGAIN text, primary key (id autoincrement));
  create table albumart (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));
  create table maxvolumes (ID integer not null, FILENAME text, BOOST numeric, primary key (id autoincrement));
  create table refresh_logs (OPERATION_DATE text, OPERATION text);
  create table loadfiles (FILENAME text);
  create unique index idx_tracks_id on tracks(id);
  create index idx_tracks_filename on tracks(filename);
EOF
  # Update the activities log...
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Creating a Niente database');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd "PRAGMA journal_mode=TRUNCATE;" .exit >/dev/null 2>&1
  # sqlite3 "$CONFDIR/db/$DBNAME.db" -cmd "PRAGMA journal_mode=TRUNCATE;" .exit >$CONFDIR/db/$DBNAME.walmode;
  # If this is the only database, make it the configured default (backing the configuration up first, as the
  # configuration form does). With others already there, which should be the default is the user's choice.
  DBFILES=("$CONFDIR"/db/*.db)
  if [[ ${#DBFILES[@]} -eq 1 && -f "$CONFDIR/txt/niente.conf" ]]; then
    cp "$CONFDIR/txt/niente.conf" "$CONFDIR/txt/niente.conf-$(date +%F-%T).bkp"
    BKPS=("$CONFDIR/txt"/niente.conf-*.bkp)
    if [[ ${#BKPS[@]} -gt 10 && -f ${BKPS[0]} ]]; then rm -f "${BKPS[@]:0:${#BKPS[@]}-10}"; fi
    if grep -q '^DBNAME=' "$CONFDIR/txt/niente.conf"; then
      $SEDPROG -i "s|^DBNAME=.*|DBNAME=\"$DBNAME\"|" "$CONFDIR/txt/niente.conf"
    else
      echo "DBNAME=\"$DBNAME\"" >> "$CONFDIR/txt/niente.conf"
    fi
  fi
  dialog --stdout --backtitle "Niente Database Creation" --title " Database successfully created! " --msgbox "\\nA database called "$DBNAME" has been successfully created. \\n\\nYou should now perform a scan for your music to populate it.\\n\\nClick OK to continue." 12 80
else
  return
fi
}

if [ -z "$DBNAME" ]; then NAMEPROMPT=1; else NAMEPROMPT=0; fi
create_database
