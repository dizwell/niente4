#!/usr/bin/env bash
####################################################################
#
# nenvolchk: routine for checking the peak volumes of music
# within a FLAC mentioned in the Niente music database
#
####################################################################
POSSIBLE_BOOSTS=0
SECONDS=0

trap ctrl_c INT  # Trap to quit nicely if Ctrl+C issued

function ctrl_c() {
  release_lock
  exit_program
}

function volumeboost_scan {
tput civis
FSSCAN=X
if [[ $SCANTYPE == "full" ]]; then SCANDESC="Full"; else SCANDESC="Differential"; fi
check_database
SQLSTMT="create table if not exists maxvolumes_load (ID integer not null, FILENAME text, BOOST numeric, primary key (id autoincrement));"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1

# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  dialog --stdout --backtitle "Niente Volume Boost Check" --title " Application lock present! " --msgbox "\\nAnother Niente session is currently running a scan or check, so this one cannot proceed.\\n\\nPlease try again when it has finished. Click OK to return to the main menu." 12 80
  return
fi

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Starting a $SCANTYPE Volume Boost check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"

if [[ $SCANTYPE == "full" ]]; then
  VOLSCAN_COUNT=$(sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"select count(*) from tracks")
  VOLSCAN_SQL="select id, filename from tracks order by filename"
  sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes"
  sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"
  sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"update sqlite_sequence set seq=0 where name in ('maxvolumes_load','maxvolumes')"
  if [[ $VOLSCAN_COUNT -eq 0 ]]; then
    dialog --stdout --backtitle "Niente Volume Boost Check" --title " No candidate recordings! " --msgbox "\\nThe current working database knows of no recordings to analyse for volume boosts.\\n\\nClick OK to return to the main menu." 12 80
  release_lock
  return
  fi
else
  # Note the horror SQL needed to extract only the folder name from a folder/file full path name! It's finding the position of the last '/', and using that to substring back from that
  recheck_selection volume                                            # Never checked, plus folders above the boost threshold (as the report)
fi

if [[ $VOLSCAN_COUNT -eq 0 ]]; then
  dialog --stdout --backtitle "Niente Volume Boost Check" --title " No candidate recordings! " --msgbox "\\nYou've asked to perform a Volume Boost check, but there are no recordings known that can be meaningfully analysed.\\n\\nThis can be because your database simply knows of no recordings; or that all the recordings it knows about have already been determined not to be volume boost candidates.\\n\\nClick OK to return to the main menu." 14 80
  release_lock
  return
fi

# If we get this far, we have at least one file to process, so we can proceed
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"$VOLSCAN_SQL" > "$CONFDIR/txt/nienterecs.txt"
readarray -t volcheck < "$CONFDIR/txt/nienterecs.txt"
COUNTER=0

(
declare -A BOOSTDIRS                                     # Folders holding at least one candidate: boosting is done album by album
for f in "${volcheck[@]}"; do
  fileid="${f%%|*}"; filename="${f#*|}"                 # Split at the first pipe only: a filename may contain one
  COUNTER=$((COUNTER+1))
  HOURS=$(( SECONDS / 3600 ))
  MINS=$(( (SECONDS % 3600) / 60 ))
  SECS=$(( SECONDS % 60 ))
  ELAPSED=$(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)
  
  # Calculate ETA (HH:MM:SS)
  if (( COUNTER > 1 )); then
    if (( COUNTER % 25 == 0 )); then
      REMAINING_SECONDS=$(( (VOLSCAN_COUNT - COUNTER) * SECONDS / COUNTER ))
      ETA_H=$(( REMAINING_SECONDS / 3600 ))
      ETA_M=$(( (REMAINING_SECONDS % 3600) / 60 ))
      ETA_S=$(( REMAINING_SECONDS % 60 ))
      ETA=$(printf "%02d:%02d:%02d" $ETA_H $ETA_M $ETA_S)
    fi
  else
    ETA="--:--:--"
  fi
  
  if [[ -z "$filename" ]]; then filename='QxQxQx'; fi
  if [[ -f "$filename" ]]; then
    COMPOSERNAME=$("$METAFLAC" $UTFCHARS --show-tag=COMPOSER "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    ALBUMNAME=$("$METAFLAC" $UTFCHARS --show-tag=ALBUM "$filename" 2>/dev/null | sed 's/^[^=]*=//')
    DISP_ALBUMNAME="${ALBUMNAME:0:75}"
    LINE=$("$FFMPEG" -nostdin -threads 0 -nostats -i "$filename" -af "volumedetect" -vn -sn -dn -f null - 2>&1 | grep "max_volume")
    MAXV=$(echo "$LINE" | awk '{print $5}' | tr -d '-')
    
    if [[ -z "$MAXV" ]]; then
      MAXV=0.0             # Special case: if max_volume is 0.0, then ffmpeg displays no '+' against it, so the return from the above is null. This sets it back to being 0.0
    else
      MAXV=${MAXV%" dB"}	# Strip the 'dB' suffix from the return: we want only numbers, otherwise we can't do maths with them later
    fi
    if [[ $MAXV == "0.0" || $MAXV == "0" ]]; then DISPLAY_MAXV="0.0 dB"; else DISPLAY_MAXV="-$MAXV dB"; fi
    
    # The logic is inverse here, since we've removed any minus sign. So volume -6 is not 6. If 
    # threshold is 2, we need to say if 6 > 2 then that's a possible volume boost
    if (( $(echo "$MAXV > $VOLUMETHRESHOLD" | bc -l) )); then POSSIBLE_BOOSTS=$((POSSIBLE_BOOSTS+1)); BOOSTDIRS["${filename%/*}"]=1; fi
    if (( POSSIBLE_BOOSTS == 1 )); then BOOSTFILES="1 file"; else BOOSTFILES="$POSSIBLE_BOOSTS files"; fi
    if (( ${#BOOSTDIRS[@]} == 1 )); then BOOSTFOLDERS="1 folder"; else BOOSTFOLDERS="${#BOOSTDIRS[@]} folders"; fi

    
    PERCENTAGE=$(( 100 * COUNTER / VOLSCAN_COUNT ))
    echo -e "XXX\n$(printf '\u00a0')\n\
 Composer    : $COMPOSERNAME\n\
 Recording   : $DISP_ALBUMNAME\n\
 Peak Volume : $DISPLAY_MAXV\n\
 Elapsed     : $(printf "%02d:%02d:%02d" $HOURS $MINS $SECS)\n\
 ETA         : $ETA\n\n\
 Processing file $COUNTER of $VOLSCAN_COUNT\n\
 Possible Volume Boosts found : $BOOSTFILES in $BOOSTFOLDERS (Threshold = -$VOLUMETHRESHOLD dB)\nXXX"
    echo "$PERCENTAGE"  
    
    # Remove dodgy characters. Single quotes are escaped into being two-single quotes.
    # Double quotes are replaced by a meaningless string for now...
    volfilename=${filename//\'/\'\'}
    volfilename="${volfilename//\"/##@##}"
    
	SQLSTR="insert into maxvolumes_load (filename, boost) values ('$volfilename','$MAXV')"
	sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTR"  >/dev/null 2>&1
  fi
done
echo "$POSSIBLE_BOOSTS ${#BOOSTDIRS[@]}" > "$CONFDIR/tmp/boost_count.txt"
) | dialog --backtitle "Niente $SCANDESC Volume Boost Check" \
           --title " Analysing Music Files for Physical Volume Levels " \
           --no-collapse \
           --gauge "Initialising..." 15 95 0

# If dodgy characters were replaced, now put them back
tput cvvis;
sqlite3 "$CONFDIR/db/$DBNAME.db" "update maxvolumes_load set filename=replace(filename,'##@##','\"');" >/dev/null 2>&1
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes where filename in (select filename from maxvolumes_load)"   # Re-checked files: the new result replaces the old
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"insert into maxvolumes select * from maxvolumes_load"
sqlite3 "$CONFDIR/db/$DBNAME.db" <<<"delete from maxvolumes_load"

# Update the activities log...
TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Completing the volume boost check');"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
release_lock

if [[ -f "$CONFDIR/tmp/boost_count.txt" ]]; then
    read -r POSSIBLE_BOOSTS BOOSTFOLDERCOUNT < "$CONFDIR/tmp/boost_count.txt"
    rm "$CONFDIR/tmp/boost_count.txt"
fi
POSSIBLE_BOOSTS=${POSSIBLE_BOOSTS:-0}; BOOSTFOLDERCOUNT=${BOOSTFOLDERCOUNT:-0}
if (( POSSIBLE_BOOSTS == 1 )); then BOOSTFILES="1 potential volume boost"; else BOOSTFILES="$POSSIBLE_BOOSTS potential volume boosts"; fi
if (( BOOSTFOLDERCOUNT == 1 )); then BOOSTFOLDERS="1 folder"; else BOOSTFOLDERS="$BOOSTFOLDERCOUNT folders"; fi

dialog --stdout --backtitle "Niente Volume Check" --title " Volume Check Completed! " --msgbox "\\nThe volume boost check has completed successfully in $SECONDS seconds, with $BOOSTFILES, in $BOOSTFOLDERS, detected.\\n\\nClick OK to return to the main menu." 12 80
}

if [[ -z "$1" ]]; then SCANTYPE="full"; else SCANTYPE=$1; fi
volumeboost_scan
