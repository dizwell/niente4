#!/usr/bin/env bash
####################################################################
#
# Installation Program for Niente Version 4. In broad terms:
#
#  1. Get user consent to adjust system
#  2. Configure default Dialog colour scheme
#  3. Use nenoscheck to install Niente's software dependencies
#  4. Install new Niente 4 files
#  5. Verify installation
#  6. Install new fonts
#
####################################################################
PROGVERSION="4.05"
COPYRIGHT="2021-2026"
USERNAME=$(whoami); ERRORCOUNT=0  YPOS=6 

HOTKEY=11
DRAWLINES=2
MAINTEXT=15
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

tput() {
	local VERSION='bash tput (1.0.0)'

	local opt OPTIND OPTARG
	while getopts 'ST:V' opt; do
		case "$opt" in
			S) command tput "$@"; return $?;;
			T) true;;
			V) echo "$VERSION"; return 0;;
		esac
	done
	shift "$((OPTIND - 1))"

	local ESC=$'\x1b'
	case "$1" in
		bel) echo -n $'\x7';;
		sgr0 | me) echo -n "$ESC[0m";;
		bold) echo -n "$ESC[1m";;
		dim) echo -n "$ESC[2m";;
		rev) echo -n "$ESC[7m";;
		blink) echo -n "$ESC[5m";;
		setaf | AF) echo -n "$ESC[38;5;$2m";;
		setab | AB) echo -n "$ESC[48;5;$2m";;
		sc) echo -n "${ESC}7";;
		rc) echo -n "${ESC}8";;
		cnorm) echo -n "$ESC[?25h";;
		civis) echo -n "$ESC[?25l";;
		smcup) echo -n "$ESC[?1049h";;
		rmcup) echo -n "$ESC[?1049l";;
		clear) echo -n "$ESC[H$ESC[2J";;
		home) echo -n "$ESC[H";;
		cuu) echo -n "$ESC[$2A";;
		cud) echo -n "$ESC[$2B";;
		cuf) echo -n "$ESC[$2C";;
		cub) echo -n "$ESC[$2D";;
		cup)
			local row=$(($2 + 1))
			local col=$(($3 + 1))
			echo -n "$ESC[$row;${col}H";;
		*) command tput "$@"; return $?;;
	esac
}

# Attempt to resize the terminal to 29 rows and 105 columns.
tput civis; printf '\e[8;28;103t'

REMOTESOURCE="https://bbritten.com/software/niente"
NEWCONF="$HOME/.local/share/niente4"
CONFDIR="$NEWCONF"

function print_header {
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGO; echo "♬♪ Niente: The Digital Music Integrity Checke ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © Howard Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGO; echo "Version $PROGVERSION"
}

# 1. Warning
# -----------------------------------------------------
clear; print_header; tput setaf $DRAWLINES;
tput cup 6 0
echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐"
echo -e "│  Welcome to the Niente Installer.                                                                 │"
echo -e "│                                                                                                   │"
echo -e "│  It will install numerous new software packages necessary for Niente to function correctly.       │"
echo -e "│  It will also create a bunch of new folders within your \$HOME folder                              │"
echo -e "│                                                                                                   │"
echo -e "│  Please note that this installer will not proceed if it detects that any software updates         │"
echo -e "│  are available but not yet applied: you need to do a full system upgrade before the               │"
echo -e "│  installer will work correctly.                                                                   │"
echo -e "│                                                                                                   │"
echo -e "│  If you are not comfortable with any of that, please type 'n' to cancel the installation.         │"
echo -e "│                                                                                                   │"
echo -e "│  If you are happy to proceed, type 'y' when prompted.                                             │"
echo -e "│                                                                                                   │"
echo -e "└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
echo ""
tput setaf $MAINTEXT; read -n 1 -p " Do you wish to proceed? (y/n): " response

if [[ "$response" == [Yy]* ]]; then
  clear; print_header; tput setaf $ALERT; tput cup 6 0
  echo -e " Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    echo -e " Sadly, you do not appear to be able to reach the Internet."
    echo -e " This is a requirement for the Niente installation."
    read -n 1 -p " Quitting in the meantime. Press a key to exit."
    tput reset; tput sgr0
    exit 1
  fi
else
  clear
  exit 0
fi

# 1. Make new version directory structure
clear; print_header; tput cup 6 0
mkdir -p "$NEWCONF"
mkdir -p "$NEWCONF/art"
mkdir -p "$NEWCONF/bin"
mkdir -p "$NEWCONF/db"
mkdir -p "$NEWCONF/txt"
mkdir -p "$NEWCONF/tmp"

# 3. Call nenoscheck.sh and get packages installed
YPOS=$((YPOS+1)); tput cup $YPOS 1;
wget -q "$REMOTESOURCE/bin/nenoscheck.sh" -O "$NEWCONF/bin/nenoscheck.sh"
source "$NEWCONF/bin/nenoscheck.sh" install        # Triggers a check of software dependencies and *fixes* them

