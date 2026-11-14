#!/usr/bin/env bash
####################################################################
#
# nenlogdel: routine for pruning the database operations log
#
####################################################################

function prune_log {
check_database
SQLSTMT="delete from refresh_logs;"
sqlite3 "$CONFDIR/db/$DBNAME.db" "$SQLSTMT" .exit > /dev/null 2>&1
dialog --stdout --backtitle "Niente Administration" --title " Log Pruning Complete! " --msgbox "\\nThe operations log has now been cleared.\\n\\nClick OK to return to the main menu." 12 80
}

prune_log
