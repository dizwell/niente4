#!/usr/bin/env bash
####################################################################
#
# nennukedb: routine for wiping a database of all of its
# contents
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

function nuke_database {
check_database
# Place a lock on disk, so no competing sessions can run
if ! take_lock; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Nuke database operation aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
fi

# Data-loss guard: check the music folder before wiping anything; if it's suspect, change nothing and say why in the log
list_music_folder
if ! check_data_loss; then
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  sqlite3 "$CONFDIR/db/$DBNAME.db" "insert into refresh_logs values ('$TODAYDATE','$LOSSLOG');" .exit > /dev/null 2>&1
  tidy_music_list
  release_lock
  return 1
fi
tidy_music_list

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
}

nuke_database
