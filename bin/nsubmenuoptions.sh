#!/usr/bin/env bash
####################################################################
#
# A function to write various menu options onto the screen
#
####################################################################
source "$CONFDIR/bin/nentput.sh"
SPACER="      "
escape_char=$(printf "\u1b")

source "$CONFDIR/bin/nmenudraw.sh"
if [ "$1" == "general" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $DRAWLINES; echo -en "\e[7mGeneral Reports\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "L"; tput setaf $DRAWLINES; echo -en "ogical Issues Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "O"; tput setaf $DRAWLINES; echo -en "ther Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dvanced SQL"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo "1) Aggregate Statistics"
  tput cup  9 4; echo "2) Files with physical corruption"
  tput cup 10 4; echo "3) Files not yet analysed at all"
  tput cup 11 4; echo "4) Files with one or more missing tags"
  tput cup 22 4; tput setaf $ALERT; echo -e "M) Return to Main Menu"
  
  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "") source "$CONFDIR/bin/nenreports.sh" aggsts ;;
    1) source "$CONFDIR/bin/nenreports.sh" aggsts ;;
    2) source "$CONFDIR/bin/nenreports.sh" phys ;;
    3) source "$CONFDIR/bin/nenreports.sh" nya ;;
    4) source "$CONFDIR/bin/nenreports.sh" nulltg ;;
    '[D') nsubmenuoptions advsql;;
    '[C') nsubmenuoptions logical;;
    G|g ) clear; nsubmenuoptions general;;
    L|l ) clear; nsubmenuoptions logical;;
    O|o ) clear; nsubmenuoptions other;;
    A|a ) clear; nsubmenuoptions advsql;;
    M|m ) clear; nmenuoptions reporting;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions general    
            fi
          else
            if command -v sqlitebrowser >/dev/null 2>&1; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions general
            fi
          fi
          ;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "logical" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "G"; tput setaf $DRAWLINES; echo -en "eneral Reports"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mLogical Issues Reports\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "O"; tput setaf $DRAWLINES; echo -en "ther Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dvanced SQL"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Inconsistent DATE & ALBUM tags"
  tput cup  9 4; echo "2) Inconsistent TRACKNUMBER tags"
  tput cup 10 4; echo "3) Inconsistent PERFORMER & COMMENT tags"
  tput cup 11 4; echo "4) Inconsistent COMMENT & ALBUM tags"
  tput cup 12 4; echo "5) Inconsistent ARTIST & COMPOSER tags"
  tput cup 13 4; echo "6) Incongruous Bit Depth & Sample Rates"
  tput cup 22 4; tput setaf $ALERT; echo -e "M) Return to Main Menu"
  
  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "") source "$CONFDIR/bin/nenreports.sh" dates ;;
    1) source "$CONFDIR/bin/nenreports.sh" dates ;;
    2) source "$CONFDIR/bin/nenreports.sh" track ;;
    3) source "$CONFDIR/bin/nenreports.sh" comper ;;
    4) source "$CONFDIR/bin/nenreports.sh" albper ;;
    5) source "$CONFDIR/bin/nenreports.sh" artcom ;;
    6) source "$CONFDIR/bin/nenreports.sh" bits ;;
    '[D') nsubmenuoptions general;;
    '[C') nsubmenuoptions other;;
    G|g ) clear; nsubmenuoptions general;;
    L|l ) clear; nsubmenuoptions logical;;
    O|o ) clear; nsubmenuoptions other;;
    A|a ) clear; nsubmenuoptions advsql;;
    M|m ) clear; nmenuoptions reporting;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions logical    
            fi
          else
            if command -v sqlitebrowser >/dev/null 2>&1; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions logical
            fi
          fi
          ;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "other" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "G"; tput setaf $DRAWLINES; echo -en "eneral Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "L"; tput setaf $DRAWLINES; echo -en "ogical Issues Reports"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mOther Reports\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dvanced SQL"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Recordings with album art issues"
  tput cup  9 4; echo "2) Folders with potential real volume boosts"
  tput cup 10 4; echo "3) Recordings with missing ReplayGain"
  tput cup 11 4; echo "4) Files missing audio data in filenames"
  tput cup 12 4; echo "5) Folders with multiple physical files"
  tput cup 13 4; echo "6) Possible duplicate recordings"
  tput cup 15 4; echo "7) Display the operations log"
  tput cup 22 4; tput setaf $ALERT; echo -e "M) Return to Main Menu"

  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "") source "$CONFDIR/bin/nenreports.sh" badart ;;
    1) source "$CONFDIR/bin/nenreports.sh" badart ;;
    2) source "$CONFDIR/bin/nenreports.sh" maxv ;;
    3) source "$CONFDIR/bin/nenreports.sh" replay ;;
    4) source "$CONFDIR/bin/nenreports.sh" namebt ;;
    5) source "$CONFDIR/bin/nenreports.sh" multtk ;;
    6) source "$CONFDIR/bin/nenreports.sh" dupes ;;
    7) source "$CONFDIR/bin/nenreports.sh" ops ;;
    '[D') nsubmenuoptions logical;;
    '[C') nsubmenuoptions advsql;;
    G|g ) clear; nsubmenuoptions general;;
    L|l ) clear; nsubmenuoptions logical;;
    O|o ) clear; nsubmenuoptions other;;
    A|a ) clear; nsubmenuoptions advsql;;
    M|m ) clear; nmenuoptions reporting;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions other    
            fi
          else
            if command -v sqlitebrowser >/dev/null 2>&1; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions other
            fi
          fi
          ;;
    * ) A=1;;
  esac
  done
elif [ "$1" == "advsql" ]; then
  # ======================================================================================================
  # Advanced SQL is the top bar's fourth item: arriving here only highlights it; Enter then does what the
  # Reporting menu's option 4 does
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "G"; tput setaf $DRAWLINES; echo -en "eneral Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "L"; tput setaf $DRAWLINES; echo -en "ogical Issues Reports"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "O"; tput setaf $DRAWLINES; echo -en "ther Reports"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mAdvanced SQL\e[0m"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo "1) Report by use of SQL"
  tput cup 22 4; tput setaf $ALERT; echo -e "M) Return to Main Menu"

  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "") source "$CONFDIR/bin/nenreports.sh" advsql ;;      # As the Reporting menu's option 4
    1) source "$CONFDIR/bin/nenreports.sh" advsql ;;
    '[D') nsubmenuoptions other;;
    '[C') nsubmenuoptions general;;
    G|g ) clear; nsubmenuoptions general;;
    L|l ) clear; nsubmenuoptions logical;;
    O|o ) clear; nsubmenuoptions other;;
    A|a ) clear; nsubmenuoptions advsql;;
    M|m ) clear; nmenuoptions reporting;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions advsql    
            fi
          else
            if command -v sqlitebrowser >/dev/null 2>&1; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nsubmenuoptions advsql
            fi
          fi
          ;;
    * ) A=1;;
  esac
  done
fi
