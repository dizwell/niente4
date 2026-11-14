#!/usr/bin/env bash
####################################################################
#
# ablibnenlokdel: routine for removing the file scan log
#
####################################################################

function remove_lock {
if [ -f "$CONFDIR/tmp/nientelock" ]; then
  rm -rf "$CONFDIR/tmp/nientelock" >/dev/null 2>&1
  if [ "$callmode" == "verbose" ]; then
    dialog --stdout --backtitle "Niente Administration" --title " File Scan Lock Removed " --msgbox "\\nThe program lock has been successfully removed.\\n\\nClick OK to return to the main menu." 12 80
  fi
else
  if [ "$callmode" == "verbose" ]; then
    dialog --stdout --backtitle "Niente Administration" --title " No File Scan Lock " --msgbox "\\nThere is no current file scan lock to be removed: your request has therefore been ignored on this occasion.\\n\\nClick OK to return to the main menu." 12 80
  fi
fi
}

if [ -z "$1" ]; then callmode="verbose"; else callmode=$1; fi
remove_lock