function downloads {
# 4. Fetch Niente components
components=(nencheckver.sh nenaggstatnd.sh nenartscan.sh nenartscannd.sh nencolour.sh nenconf.sh nencreatedb.sh
nenintegrity.sh nenintegritynd.sh nenlogdel.sh nenlokdel.sh nennodb.sh nennukedb.sh nennukedbnd.sh
nenparse.sh nenrefreshdb.sh nenrefreshdbnd.sh nenreports.sh nenrptgen.sh nenrptlog.sh
nenrptother.sh nentput.sh nenvolchk.sh nenvolchknd.sh nenoscheck.sh nenoutput.sh nmenudraw.sh
nmenuoptions.sh nsubmenuoptions.sh)
total=${#components[@]}
count=0

# Install components: BIN files first
(
for f in "${components[@]}"; do
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  wget -q "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f";
  sleep 0.1
done
) | dialog --title "Installing Niente Binary Components" --gauge "\\n\\nDownloading Niente's own software components: this might take some time..." 12 70

# Art files next
components=(Luxi_License.txt luximr.ttf nienteico.png nienteico.svg nienteico.xpm)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  wget -q "$REMOTESOURCE/art/$f" -O "$NEWCONF/art/$f";
  sleep 0.1
done
) | dialog --title "Installing Niente Art Components" --guage "\\n\\nNow downloading some other Niente bits and pieces: not long to wait now..." 12 70

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  sudo wget -q "$REMOTESOURCE/niente4.sh" -O "/usr/local/bin/niente4.sh";  sudo chmod +x /usr/local/bin/niente4.sh
  sudo rm -f /usr/local/bin/niente 2>/dev/null; sudo ln -s /usr/local/bin/niente4.sh /usr/local/bin/niente 2>/dev/null
else
  sudo wget -q "$REMOTESOURCE/niente4.sh" -O "/usr/bin/niente4.sh";  sudo chmod +x /usr/bin/niente4.sh
  sudo rm -f /usr/bin/niente 2>/dev/null; sudo ln -s /usr/bin/niente4.sh /usr/bin/niente 2>/dev/null
fi
  
# 6. Configure the default "dialog" colour scheme
echo "screen_color = (WHITE,BLACK,ON)
shadow_color = (BLACK,BLACK,ON)
dialog_color = (BLACK,WHITE,OFF)
title_color = (GREEN,WHITE,OFF)
border_color = (WHITE,WHITE,ON)
button_active_color = (WHITE,RED,ON)
button_inactive_color = dialog_color
button_key_active_color = button_active_color
button_key_inactive_color = (RED,WHITE,ON)
button_label_active_color = (WHITE,RED,ON)
button_label_inactive_color = (BLACK,WHITE,ON)
inputbox_color = dialog_color
inputbox_border_color = dialog_color
searchbox_color = dialog_color
searchbox_title_color = title_color
searchbox_border_color = border_color
position_indicator_color = title_color
menubox_color = dialog_color
menubox_border_color = border_color
item_color = dialog_color
item_selected_color = button_active_color
tag_color = title_color
tag_selected_color = button_label_active_color
tag_key_color = button_key_inactive_color
tag_key_selected_color = (RED,WHITE,ON)
check_color = dialog_color
check_selected_color = button_active_color
uarrow_color = (GREEN,WHITE,ON)
darrow_color = uarrow_color
itemhelp_color = (WHITE,BLACK,OFF)
form_active_text_color = button_active_color
form_text_color = (WHITE,CYAN,ON)
form_item_readonly_color = (CYAN,WHITE,ON)
gauge_color = title_color
border2_color = dialog_color
inputbox_border2_color = dialog_color
searchbox_border2_color = dialog_color
menubox_border2_color = dialog_color" > "$NEWCONF/txt/abnendialog.conf"  
  
if [[ $OS != "DARWIN" ]]; then
  if [ ! -d "$HOME/.local/share/applications" ]; then mkdir -p "$HOME/.local/share/applications/"; fi
  wget -q "$REMOTESOURCE/niente.desktop" -O "$HOME/.local/share/applications/niente.desktop"
  sed -i "s|xxxxxxxx|$USERNAME|" "$HOME/.local/share/applications/niente.desktop"
  chmod +x "$HOME/.local/share/applications/niente.desktop"
  ln -s "$HOME/.local/share/applications/niente.desktop" "$HOME/Desktop" 2>/dev/null
fi
  
wget -q "$REMOTESOURCE/txt/niente.conf" -O "$CONFDIR/txt/niente.conf"
  
# Confirmation when concluded
dialog --title "Software Components Completed" --msgbox "\\n\\nAll Niente's components have now been installed successfully.\\n\\nPress OK to quit back to the command line." 12 70
}

downloads
chown -R $USERNAME:$USERNAME "$CONFDIR" 2>/dev/null

# 6. Try to install the program fonts (but it may not work on all distros, and ultimately it's up to them)
mkdir "$HOME/.local/share/fonts" 2>/dev/null
cp "$HOME/.local/share/niente4/art/"*.ttf "$HOME/.local/share/fonts/"
fc-cache -f 2>/dev/null
clear
reset