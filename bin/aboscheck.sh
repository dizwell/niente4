#!/usr/bin/env bash
####################################################################
#
# Queries the nature of the OS it's running on and sees if software
# prerequisites are present.
#
####################################################################
if [ -z "$1" ]; then set -- "checkonly"; fi
if [[ $1 == "install" ]]; then
  CHECKONLY=0
else
  CHECKONLY=1
fi

# Start by checking what operating system we're dealing with
# -----------------------------------------------------------------------------
if [ -f /etc/os-release ]; then
    . /etc/os-release
    OS=$NAME
    THISVER=$VERSION
else
  OS=$(uname -s)
  THISVER=$(uname -r)
fi

OS=${OS^^}

if hash nproc 2>/dev/null; then
  THREADS=$(nproc)
else
  THREADS=$(sysctl -n hw.logicalcpu)
fi

# If we're not running version 4+ of Bash, all our maths break!
# -----------------------------------------------------------------------------
if ((BASH_VERSINFO[0] < 4)); then
  echo "You are running an ancient version of Bash and Niente cannot continue."
  exit 1
fi

# Put OS into appropriate family:
# -----------------------------------------------------------------------------
if [[ $OS == *"DARWIN"* ]]; then OSFAMILY="MACOS"; fi
if [[ $OS == *"ALMA"* || $OS == *"ROCKY"* ]]; then OSFAMILY="RHEL"; fi
if [[ $OS == *"ARCH"* ]] || [[ $OS == *"MANJARO"* ]] || [[ $OS == *"ENDEAVOUROS"* ]] || [[ $OS == *"GARUDA"* ]]; then OSFAMILY="ARCH"; fi
if [[ $OS == *"DEBIAN"* ]] || [[ $OS == *"DEVUAN"* ]] || [[ $OS == *"RASPBIAN"* ]] || [[ $OS == *"LMDE"* ]]; then OSFAMILY="DEBIAN"; fi
if [[ $OS == *"FEDORA"* ]] || [[ $OS == *"NOBARA"* ]] || [[ $OS == *"ULTRAMARINE"* ]]; then OSFAMILY="FEDORA"; fi
if [[ $OS == *"OPENSUSE"* ]]; then OSFAMILY="SUSE"; fi
if [[ $OS == *"UBUNTU"* ]] || [[ $OS == *"MINT"* ]] || [[ $OS == *"POP!"* ]] || [[ $OS == *"ZORIN"* ]] || [[ $OS == *"ELEMENTARY"* ]] || [[ $OS == *"TUXEDO"* ]] || [[ $OS == *"NEON"* ]]; then OSFAMILY="UBUNTU"; fi
if [[ $OS == *"MANJARO ARM"* ]]; then OSFAMILY="MANARM"; fi
if [ -z $OSFAMILY ]; then OSFAMILY="FEDORA"; fi

