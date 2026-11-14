#!/usr/bin/env bash
####################################################################
#
# A function to write various menu options onto the screen
#
####################################################################
source "$CONFDIR/bin/nentput.sh"
SPACER="      "
escape_char=$(printf "\u1b")

if [ "$1" == "database" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $DRAWLINES; echo -en "\e[7mDatabase\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "I"; tput setaf $DRAWLINES; echo -en "ntegrity Checks"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eporting"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo "1) Create a music database"
  tput cup  9 4; echo "2) Wipe & re-load a database from scratch"
  tput cup 10 4; echo "3) Add/Remove music files incrementally"
  tput cup 11 4; echo "4) Wipe a music database"
  tput cup 13 4; echo -e "L) Remove the program lock"
  tput cup 14 4; echo -e "C) Change Working Database"
  tput cup 15 4; echo -e "F) Change Working Music Folder"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program" 

  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/nencreatedb.sh"; nmenuoptions database ;;
    1 ) source "$CONFDIR/bin/nencreatedb.sh"; nmenuoptions database ;;
    2 ) source "$CONFDIR/bin/nennukedb.sh" quiet; source "$CONFDIR/bin/nenrefreshdb.sh"; nmenuoptions database;;
    3 ) source "$CONFDIR/bin/nenrefreshdb.sh"; nmenuoptions database;;
    4 ) source "$CONFDIR/bin/nennukedb.sh" verbose; nmenuoptions database;;
    D|d ) clear; nmenuoptions database;;
    I|i ) clear; nmenuoptions integrity;;
    R|r ) clear; nmenuoptions reporting;;
    A|a ) clear; nmenuoptions administration;;
    Q|q ) clear; nmenuoptions quit;;
    L|l ) source "$CONFDIR/bin/nenlokdel.sh" quiet; nmenuoptions database;;
    C|c ) source "$CONFDIR/bin/nennodb.sh" database; nmenuoptions database;;
    F|f ) source "$CONFDIR/bin/nennodb.sh" folder; nmenuoptions database;;
    X|x ) clear; exit 0 ;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions database    
            fi
          else
            if command -v sqlitebrowser 2>/dev/null; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions database
            fi
          fi
          ;;
    '[D') nmenuoptions quit;;
    '[C') nmenuoptions integrity;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "integrity" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mIntegrity Checks\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eporting"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  tput cup 3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Perform a full integrity check"
  tput cup  9 4; echo "2) Perform a differential integrity check"
  tput cup 10 4; echo "3) Perform a fast integrity check"
  tput cup 11 4; echo "4) Check album art for all files"
  tput cup 12 4; echo "5) Check album art for new files"
  tput cup 13 4; echo "6) Check all files for volume boosts"
  tput cup 14 4; echo "7) Check new files for volume boosts"
  tput cup 16 4; echo -e "L) Remove the program lock"
  tput cup 17 4; echo -e "C) Change Working Database"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program" 
  
  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/nenintegrity.sh" full; nmenuoptions integrity;;
    1 ) source "$CONFDIR/bin/nenintegrity.sh" full; nmenuoptions integrity;;
    2 ) source "$CONFDIR/bin/nenintegrity.sh" diff; nmenuoptions integrity;;
    3 ) source "$CONFDIR/bin/nenintegrity.sh" logic; nmenuoptions integrity;;
    4 ) source "$CONFDIR/bin/nenartscan.sh" full; nmenuoptions integrity;;
    5 ) source "$CONFDIR/bin/nenartscan.sh" diff; nmenuoptions integrity;;
    6 ) source "$CONFDIR/bin/nenvolchk.sh" full; nmenuoptions integrity;;
    7 ) source "$CONFDIR/bin/nenvolchk.sh" partial; nmenuoptions integrity;;
    D|d ) clear; nmenuoptions database;;
    I|i ) clear; nmenuoptions integrity;;
    R|r ) clear; nmenuoptions reporting;;
    A|a ) clear; nmenuoptions administration;;
    Q|q ) clear; nmenuoptions quit;;
    L|l ) source "$CONFDIR/bin/nenlokdel.sh" quiet; nmenuoptions integrity;;
    C|c ) source "$CONFDIR/bin/nennodb.sh" database; nmenuoptions integrity;;
    X|x ) clear; exit 0 ;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions integrity    
            fi
          else
            if command -v sqlitebrowser 2>/dev/null; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions integrity
            fi
          fi
          ;;
    '[D') nmenuoptions database;;
    '[C') nmenuoptions reporting;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "reporting" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "I"; tput setaf $DRAWLINES; echo -en "ntegrity Checks"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mReporting\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) General Reports"
  tput cup  9 4; echo "2) Logical Problems Reports"
  tput cup 10 4; echo "3) Other Reports"
  tput cup 11 4; echo "4) Advanced SQL Reporting"
  tput cup 13 4; echo -e "L) Remove the program lock"
  tput cup 14 4; echo -e "C) Change Working Database"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program" 
  
  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) source "$CONFDIR/bin/nsubmenuoptions.sh" general;;
    1 ) source "$CONFDIR/bin/nsubmenuoptions.sh" general;;
    2 ) source "$CONFDIR/bin/nsubmenuoptions.sh" logical;;
    3 ) source "$CONFDIR/bin/nsubmenuoptions.sh" other;;
    4 ) source "$CONFDIR/bin/nenreports.sh" advsql ;;
    D|d ) clear; nmenuoptions database;;
    I|i ) clear; nmenuoptions integrity;;
    R|r ) clear; nmenuoptions reporting;;
    A|a ) clear; nmenuoptions administration;;
    Q|q ) clear; nmenuoptions quit;;
    L|l ) source "$CONFDIR/bin/nenlokdel.sh" quiet; nmenuoptions reporting;;
    C|c ) source "$CONFDIR/bin/nennodb.sh" database; nmenuoptions reporting;;
    X|x ) clear; exit 0 ;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions reporting    
            fi
          else
            if command -v sqlitebrowser 2>/dev/null; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions reporting
            fi
          fi
          ;;
    '[D') nmenuoptions integrity;;
    '[C') nmenuoptions administration;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "administration" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "I"; tput setaf $DRAWLINES; echo -en "ntegrity Checks"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eporting"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mAdministration\e[0m"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "Q"; tput setaf $DRAWLINES; echo -en "uit"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}"
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Edit Configuration File"
  tput cup  9 4; echo -e "2) Display software licence"
  tput cup 10 4; echo -e "3) Remove Program Lock"
  tput cup 11 4; echo -e "4) Wipe the Niente operations log"
  tput cup 12 4; echo -e "5) Check for software updates"
  tput cup 13 4; echo -e "6) Change the program colour scheme"    
  tput cup 15 4; echo -e "L) Remove the program lock"
  tput cup 16 4; echo -e "C) Change Working Database"
  tput cup 22 4; tput setaf $ALERT; echo -e "X) Exit the program"  
  
  until [ "$option" == "q" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
   "" ) clear; source "$CONFDIR/bin/nenconf.sh"; nmenuoptions administration ;;
    1 ) clear; source "$CONFDIR/bin/nenconf.sh"; nmenuoptions administration ;;
    2 ) if [[ ! -d "$CONFDIR/tmp" ]]; then mkdir -p "$CONFDIR/tmp"; fi
        if [[ ! -f "$CONFDIR/tmp/license.txt" ]]; then
          wget -q https://raw.githubusercontent.com/dizwell/niente4/beta/gpl-v2.0.txt -O "$CONFDIR/tmp/license.txt"
        fi
        fmt -w 90 < "$CONFDIR/tmp/license.txt" > "$CONFDIR/tmp/licensewrapped.txt"
        sed -i 's/\\n/\n/g' "$CONFDIR/tmp/licensewrapped.txt"  # Sorts out spurious extra blank lines, replacing them with singles
        sed -i '1s/^/\n/' "$CONFDIR/tmp/licensewrapped.txt"    # Add a blank line to the start of the file for appearance's sake
        if [[ -f "$CONFDIR/tmp/licensewrapped.txt" ]]; then
          dialog --backtitle "Niente GPL v2 Software Licence" --title " Text of the GPLv2 Licence " --ok-label "OK" --extra-button --extra-label "Cancel" --textbox "$CONFDIR/tmp/licensewrapped.txt" 20 95
        fi
        nmenuoptions administration ;;
    3 ) clear; source "$CONFDIR/bin/nenlokdel.sh"; nmenuoptions administration ;;
    4 ) clear; source "$CONFDIR/bin/nenlogdel.sh"; nmenuoptions administration ;;
    5 ) clear; source "$CONFDIR/bin/nencheckver.sh"; nmenuoptions administration ;;
    6 ) clear; source "$CONFDIR/bin/nencolour.sh"; nmenuoptions administration;;

    D|d ) clear; nmenuoptions database;;
    I|i ) clear; nmenuoptions integrity;;
    R|r ) clear; nmenuoptions reporting;;
    A|a ) clear; nmenuoptions administration;;
    Q|q ) clear; nmenuoptions quit;;
    L|l ) source "$CONFDIR/bin/nenlokdel.sh" quiet; nmenuoptions administration;;
    C|c ) source "$CONFDIR/bin/nennodb.sh" database; nmenuoptions administration;;
    X|x ) clear; exit 0 ;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions administration    
            fi
          else
            if command -v sqlitebrowser 2>/dev/null; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions administration
            fi
          fi
          ;;
    '[D') nmenuoptions reporting;;
    '[C') nmenuoptions quit;;
    * ) A=1;;
  esac
  done

