#!/usr/bin/env bash
####################################################################
#
# ablibnenartscan: routine for checking the state of embedded
# album art within known FLACs
#
####################################################################
SECONDS=0
function full_art_checkonly {
FSSCAN=X
check_database

SQLSTMT="create table if not exists albumart_load (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! [ -f "$CONFDIR/tmp/nientelock" ]; then
  touch "$CONFDIR/tmp/nientelock"
else
  dialog --stdout --backtitle "Niente Album Art Check" --title " Application lock present! " --msgbox "\\nOnly one administrative option can run at a time, but you appear to be already running one. This new one cannot therefore proceed. \\n\\nManually remove the program lock (by tapping the 'L' key) if you think this message has appeared in error. Click OK to return to the main menu." 12 80
  return
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a full Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

ARTSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
ARTSCAN_SQL="select id, filename from tracks order by filename"

if [ $ARTSCAN_COUNT -eq 0 ]; then
  dialog --stdout --backtitle "Niente Album Art Check" --title " No candidate recordings! " --msgbox "\\nThe current working database knows of no recordings to analyse for album artwork issues.\\n\\nClick OK to return to the main menu." 12 80
  rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
  return
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$ARTSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t artcheck < "$CONFDIR/txt/nienterecs.txt"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name='albumart_load'"
#display_progress
COUNTER=0

(
for f in "${artcheck[@]}"; do
  fileid=$(echo "$f" | awk -F'|' '{print $1}')
  filename=$(echo "$f" | awk -F'|' '{print $2}')
  COUNTER=$((COUNTER+1))
  HOURS=$(( SECONDS / 3600 ))
  MINS=$(( (SECONDS % 3600) / 60 ))
  SECS=$(( SECONDS % 60 ))
  ELAPSED=$(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)
  
  # Calculate ETA (HH:MM:SS)
  if (( COUNTER > 1 )); then
    if (( COUNTER % 25 == 0 )); then
      REMAINING_SECONDS=$(( (ARTSCAN_COUNT - COUNTER) * SECONDS / COUNTER ))
      ETA_H=$(( REMAINING_SECONDS / 3600 ))
      ETA_M=$(( (REMAINING_SECONDS % 3600) / 60 ))
      ETA_S=$(( REMAINING_SECONDS % 60 ))
      ETA=$(printf "%02d:%02d:%02d" $ETA_H $ETA_M $ETA_S)
    fi
  else
    ETA="--:--:--"
  fi
  
  if [ -z "$filename" ]; then filename='QxQxQx'; fi
  if [ -f "$filename" ]; then
    COMPOSERNAME=$(metaflac $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed s/.*=//g)
    ALBUMNAME=$(metaflac $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
    DISP_ALBUMNAME="${ALBUMNAME:0:75}"
    ARTWIDTH=$(metaflac --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 width | awk '{print $2}'); if [ -z "$ARTWIDTH" ]; then ARTWIDTH=9999; fi
    ARTHEIGHT=$(metaflac --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 height | awk '{print $2}'); if [ -z "$ARTHEIGHT" ]; then ARTHEIGHT=9999; fi
    if [[ $ARTWIDTH -eq 9999 ]]; then 
      ARTSTRING="Embedded artwork not present"
    else 
      ARTSTRING="Embedded art found at $ARTWIDTH x $ARTWIDTH pixels"
    fi
    
    PERCENTAGE=$(( 100 * COUNTER / ARTSCAN_COUNT ))
    echo -e "XXX\n$(printf '\u00a0')\n\
 Composer  : $COMPOSERNAME\n\
 Recording : $DISP_ALBUMNAME\n\
 Art Size  : $ARTSTRING\n\
 Elapsed   : $(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)\n\
 ETA       : $ETA\n\n\
 Processing file $COUNTER of $ARTSCAN_COUNT\nXXX"
    echo "$PERCENTAGE"  
    
    # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    artfilename=${filename//\'/\'\'}
    artfilename="${artfilename//\"/##@##}"
    
	SQLSTR="insert into albumart_load (filename, albumartheight, albumartwidth) values ('$artfilename','$ARTHEIGHT','$ARTWIDTH')"
	sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"  >/dev/null 2>&1
  fi
done
) | dialog --backtitle "Niente Full Album Art Check" \
           --title " Analysing Music Files " \
           --no-collapse \
           --gauge "Initialising..." 15 95 0
           
# If there were dodgy characters that were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update albumart_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name='albumart'"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into albumart select * from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
dialog --stdout --backtitle "Niente Album Art Check" --title " Art Check Completed! " --msgbox "\\nThe album art check has completed successfully.\\n\\nClick OK to return to the main menu." 12 80

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a full Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
}

function diff_art_checkonly {
FSSCAN=X
check_database

SQLSTMT="create table if not exists albumart_load (ID integer not null, FILENAME text, ALBUMARTHEIGHT integer, ALBUMARTWIDTH integer, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! [ -f "$CONFDIR/tmp/nientelock" ]; then
  touch "$CONFDIR/tmp/nientelock"
else
  dialog --stdout --backtitle "Niente Album Art Check" --title " Application lock present! " --msgbox "\\nOnly one administrative option can run at a time, but you appear to be already running one. This new one cannot therefore proceed. \\n\\nManually remove the program lock (by tapping the 'L' key) if you think this message has appeared in error. Click OK to return to the main menu." 12 80
  return
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a differential Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
ARTSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks where filename not in (select filename from albumart)")
ARTSCAN_SQL="select id, filename from tracks where filename not in (select filename from albumart) order by filename"

if [ $ARTSCAN_COUNT -eq 0 ]; then
  dialog --stdout --backtitle "Niente Album Art Check" --title " No candidate recordings! " --msgbox "\\nThe current working database knows of no recordings to analyse for album artwork issues.\\n\\nClick OK to return to the main menu." 12 80
  rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
  return
elif [ $ARTSCAN_COUNT -gt 100 ]; then
  dialog --no-label "Cancel" --yes-label "OK" --stdout --backtitle "Niente Album Art Check" --title " Excessive candidate recordings! " --yesno "\\nThe check of 'new' album art needs to analyse the data from over one hundred recordings. This could take a long time to complete.\\n\\nClick OK to proceed or Cancel to return to the main menu." 12 80
  exitstatus=$?
  # 0 means OK was pressed, 1 means Cancel, and 255 means Escape
  if [ $exitstatus -eq 1 ] || [ $exitstatus -eq 255 ]; then
    rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
    return
  fi
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$ARTSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t artcheck < "$CONFDIR/txt/nienterecs.txt"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=(select max(id)+1 from albumart) where name='albumart_load'"
COUNTER=0
  
(
for f in "${artcheck[@]}"; do
  fileid=$(echo "$f" | awk -F'|' '{print $1}')
  filename=$(echo "$f" | awk -F'|' '{print $2}')
  COUNTER=$((COUNTER+1))
  HOURS=$(( SECONDS / 3600 ))
  MINS=$(( (SECONDS % 3600) / 60 ))
  SECS=$(( SECONDS % 60 ))
  ELAPSED=$(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)
  
  # Calculate ETA (HH:MM:SS)
  if (( COUNTER > 1 )); then
    if (( COUNTER % 25 == 0 )); then
      REMAINING_SECONDS=$(( (ARTSCAN_COUNT - COUNTER) * SECONDS / COUNTER ))
      ETA_H=$(( REMAINING_SECONDS / 3600 ))
      ETA_M=$(( (REMAINING_SECONDS % 3600) / 60 ))
      ETA_S=$(( REMAINING_SECONDS % 60 ))
      ETA=$(printf "%02d:%02d:%02d" $ETA_H $ETA_M $ETA_S)
    fi
  else
    ETA="--:--:--"
  fi
  
  if [ -z "$filename" ]; then filename='QxQxQx'; fi
  if [ -f "$filename" ]; then
    COMPOSERNAME=$(metaflac $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed s/.*=//g)
    ALBUMNAME=$(metaflac $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed s/.*=//g)
    DISP_ALBUMNAME="${ALBUMNAME:0:75}"
    ARTWIDTH=$(metaflac --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 width | awk '{print $2}'); if [ -z "$ARTWIDTH" ]; then ARTWIDTH=9999; fi
    ARTHEIGHT=$(metaflac --list --block-type=PICTURE "$filename" 2>/dev/null | $GREPPROG -m 1 height | awk '{print $2}'); if [ -z "$ARTHEIGHT" ]; then ARTHEIGHT=9999; fi
    if [[ $ARTWIDTH -eq 9999 ]]; then 
      ARTSTRING="Embedded artwork not present"
    else 
      ARTSTRING="Embedded art found at $ARTWIDTH x $ARTWIDTH pixels"
    fi
    
    PERCENTAGE=$(( 100 * COUNTER / ARTSCAN_COUNT ))
    echo -e "XXX\n$(printf '\u00a0')\n\
 Composer  : $COMPOSERNAME\n\
 Recording : $DISP_ALBUMNAME\n\
 Art Size  : $ARTSTRING\n\
 Elapsed   : $(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)\n\
 ETA       : $ETA\n\n\
 Processing file $COUNTER of $ARTSCAN_COUNT\nXXX"
    echo "$PERCENTAGE"  
    
    # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    artfilename=${filename//\'/\'\'}
    artfilename="${artfilename//\"/##@##}"
    
	SQLSTR="insert into albumart_load (filename, albumartheight, albumartwidth) values ('$artfilename','$ARTHEIGHT','$ARTWIDTH')"
	sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"  >/dev/null 2>&1
  fi
done
) | dialog --backtitle "Niente Differential Album Art Check" \
           --title " Analysing Music Files " \
           --no-collapse \
           --gauge "Initialising..." 15 95 0

# If there were dodgy characters that were replaced, now put them back
sqlite3 "$CONFDIR/db/$DBNAME.db" "update albumart_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into albumart select * from albumart_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from albumart_load"
dialog --stdout --backtitle "Niente Album Art Check" --title " Art Check Completed! " --msgbox "\\nThe album art check has completed successfully.\\n\\nClick OK to return to the main menu." 12 80

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing a differential Album Art Checkup');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
}

if [ -z "$1" ]; then CHECKTYPE="full"; else CHECKTYPE=$1; fi
if [ $CHECKTYPE == "full" ]; then
  full_art_checkonly
else
  diff_art_checkonly
fi
