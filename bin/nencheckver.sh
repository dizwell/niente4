#!/usr/bin/env bash
#
####################################################################
#
# nencheckver: A function to check if software updates are available
# and to apply them if so and the user requests it.
#
####################################################################
source "$CONFDIR/bin/nentput.sh"
REMOTESOURCE="https://bbritten.com/software/niente"
NEWCONF="$HOME/.local/share/niente4"

BACKTITLE="Niente Software Update Checker"  LINENUM=9
if ! [ -d "$CONFDIR/tmp" ]; then mkdir -p "$CONFDIR/tmp" 2>/dev/null; fi
unset response

remote_hash=$(curl -s "$REMOTESOURCE/releasehash.txt" | tr -d '[:space:]')
RELEASEHASH=82583797e66ba35c10769fc2f2876fd2    #hard-coded at time of release by -d "2026-03-28 21:00:00" +%Y%m%d%H%M | md5sum | awk '{print $1}'

if [[ $remote_hash != $RELEASEHASH ]]; then
  DOUPGRADE=1
else
  DOUPGRADE=0
fi

function perform_upgrade {
# Fetch Niente components: Bin files first
components=(nencheckver.sh nenaggstatnd.sh nenartscan.sh nenartscannd.sh nencolour.sh nenconf.sh nencreatedb.sh
nenintegrity.sh nenintegritynd.sh nenlogdel.sh nenlokdel.sh nennodb.sh nennukedb.sh nennukedbnd.sh
nenparse.sh nenrefreshdb.sh nenrefreshdbnd.sh nenreports.sh nenrptgen.sh nenrptlog.sh
nenrptother.sh nentput.sh nenvolchk.sh nenvolchknd.sh nenoscheck.sh nenoutput.sh nmenudraw.sh
nmenuoptions.sh nsubmenuoptions.sh)
total=${#components[@]}
count=0

(
for f in "${components[@]}"; do
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  wget -q "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f";
  sleep 0.1
done
) | dialog --title "Updating Niente Binary Components" --gauge "\\n\\nDownloading fresh copies of Niente's own software components: this might take some time..." 12 70

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
) | dialog --title "Updating Niente Art Components" --guage "\\n\\nDownloading fresh copies of some other Niente bits and pieces: not long to wait now..." 12 70

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  sudo wget -q "$REMOTESOURCE/niente4.sh" -O "/usr/local/bin/niente4.sh";  sudo chmod +x /usr/local/bin/niente4.sh
  sudo rm -f /usr/local/bin/niente 2>/dev/null; sudo ln -s /usr/local/bin/niente4.sh /usr/local/bin/niente 2>/dev/null
else
  sudo wget -q "$REMOTESOURCE/niente4.sh" -O "/usr/bin/niente4.sh";  sudo chmod +x /usr/bin/niente4.sh
  sudo rm -f /usr/bin/niente 2>/dev/null; sudo ln -s /usr/bin/niente4.sh /usr/bin/niente 2>/dev/null
fi

# Confirmation when concluded
dialog --title "Software Components Completed" --msgbox "\\n\\nAll Niente's components have now been updated successfully." 12 70
}

clear; source "$CONFDIR/bin/nmenudraw.sh" short
if [[ $DOUPGRADE -eq 1 ]]; then
  dialog --title " Software Update Available " --backtitle "$BACKTITLE" --yesno "\\nA software update is available. Would you like to install it?" 10 80
  response=$?			# 0=yes, 1=no, 255=Escape key pressed
  case $response in
    0  ) perform_upgrade;;
    1  ) dialog --stdout --backtitle "$BACKTITLE" --msgbox "The software update has been cancelled.\\n\\nNo software has been modified or altered.\\n\\nPress OK to continue..." 10 80 ;;
    255) dialog --stdout --backtitle "$BACKTITLE" --msgbox "The software update has been cancelled.\\n\\nNo software has been modified or altered.\\n\\nPress OK to continue..." 10 80 ;;
  esac
else
  dialog --title " Software Update " --backtitle "$BACKTITLE" --msgbox "\\nYou are all good: there is no newer version of Niente software to apply.\\n\\nPress OK to continue..." 10 80
fi