# Now define the software tools etc. required for each family
# -----------------------------------------------------------------------------
case $OSFAMILY in
  ARCH)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    sudo  --noconfirm pacman -Syy >/dev/null 2>&1

    if sudo pacman -Qu | grep -q .; then
      echo " Your system has pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      exit 1
    fi

    sudo pacman -S --noconfirm dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc coreutils cuetools curl fd ncurses ffmpeg flac imagemagick kitty libsixel sqlite3 xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo pacman -S --noconfirm "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd  
  ;;
  
  DEBIAN)
  if [[ $CHECKONLY -eq 0 ]]; then
    # If sudo doesn't work, grant the user SUDO privileges. Otherwise, just get on with it...
    if ! sudo -n true 2>/dev/null; then
      tput cup $YPOS 1; echo "Please supply the **root user** password when prompted"; YPOS=$((YPOS+1))
      tput cup $YPOS 1; echo ""
      su -c "
      echo \"$USER ALL=(ALL:ALL) ALL\" >/etc/sudoers.d/$USER
      chmod 440 /etc/sudoers.d/$USER
      "
    fi

    if ! sudo -n true 2>/dev/null; then
      echo ""
      echo " Now please supply your own password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')

    if [[ $pending -gt 0 ]]; then
      echo " Your system has $pending pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      exit 1
    fi

    sudo apt -y install dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc coreutils cuetools curl fd-find ffmpeg flac imagemagick kitty libsixel-bin sqlite3 xterm)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -y install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fdfind  
  ;;
  
  UBUNTU)
   if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    sudo apt-get update -qq
    pending=$(apt-get -s upgrade | awk '/^Inst / {count++} END {print count+0}')

    if [[ $pending -gt 0 ]]; then
      echo " Your system has $pending pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      exit 1
    fi

    sudo apt -y install dialog > /dev/null 2>&1

    # Define what's required
    packages=(bc coreutils cuetools curl fd-find ffmpeg flac imagemagick kitty libsixel-bin xterm sqlite3)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo apt -y install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep SEDPROG=sed DATEPROG=date MD5PROG=md5sum FDPROG=fdfind
  ;;
  
  FEDORA)
    if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    sudo dnf check-update --refresh -q; rc=$?
    if [[ $rc -eq 100 ]]; then
      echo " Your system has pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      exit 1
    fi

    echo " Adding needed repositories. Please be patient..."
    sudo dnf -y install dialog > /dev/null 2>&1
    sudo dnf -y install https://download1.rpmfusion.org/free/fedora/rpmfusion-free-release-$(rpm -E %fedora).noarch.rpm >/dev/null 2>&1
    sudo dnf -y copr enable lchh/libsixel > /dev/null 2>&1

    # Define what's required
    packages=(bc cuetools coreutils curl fd-find ffmpeg flac ImageMagick ncurses sqlite3 xterm kitty libsixel libsixel-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70
    
    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;
  
  RHEL)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    sudo dnf check-update --refresh -q; rc=$?
    if [[ $rc -eq 100 ]]; then
      echo " Your system has pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      exit 1
    fi

    echo " Adding needed repositories. Please be patient..."
    sudo dnf -y install dialog > /dev/null 2>&1
    FUSIONON=$(sudo dnf repolist | grep epel | wc -l)
    if [ $FUSIONON -eq 0 ]; then
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://dl.fedoraproject.org/pub/epel/epel-next-release-latest-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/free/el/rpmfusion-free-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y install "https://mirrors.rpmfusion.org/nonfree/el/rpmfusion-nonfree-release-$(rpm -E %rhel).noarch.rpm" >/dev/null 2>&1
      sudo dnf -y config-manager --set-enabled crb >/dev/null 2>&1
    fi

    # Define what's required
    packages=(bc cuetools coreutils curl fd-find ffmpeg flac ImageMagick ncurses sqlite xterm kitty libsixel libsixel-utils)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo dnf -y install "$pkg" --allowerasing > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;
  
  SUSE)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    sudo timedatectl set-ntp true >/dev/null 2>&1
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."

    sudo zypper refresh >/dev/null
    if [[ $(sudo zypper lu | grep "No updates found." | wc -l) -eq 0 ]]; then
      echo " Your system has pending software updates. Please update your system manually."
      echo " This script will not proceed until you do."
      read -p " Press a key to continue."
      clear
      reset
      exit 1
    fi

    if [[ $OS == *"LEAP"* ]]; then
      sudo zypper ar -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Leap_'$THISVER/ packman
      sudo zypper --no-gpg-checks -n update
    else
      sudo zypper ar -cfp 90 'https://ftp.gwdg.de/pub/linux/misc/packman/suse/openSUSE_Tumbleweed/' packman
      sudo zypper --no-gpg-checks -n update
    fi
    
    sudo zypper --no-gpg-checks --non-interactive install -t pattern devel_basis
    sudo zypper --no-gpg-checks --non-interactive install dialog > /dev/null 2>&1

    # Define what's required
    packages=(ImageMagick fd libncurses6 coreutils cuetools bc flac ffmpeg xclip curl xterm dialog sqlite3 libsixel1 libsixel-utils kitty)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      sudo zypper --no-gpg-checks --non-interactive install "$pkg" > /dev/null 2>&1 || true
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Nienteo's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum FDPROG=fd
  ;;
  
  MACOS)
  if [[ $CHECKONLY -eq 0 ]]; then
    if ! sudo -n true 2>/dev/null; then
      echo "Please supply the sudo password:"
      sudo -v || { echo " Failed to acquire sudo privieleges, so quitting..."; exit 1; }
    fi

    # Keep sudo status for as long as needed
    while true; do sudo -n true; sleep 60; kill -0 "$$" || exit; done 2>/dev/null &
    echo ""
    echo " Getting the Niente installer ready. Please bear with us for a few moments..."
    echo ""

    # Create a destination folder for Giocoso
    if [[ ! -d /usr/local/bin ]]; then
      sudo mkdir -p /usr/local/bin
      sudo chown -R $(whoami) /usr/local/bin
      sudo chmod -R u=rwX,go=rX /usr/local/bin
    fi
    
     while true; do
      echo " Do you want to use Homebrew (h) or Macports (m) as your package installer?"
      echo " Note that whatever you choose here must have already been installed by you, manually."
      echo " Do not mix package installers: if you've already used one or the other, stick"
      echo " to that one now. If you have a free choice, choose Macports for older machines"
      echo " and for the fact that it's *much* faster to complete!"
      echo ""
      read -n 1 -p " Homebrew or Macports, then? (h/m): " input
      case "$input" in
       [hH])
         if command -v brew >/dev/null 2>&1; then
           pkgmanager=homebrew
           echo ""
           echo " Using the Homebrew Package Manager. Please hold on..."
           echo ""
           brew install --quiet dialog >/dev/null 2>&1
           break
         else
           echo ""
           echo " Unfortunately, it appears that Homebrew has not already been installed on this system."
           echo " Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1        
         fi  
         ;;
       [mM])
         if command -v port >/dev/null 2>&1; then
           pkgmanager=macports
           echo ""
           echo " Using the Macports Package Manager. Please wait..."
           echo ""
           sudo port -N install dialog > /dev/null 2>&1           
           break
         else
           echo ""
           echo " Unfortunately, it appears that Macports has not already been installed on this system."
           echo " Do that first, manually, before trying to re-run this installer."
           echo ""
           exit 1
         fi   
         ;;
       *)
         clear
         echo ""
         echo " Invalid input: only h or m are allowed. Please try again."
         echo ""
        ;;
      esac
    done

    # Define what's required
    bc coreutils cuetools curl fd ffmpeg flac ImageMagick imagemagick-full md5sha1sum ncurses sqlite3 util-linux xterm
    
    packages=(bc coreutils cuetools curl fd ffmpeg flac ImageMagick imagemagick-full md5sha1sum ncurses sqlite3 util-linux xterm libsixel kitty)
    total=${#packages[@]}
    count=0

    # Install what's required
    (
    for pkg in "${packages[@]}"; do
      count=$((count + 1 ))
      percent=$((count * 100 / total))
      echo $percent

      if [[ $pkgmanager == "homebrew" ]]; then
        brew install --quiet "$pkg" >/dev/null 2>&1
      elif [[ $pkgmanager == "macports" ]]; then
        sudo port -N install "$pkg" > /dev/null 2>&1
      fi
      
      sleep 0.1
    done
    ) | dialog --backtitle "Niente Software Install" --title "Installing Niente's Software Dependencies" --guage "\\n\\nInstallation may take some time. Please be patient..." 12 70

    # Confirmation when concluded
    dialog --backtitle "Niente Software Install" --title "Software Dependencies Installation Completed" --msgbox "\\n\\nAll Niente's software dependencies have been installed.\\n\\nClick OK to proceed." 12 70
  fi
  GREPPROG=grep  SEDPROG=gsed  DATEPROG=gdate  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  MANARM)
  if [ $CHECKONLY -eq 0 ]; then
    sudo pacman --noconfirm -Syy
    sudo pacman --noconfirm --needed -S imagemagick fd ncurses cuetools coreutils bc flac ffmpeg xclip curl xterm dialog sqlite3
    sudo pacman --noconfirm --needed -S yay 2>/dev/null
    dialog --stdout --backtitle "Niente Software Install" --msgbox "Software dependencies have been installed: \n\nClick OK to proceed." 10 80
  fi
  GREPPROG=grep  SEDPROG=sed  DATEPROG=date  MD5PROG=md5sum  FDPROG=fd
  ;;
  
  *)
  echo "You are using an unsupported operating system. Quitting!"
  exit 1
  ;;
esac

# Check which version of ImageMagick they have: if 'magick' works, it's 7
# -----------------------------------------------------------------------------
if hash magick 2>/dev/null; then
  CONVERTER=magick
else
  CONVERTER=convert
fi

echo "SEDPROG=$SEDPROG
GREPPROG=$GREPPROG
DATEPROG=$DATEPROG
MD5PROG=$MD5PROG
FDPROG=$FDPROG
CONVPROG=$CONVERTER"> "$HOME/.local/share/niente4/txt/programvariables.txt"
