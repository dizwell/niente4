#!/usr/bin/env bash
####################################################################
#
# Installation Program for Niente Version 4. In broad terms:
#
#  1. Get user consent to adjust system
#  2. Download the Dialog colour schemes
#  3. Use nenoscheck to install Niente's software dependencies
#  4. Install new Niente 4 files
#  5. Verify installation
#  6. Install new fonts
#
####################################################################
PROGVERSION="4.10" COPYRIGHT="2021-2026"
PRIORVERSION=0; clear; USERNAME=$(whoami); ERRORCOUNT=0  YPOS=6

# Determine if the user has invoked the installer with a specific release flavour (-v beta)
# or distro (-d name) in mind, exactly as Giocoso's installer does
NENRELEASE=""    NENDISTRO=""
while getopts "v:d:" opt; do
	case "$opt" in
	  v)  NENRELEASE="$OPTARG";;
	  d)  NENDISTRO="$OPTARG";;
	esac
done

# Everything is fetched from GitHub: the beta branch (work in progress) or main (releases)
# -v must be beta or stable; if it's left out, choose_release asks which (after "Do you wish to proceed?")
case "$NENRELEASE" in
  beta|stable|"") ;;
  *) echo "Unknown release '$NENRELEASE': use -v beta or -v stable."; exit 1 ;;
esac

function choose_release {
if [[ -z $NENRELEASE ]]; then
  clear; print_header
  tput cup 6 4; tput setaf $INFOTEXT; echo "You have a choice of whether to install the stable or beta release of Niente. Beta releases contain all the latest fixes and new features but have not been thoroughly tested on every supported platform and might break, badly. Stable releases have been tested to work correctly on all supported platforms." | fold -s -w 76 | sed '2,$s/^/    /'
  echo ""
  while true; do
    tput setaf $ALERT; read -s -n 1 -p "    Choose now whether to install the stable or beta release (s/b): " input
    case "$input" in
      [sS]) NENRELEASE="stable"; break ;;
      [bB]) NENRELEASE="beta"; break ;;
      *) echo ""; echo ""; tput setaf $MAINTEXT; echo "    Invalid input: only s or b are allowed. Please try again."; echo "" ;;
    esac
  done
fi

# Everything is fetched from GitHub: the beta branch (work in progress) or main (releases)
if [[ $NENRELEASE == "beta" ]]; then
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/niente4/beta"
else
  REMOTESOURCE="https://raw.githubusercontent.com/dizwell/niente4/main"
fi
}

# The installer deletes itself when it finishes or is cancelled, whatever it was saved as (nen4inst, gio4inst...),
# unless it's the copy inside a program's own repository folder
INSTALLERFILE="$0"
if git -C "$(dirname "$INSTALLERFILE")" rev-parse --is-inside-work-tree >/dev/null 2>&1; then INSTALLERFILE=""; fi

NEWCONF="$HOME/.local/share/niente4"
CONFDIR="$NEWCONF"

HOTKEY=11
DRAWLINES=2
MAINTEXT=11
LOGO=6
INFOTEXT=11
SPINNER=12
ALERT=1

function exit_program {
rm -f "$INSTALLERFILE" >/dev/null 2>&1
reset
exit 1
}

# The installer needs sudo to install packages and make the program's commands. Check that it works before
# anything else happens; if it doesn't, say why and wait for a key, so the reason stays on screen.
function check_sudo {
local problem=""
clear; print_header
if ! command -v sudo >/dev/null 2>&1; then
  problem="Niente can't be installed, because the 'sudo' program isn't installed on this computer. Niente needs it to install the software it depends on. Please install sudo and add your user to the sudoers file, then run this installer again."
else
  tput cup 6 0; tput setaf $ALERT
  if ! sudo -p $'\r    Please supply the sudo password for %u: ' -v; then
    problem="Niente can't be installed until your user can use sudo: you don't appear to be in the sudoers file, or the password wasn't accepted. Please fix that, then run this installer again."
  fi
  tput setaf $MAINTEXT
fi
if [[ -n $problem ]]; then
  tput clear; print_header
  tput cup 6 4; tput setaf $ALERT; echo -e "$problem" | fold -s -w 76 | sed '2,$s/^/    /'
  tput cup 11 4; tput setaf $ALERT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
  tput reset; tput sgr0
  exit_program
fi
}