elif [ "$1" == "quit" ]; then
  # ======================================================================================================
  tput cup  5 4
  tput setaf $HOTKEY; echo -en "D"; tput setaf $DRAWLINES; echo -en "atabase"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "I"; tput setaf $DRAWLINES; echo -en "ntegrity Checks"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "R"; tput setaf $DRAWLINES; echo -en "eporting"; echo -en "$SPACER"
  tput setaf $HOTKEY; echo -en "A"; tput setaf $DRAWLINES; echo -en "dministration"; echo -en "$SPACER"
  tput setaf $DRAWLINES; echo -en "\e[7mQuit\e[0m"
  # ======================================================================================================
  tput cup  3 4; tput setaf $LOGO; echo -en "Using database: "; tput setaf $INFOTEXT; echo -en "${DBNAME^}";
  tput cup  8 4; tput setaf $MAINTEXT; echo -e "1) Quit the Program"
  
  until [ "$option" == "Z" ]; do
  tput cup 25 4; tput setaf $MAINTEXT; echo -n "Type a menu item: "; tput setaf $SPINNER;
  tput cup 25 24; tput cvvis; read -n 1 -s -r option
  if [[ $option == $escape_char ]]; then
    read -rsn2 option
  fi
  case $option in
    ""  ) exit_program ;;
    1   ) exit_program ;;
    D|d ) clear; nmenuoptions database;;
    I|i ) clear; nmenuoptions integrity;;
    R|r ) clear; nmenuoptions reporting;;
    A|a ) clear; nmenuoptions administration;;
    Q|q ) clear; nmenuoptions quit;;
    X|x ) clear; exit 0 ;;
    B|b ) if [[ $OSFAMILY == "MACOS" ]]; then
            if [[ $(mdfind "kMDItemFSName == 'DB Browser for SQLite.app'" | wc -l) -gt 0 ]]; then
              pkill -i "DB Browser for SQLite" 2>/dev/null
              open -a "DB Browser for SQLite" "$CONFDIR/db/$DBNAME.db" >/dev/null 2>&1 &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions quit    
            fi
          else
            if command -v sqlitebrowser 2>/dev/null; then
              pkill -i sqlitebrowser  2>/dev/null
              sqlitebrowser "$CONFDIR/db/$DBNAME.db" 2>/dev/null &
            else
              dialog --stdout --backtitle "Niente Database Browser" --msgbox "The Sqlitebrowser tool has not been installed on this system. You need to install that manually before the 'B' key will do anything!" 10 80
              clear; nmenuoptions quit
            fi
          fi
          ;;
    '[D') nmenuoptions administration;;
    '[C') nmenuoptions database;;
    * )   if [[ $key = "" ]]; then exit_program; fi;;
  esac
  done
fi

read -p "Wait"
