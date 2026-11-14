#!/usr/bin/env bash
####################################################################
#
# ablibnennukedb: routine for wiping a database of all of its
# contents
#
####################################################################
PATH=/usr/local/bin:/usr/bin:/bin:$PATH

function nuke_database {
check_database
# Place a lock on disk, so no competing sessions can run
if ! [ -f "$CONFDIR/tmp/nientelock" ]; then
  touch "$CONFDIR/tmp/nientelock"
else
  TODAYDATE=$(date +"%Y-%m-%d : %H:%M:%S")
  SQLSTMT="insert into refresh_logs values ('$TODAYDATE','Nuke database operation aborted, due to presence of program lock');"
  sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
  exit 1
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
}

nuke_database