# Download one file, trying up to five times; it only counts if it arrives and isn't empty
function fetch_file {
  for attempt in {1..5}; do
    if wget -q --tries=1 "$1" -O "$2" && [[ -s "$2" ]]; then return 0; fi
    rm -f "$2"
    sleep 1
  done
  return 1
}

trap exit_program TERM      # Trap to quit nicely if the terminal is closed by clicking 'X' icon in window titlebar
trap exit_program SIGHUP    # Same thing, different signal
trap exit_program INT       # Trap to prevent Ctrl+C from working

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

# Attempt to resize the terminal to 28 rows and 103 columns.
tput civis; printf '\e[8;28;103t'

function print_header {
tput setaf $DRAWLINES; echo -e "┌───────────────────────────────────────────────────────────────────────────────────────────────────┐
│                                                                                                   │
│                                                                                                   │
│                                                                                                   │
└───────────────────────────────────────────────────────────────────────────────────────────────────┘"
tput cup  1 4; tput setaf $LOGO; echo "♬♪ Niente: The Digital Music Integrity Manager ♬♪"
tput cup  2 4; tput setaf $LOGO; echo "Copyright © H. Rogers $COPYRIGHT"
tput cup  3 4; tput setaf $LOGO; echo "Version $PROGVERSION"
# Once known (from -v, or from the stable/beta prompt), the release being installed shows flush right
if [[ -n $NENRELEASE ]]; then
  RELTEXT="INSTALLING $(tr "[:lower:]" "[:upper:]" <<< "$NENRELEASE") RELEASE"
  tput cup  3 $(( 97 - ${#RELTEXT} )); tput setaf $LOGO; echo "$RELTEXT"
fi
}

function downloads {
# Fetch Niente components: BIN files first
components=(nenaggstatnd.sh nenartscan.sh nenartscannd.sh nencolour.sh nenconf.sh nencreatedb.sh nenintegrity.sh nenintegritynd.sh nenlogdel.sh nennodb.sh nennukedb.sh nennukedbnd.sh nenoscheck.sh nenoutput.sh nenparse.sh nenrefreshdb.sh nenrefreshdbnd.sh nenreports.sh nenrptgen.sh nenrptlog.sh nenrptother.sh nentput.sh nenvolchk.sh nenvolchknd.sh nmenudraw.sh nmenuoptions.sh nsubmenuoptions.sh)
BINCOMPONENTS=("${components[@]}")                                  # Remembered for the final installation check
total=${#components[@]}
count=0

(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/bin/$f" -O "$NEWCONF/bin/$f" && [[ $(head -c2 "$NEWCONF/bin/$f") == '#!' ]]; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/bin/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Niente Binary Components " --gauge "\\n\\nDownloading Niente's own software components: this might take some time..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Self-compiled static executables next: these live in exec, not bin
components=(metaflac-linux-x86_64 metaflac-linux-arm64 metaflac-macos-x86_64 metaflac-macos-arm64 ffmpeg-linux-x86_64 ffmpeg-linux-arm64 ffmpeg-macos-x86_64 ffmpeg-macos-arm64 magick-linux-x86_64 magick-linux-arm64 magick-macos-x86_64 magick-macos-arm64 img2sixel-linux-x86_64 img2sixel-linux-arm64 img2sixel-macos-x86_64 img2sixel-macos-arm64)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/exec/$f" -O "$NEWCONF/exec/$f" && [[ -s "$NEWCONF/exec/$f" ]]; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/exec/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Niente Executables " --gauge "\\n\\nDownloading the external programs Niente depends on: not long to wait now..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

chmod +x "$NEWCONF/exec/"*

# Art files next
components=(LinLibertine_M.otf nienteico.png nienteicobeta.png nienteico.svg)
total=${#components[@]}
count=0
(
for f in "${components[@]}"; do
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/art/$f" -O "$NEWCONF/art/$f" && [[ -s "$NEWCONF/art/$f" ]]; then
      downloaded=1
      break
    fi
    rm -f "$NEWCONF/art/$f"
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then exit 1; fi
  count=$((count + 1 ))
  percent=$((count * 100 / total))
  echo $percent
  sleep 0.1
done
) | dialog --title " Installing Niente Art Components " --gauge "\\n\\nNow downloading some other Niente bits and pieces: it will all be over soon..." 12 70

download_status=${PIPESTATUS[0]}
if [[ $download_status -ne 0 ]]; then
  dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
  exit 1
fi

# Finally, /usr/bin and miscellaneous stuff
if [[ $OS == "DARWIN" ]]; then
  rm -f "$NEWCONF/niente4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/niente4.sh" -O "$NEWCONF/niente4.sh" && [[ $(head -c2 "$NEWCONF/niente4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/niente4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/niente4.sh"
else
  rm -f "$NEWCONF/niente4.sh"
  downloaded=0
  for attempt in {1..5}; do
    if wget -q --tries=1 "$REMOTESOURCE/niente4.sh" -O "$NEWCONF/niente4.sh" && [[ $(head -c2 "$NEWCONF/niente4.sh") == '#!' ]]; then
      downloaded=1
      break
    fi
    sleep 1
  done
  if [[ $downloaded -eq 0 ]]; then
    dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    rm -f "$NEWCONF/niente4.sh"
    exit 1
  fi
  chmod +x "$NEWCONF/niente4.sh"
fi

# Only create a desktop launcher if this is NOT macOS.
# -----------------------------------------------------
if [[ -f /etc/os-release ]]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
else
  OS=$(uname -s)
  THISVER=$(uname -r)
fi
OS=${OS^^}

if [[ ! $OS == *"DARWIN"* ]]; then
  if [[ ! -d "$HOME/.local/share/applications" ]]; then mkdir -p "$HOME/.local/share/applications/"; fi
  fetch_file "$REMOTESOURCE/niente.desktop" "$HOME/.local/share/applications/niente.desktop"
  sed -i "s|xxxxxxxx|$USERNAME|" "$HOME/.local/share/applications/niente.desktop"
  chmod +x "$HOME/.local/share/applications/niente.desktop"
  ln -s "$HOME/.local/share/applications/niente.desktop" "$HOME/Desktop" 2>/dev/null

# And now an app for MacOS, as for Giocoso and Semplice: it opens Niente in WezTerm with Niente's own settings
else
  APPNAME="Niente"
  APPPATH="/Applications/$APPNAME.app"
  ICONPNG="$HOME/.local/share/niente4/art/nienteico.png"
  ICONSET="/tmp/niente.iconset"
  ICONFILE="/tmp/niente.icns"

  rm -rf "$APPPATH" >/dev/null 2>&1
  mkdir -p "$APPPATH/Contents/MacOS" "$APPPATH/Contents/Resources" >/dev/null 2>&1

  cat > "$APPPATH/Contents/MacOS/$APPNAME" <<EOF
#!/bin/bash
# Use the first bash and WezTerm found: Homebrew (Apple Silicon or Intel), MacPorts, then WezTerm's own app
for bashPath in /opt/homebrew/bin/bash /usr/local/bin/bash /opt/local/bin/bash; do
  [[ -x "\$bashPath" ]] && break
done
for weztermPath in /opt/homebrew/bin/wezterm /usr/local/bin/wezterm /opt/local/bin/wezterm /Applications/WezTerm.app/Contents/MacOS/wezterm; do
  [[ -x "\$weztermPath" ]] && break
done

exec "\$weztermPath" --config-file "\$HOME/.niente.lua" start -- "\$bashPath" -l -c 'ulimit -u 4000; exec "\$BASH" /usr/local/bin/niente4.sh'
EOF

  chmod +x "$APPPATH/Contents/MacOS/$APPNAME"

  cat > "$APPPATH/Contents/Info.plist" <<EOF
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
<key>CFBundleExecutable</key>
<string>$APPNAME</string>
<key>CFBundleIdentifier</key>
<string>com.bbritten.niente4</string>
<key>CFBundleName</key>
<string>$APPNAME</string>
<key>CFBundleDisplayName</key>
<string>$APPNAME</string>
<key>CFBundlePackageType</key>
<string>APPL</string>
<key>CFBundleIconFile</key>
<string>niente.icns</string>
<key>LSArchitecturePriority</key>
<array>
  <string>arm64</string>
  <string>x86_64</string>
</array>
</dict>
</plist>
EOF

  rm -rf "$ICONSET" >/dev/null 2>&1
  mkdir -p "$ICONSET" >/dev/null 2>&1
  for size in 16 32 128 256 512; do
    sips -z $size $size "$ICONPNG" --out "$ICONSET/icon_${size}x${size}.png" >/dev/null 2>&1
    sips -z $((size*2)) $((size*2)) "$ICONPNG" --out "$ICONSET/icon_${size}x${size}@2x.png" >/dev/null 2>&1
  done
  iconutil -c icns "$ICONSET" -o "$ICONFILE" >/dev/null 2>&1
  cp "$ICONFILE" "$APPPATH/Contents/Resources/niente.icns" >/dev/null 2>&1

  rm -rf "$ICONSET" >/dev/null 2>&1
  rm -f "$ICONFILE" >/dev/null 2>&1
  /System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister -f "$APPPATH" >/dev/null 2>&1
fi

# Confirmation when concluded
dialog --title " Software Components Completed " --msgbox "\\n\\nAll Niente's components have now been installed successfully.\\n\\nPress OK to see an installation summary report." 12 70
}

function backup_install {
# Nothing to back up on a first-ever install, so skip creating an empty backup folder
if [[ ! -d "$NEWCONF" ]] && ! compgen -G "/usr/bin/niente*.sh" >/dev/null && ! compgen -G "/usr/local/bin/niente*.sh" >/dev/null; then return; fi
tput clear; print_header
tput cup 6 4; tput setaf $MAINTEXT; echo -n "Backing up prior version's program."
BACKUPDIR="$HOME/.local/share/niente-backup-$(date +%Y%m%d-%H%M%S)"
mkdir -p "$BACKUPDIR"
cp -r "$NEWCONF" "$BACKUPDIR" 2>/dev/null; BACKUPSUCCESS=$?
cp /usr/bin/niente*.sh "$BACKUPDIR" 2>/dev/null
cp /usr/local/bin/niente*.sh "$BACKUPDIR" 2>/dev/null

# Now prune old backups
if [[ $BACKUPSUCCESS -eq 0 ]]; then
    local count=0
    for dir in "$HOME"/.local/share/niente-backup-*; do
        [[ -d "$dir" ]] && echo "$dir"
    done | sort -r | while IFS= read -r dir; do
        ((count+=1))
        ((count > 5)) && rm -rf "$dir"
    done
fi
}

# ====================================================================================
# Installation Code Starts Here
# ====================================================================================

# 1. Warning
# -----------------------------------------------------
tput clear; print_header
tput cup 6 4; tput setaf $INFOTEXT; echo -e "Welcome to the Niente Installer."
tput cup 8 4; tput setaf $INFOTEXT; echo -e "• It will install numerous new software packages necessary for Niente to function correctly. It will also create a bunch of new folders within your \$HOME folder.\n\n• Any existing Niente installation will be backed up, just in case it's needed.\n\n• If you are happy to proceed, tap 'y' when prompted; tapping anything else will cancel the installation without it having touched your system at all." | fold -s -w 76 | sed '2,$s/^/    /'
echo ""; tput setaf $ALERT; read -s -n 1 -p "    Do you wish to proceed? (y/n): " response   # One line below the text, however long it is

if [[ "$response" == [Yy]* ]]; then
  check_sudo                     # Before anything else: without working sudo, nothing can be installed
  choose_release
  clear; print_header; tput setaf $MAINTEXT; tput cup 6 0
  tput cup 6 4; echo -e "Checking your network connection is working..."
  if ! ping -c1 -W1 "1.1.1.1" >/dev/null 2>&1; then
    tput clear; print_header
    tput cup 6 4; tput setaf $ALERT; echo -e "Sadly, you do not appear to be able to reach the Internet.\n\nThis is a requirement for the Niente installation." | fold -s -w 76 | sed '2,$s/^/    /'
    tput cup 10 4; tput setaf $ALERT; read -n 1 -p "Quitting in the meantime. Press a key to exit."
    tput reset; tput sgr0
    exit_program
  fi

  # 2. Backup if appropriate
  # -----------------------------------------------------
  backup_install

  # 3. Make new version directory structure if needed
  # -----------------------------------------------------
  if [[ ! -d "$NEWCONF" ]]; then mkdir -p "$NEWCONF"; fi
  if [[ ! -d "$NEWCONF/art" ]]; then mkdir -p "$NEWCONF/art"; fi
  if [[ ! -d "$NEWCONF/bin" ]]; then mkdir -p "$NEWCONF/bin"; fi
  if [[ ! -d "$NEWCONF/exec" ]]; then mkdir -p "$NEWCONF/exec"; fi
  if [[ ! -d "$NEWCONF/txt" ]]; then mkdir -p "$NEWCONF/txt"; fi
  if [[ ! -d "$NEWCONF/tmp" ]]; then mkdir -p "$NEWCONF/tmp"; fi
  if [[ ! -d "$NEWCONF/db" ]]; then mkdir -p "$NEWCONF/db"; fi

  # 3a. Ask for the sudo password once, now, and make the command links straight away. They point at the
  # main script in the program folder, which arrives later; nothing after this needs the password again.
  # -----------------------------------------------------
  echo ""
  tput setaf $ALERT
  sudo -p $'\r    Please supply the sudo password for %u: ' -v || { echo "    Failed to acquire sudo privileges, so quitting..."; exit_program; }
  tput setaf $MAINTEXT
  if [[ $(uname -s) == "Darwin" ]]; then BINDIR="/usr/local/bin"; else BINDIR="/usr/bin"; fi
  sudo mkdir -p "$BINDIR"
  sudo rm -f "$BINDIR/niente4.sh" "$BINDIR/niente" 2>/dev/null
  sudo ln -s "$NEWCONF/niente4.sh" "$BINDIR/niente4.sh"
  sudo ln -s "$NEWCONF/niente4.sh" "$BINDIR/niente"

  
  # 4. Call nenoscheck.sh and get packages installed
  # -----------------------------------------------------
  YPOS=$((YPOS+1)); tput cup $YPOS 1;
  if ! fetch_file "$REMOTESOURCE/bin/nenoscheck.sh" "$NEWCONF/bin/nenoscheck.sh" || [[ $(head -c2 "$NEWCONF/bin/nenoscheck.sh") != '#!' ]]; then
    dialog --title " Download Failed " --msgbox "A Niente component could not be downloaded after five attempts.\n\nInstallation aborted." 10 70
    exit 1
  fi
  source "$NEWCONF/bin/nenoscheck.sh" install        # Triggers a check of software dependencies and *fixes* them
  downloads
  chown -R $USERNAME:$USERNAME "$NEWCONF" 2>/dev/null
  
  # 5. Download the various Dialog configuration files (the same five themes as Giocoso and Semplice)
  # -----------------------------------------------------
  fetch_file "$REMOTESOURCE/txt/standard.conf" "$NEWCONF/txt/standard.conf"
  fetch_file "$REMOTESOURCE/txt/red.conf" "$NEWCONF/txt/red.conf"
  fetch_file "$REMOTESOURCE/txt/green.conf" "$NEWCONF/txt/green.conf"
  fetch_file "$REMOTESOURCE/txt/yellow.conf" "$NEWCONF/txt/yellow.conf"
  fetch_file "$REMOTESOURCE/txt/magenta.conf" "$NEWCONF/txt/magenta.conf"

  # 6. Try to install the program fonts (but it may not work on all distros, and ultimately it's up to them)
  # -----------------------------------------------------
  # WezTerm's Niente settings use the Linux Libertine Mono O font (as Giocoso does), so it must be installed where the system looks for fonts
  if [[ $(uname -s) == "Darwin" ]]; then
    mkdir -p "$HOME/Library/Fonts" 2>/dev/null
    cp "$HOME/.local/share/niente4/art/"*.ttf "$HOME/Library/Fonts/" 2>/dev/null
    cp "$HOME/.local/share/niente4/art/"*.otf "$HOME/Library/Fonts/" 2>/dev/null
  else
    mkdir -p "$HOME/.local/share/fonts" 2>/dev/null
    cp "$HOME/.local/share/niente4/art/"*.ttf "$HOME/.local/share/fonts/" 2>/dev/null
    cp "$HOME/.local/share/niente4/art/"*.otf "$HOME/.local/share/fonts/" 2>/dev/null
    fc-cache -f 2>/dev/null
    clear
  fi
  
  # 7. If possible, configure WezTerm terminals to display appropriately
  # -----------------------------------------------------
  if ! [[ -f "$HOME/.niente.lua" ]]; then
cat << 'EOF' > "$HOME/.niente.lua"
local wezterm = require 'wezterm'
local config = wezterm.config_builder()
config.initial_cols = 103
config.initial_rows = 28
config.color_scheme = 'Wild Cherry (Gogh)'
config.font = wezterm.font("Linux Libertine Mono O", {weight="Regular", stretch="Normal", style="Normal"})
config.font_size = 12
config.audible_bell = "Disabled"
config.window_close_confirmation = "NeverPrompt"
config.mouse_bindings = {
  -- Right-click over highlighted text: Copies and instantly clears the highlight
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "NONE",
    action = wezterm.action.Multiple {
      wezterm.action.CopyTo("ClipboardAndPrimarySelection"),
      wezterm.action.ClearSelection,
	},
  },

-- Shift + Right-click: Triggers your paste action
  {
    event = { Down = { streak = 1, button = "Right" } },
    mods = "SHIFT",
    action = wezterm.action.PasteFrom("Clipboard"),
  },
}
config.window_decorations = "TITLE | RESIZE"
config.freetype_load_target = "Light"
config.enable_wayland = false
config.enable_tab_bar = false
config.line_height = 1.2
--config.front_end = "WebGpu"
local schemes = wezterm.get_builtin_color_schemes()
if not schemes[config.color_scheme] then
  config.color_scheme = "Wild Cherry (Gogh)"
end
return config
EOF
  fi
    
  # 8. Assess state of installation and advise accordingly
  # -----------------------------------------------------
  BINMISSING=0                                                       # Every script in the bin components list must be present
  for c in "${BINCOMPONENTS[@]}"; do [[ -f $CONFDIR/bin/$c ]] || BINMISSING=1; done
  COUNTEXC=$(( $(ls /usr/local/bin/niente4.sh 2>/dev/null | wc -l) + $(ls /usr/bin/niente4.sh 2>/dev/null | wc -l) ))
  if [[ $BINMISSING -eq 0 ]]; then COUNTBINOK=1; else COUNTBINOK=0; fi
  if [[ $COUNTEXC -eq 1 ]]; then COUNTXECOK=1; else COUNTXECOK=0; fi
  if [[ $COUNTBINOK -eq 1 && $COUNTXECOK -eq 1 ]]; then BASICINSTALLOK=1; else BASICINSTALLOK=0; fi
  
  case "$(uname -s)" in Darwin) EXPLAT="macos" ;; Linux) EXPLAT="linux" ;; *) EXPLAT="unknown" ;; esac
  case "$(uname -m)" in arm64|aarch64) EXARCH="arm64" ;; x86_64) EXARCH="x86_64" ;; *) EXARCH="unknown" ;; esac
  if command -v sqlite3 >/dev/null 2>&1; then SQLITEOK=1; else SQLITEOK=0; fi                       # Niente's databases
  if [[ -x "$NEWCONF/exec/metaflac-$EXPLAT-$EXARCH" && -x "$NEWCONF/exec/ffmpeg-$EXPLAT-$EXARCH" ]]; then CHECKOK=1; else CHECKOK=0; fi   # Integrity and volume checks for this computer
  if [[ -x "$NEWCONF/exec/img2sixel-$EXPLAT-$EXARCH" && -x "$NEWCONF/exec/magick-$EXPLAT-$EXARCH" ]]; then SIXELOK=1; else SIXELOK=0; fi  # Logo display for this computer

  DIALOGTEXT="\nThe Niente installation has now completed. Its current status is as follows:"

  if [[ $BASICINSTALLOK -eq 1 ]]; then
    DIALOGTEXT=$DIALOGTEXT"\n\n  ✓ Your basic Niente installation is fine"
    if [[ $SQLITEOK -eq 1 ]]; then DIALOGTEXT=$DIALOGTEXT"\n  ✓ Niente can create and use its databases"; else DIALOGTEXT=$DIALOGTEXT"\n  ✘ Niente cannot use databases: sqlite3 is missing"; fi
    if [[ $CHECKOK -eq 1 ]]; then DIALOGTEXT=$DIALOGTEXT"\n  ✓ Niente can check your FLACs"; else DIALOGTEXT=$DIALOGTEXT"\n  ✘ Niente cannot check FLACs on this computer"; fi
    if [[ $SIXELOK -eq 1 ]]; then DIALOGTEXT=$DIALOGTEXT"\n  ✓ Niente can display its logo OK"; else DIALOGTEXT=$DIALOGTEXT"\n  ✘ Niente cannot display its logo"; fi
    if [[ $SQLITEOK -eq 0 || $CHECKOK -eq 0 || $SIXELOK -eq 0 ]]; then
      DIALOGTEXT=$DIALOGTEXT"\n\nSee the Niente documentation for how to potentially resolve these issues manually. You can otherwise close this terminal now."
    else
      DIALOGTEXT=$DIALOGTEXT"\n\nNiente has full functionality: click OK to return to the command line."
    fi
  else
    DIALOGTEXT=$DIALOGTEXT"\n\n  ✘ Your basic Niente installation appears to be wrong."
    DIALOGTEXT=$DIALOGTEXT"\n\nSince even the basic installation seems faulty, you're advised to check your network connection and try re-installing Niente afresh."
  fi

  dialog --stdout --backtitle "Niente Software Install" --title " Software installation status " --msgbox "\n$DIALOGTEXT" 18 80 
    
  # 9. Finish Up
  # -----------------------------------------------------
  reset
  rm -f "$INSTALLERFILE"
  exit 0
else      # They said not to proceed
  clear
  echo ""
  echo "Niente installation aborted. You can close this terminal now."
  exit_program
fi

# Failsafe cleanup
# -----------------------------------------------------
reset
rm -f "$INSTALLERFILE"
exit 0