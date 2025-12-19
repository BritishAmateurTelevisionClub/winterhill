#!/bin/bash

# WinterHill 3v20 install file
# G8GKQ 6 Mar 2021

# Winterhill for a 1920 x 1080 screen

whoami | grep -q pi
if [ $? != 0 ]; then
  echo "Install must be performed as user pi"
  exit
fi

# Amend the sources.list to legacy
sudo bash -c 'echo -e "deb http://legacy.raspbian.org/raspbian/ buster main contrib non-free rpi" > /etc/apt/sources.list' 

echo
echo "Updating the OS and Installed Packages"
echo

sudo dpkg --configure -a                         # Make sure that all the packages are properly configured
sudo apt-get clean                               # Clean up the old archived packages
sudo apt-get update --allow-releaseinfo-change   # Update the package list
sudo apt-get -y dist-upgrade                     # Upgrade all the installed packages to their latest version

# Check which source needs to be loaded
GIT_SRC="BritishAmateurTelevisionClub"
GIT_SRC_FILE=".wh_gitsrc"

if [ "$1" == "-d" ]; then
  GIT_SRC="davecrump";  # G8GKQ
  #GIT_SRC="foxcube";    # G4EWJ
  echo
  echo "-------------------------------------------------------"
  echo "----- Installing development version of WinterHill-----"
  echo "-------------------------------------------------------"
elif [ "$1" == "-u" -a ! -z "$2" ]; then
  GIT_SRC="$2"
  echo
  echo "WARNING: Installing ${GIT_SRC} development version, press enter to continue or 'q' to quit."
  read -n1 -r -s key;
  if [[ $key == q ]]; then
    exit 1;
  fi
  echo "ok!";
else
  echo
  echo "------------------------------------------------------------"
  echo "----- Installing BATC Production version of WinterHill -----"
  echo "------------------------------------------------------------"
fi

cd /home/pi

echo "--------------------------------------------------------"
echo "----- Disabling the raspberry ssh password warning -----"
echo "--------------------------------------------------------"
echo
sudo mv /etc/xdg/lxsession/LXDE-pi/sshpwd.sh /etc/xdg/lxsession/LXDE-pi/sshpwd.sh.old

echo "------------------------------------"
echo "---- Loading required packages -----"
echo "------------------------------------"
echo
sudo apt-get -y install xdotool xterm raspberrypi-kernel-headers

echo "--------------------------------------------------------------"
echo "---- Put the Desktop Toolbar at the bottom of the screen -----"
echo "--------------------------------------------------------------"
echo
cd /home/pi/.config/lxpanel/LXDE-pi/panels
sed -i "/^  edge=top/c\  edge=bottom" panel
cd /home/pi

echo "----------------------------------------------------"
echo "---- Increasing gpu memory in /boot/config.txt -----"
echo "----------------------------------------------------"
echo
sudo bash -c 'echo -e "\n##Increase GPU Memory" >> /boot/config.txt'
sudo bash -c 'echo -e "gpu_mem=128\n" >> /boot/config.txt'

echo "-------------------------------------------------"
echo "---- Set force_turbo for constant spi speed -----"
echo "-------------------------------------------------"
echo
sudo bash -c 'echo -e "##Set force_turbo for constant spi speed" >> /boot/config.txt'
sudo bash -c 'echo -e "force_turbo=1\n" >> /boot/config.txt'

echo "--------------------------------------"
echo "---- Set the spi ports correctly -----"
echo "--------------------------------------"
echo
sudo sed -i "/^#dtparam=spi=on/c\dtparam=spi=off\ndtoverlay=spi5-1cs" /boot/config.txt

echo "----------------------------------------------"
echo "---- Setting Framebuffer to 32 bit depth -----"
echo "----------------------------------------------"
echo
sudo sed -i "/^dtoverlay=vc4-fkms-v3d/c\#dtoverlay=vc4-fkms-v3d" /boot/config.txt

echo "------------------------------------------------------------"
echo "---- Setting GUI to start with or without HDMI display -----"
echo "------------------------------------------------------------"
echo
sudo sed -i "/^#hdmi_force_hotplug=1/c\hdmi_force_hotplug=1" /boot/config.txt


echo "-------------------------------------------"
echo "---- Download the WinterHill Software -----"
echo "-------------------------------------------"
echo
cd /home/pi
wget https://github.com/${GIT_SRC}/winterhill/archive/main.zip
unzip -o main.zip
mv winterhill-main winterhill
rm main.zip

BUILD_VERSION=$(</home/pi/winterhill/latest_version.txt)
echo INSTALL WinterHill build started version $BUILD_VERSION > /home/pi/winterhill/whlog.txt

echo "------------------------------------------"
echo "---- Building spi driver for install -----"
echo "------------------------------------------"
echo
cd /home/pi/winterhill/whsource-3v20/whdriver-3v20
make
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "- Failed to build the WinterHill Driver --"
  echo "------------------------------------------"
  echo INSTALL Initial make of driver failed >> /home/pi/winterhill/whlog.txt
  exit
fi

# sudo rmmod whdriver-2v22.ko  # Use in future update scripts

sudo insmod whdriver-3v20.ko
if [ $? != 0 ]; then
  echo "------------------------------------------"
  echo "--- Failed to load WinterHill Driver -----"
  echo "------------------------------------------"
  echo INSTALL Initial insmod of driver failed >> /home/pi/winterhill/whlog.txt
  exit
fi

cat /proc/modules | grep -q 'whdriver_3v20'
if [ $? != 0 ]; then
  echo "-------------------------------------------------------------"
  echo "--- Failed to find previously loaded  WinterHill Driver -----"
  echo "-------------------------------------------------------------"
  echo INSTALL Initial check of driver failed >> /home/pi/winterhill/whlog.txt
  exit
else
  echo
  echo "------------------------------------------------"
  echo "--- Successfully loaded  WinterHill Driver -----"
  echo "------------------------------------------------"
  echo INSTALL Driver Successfully loaded >> /home/pi/winterhill/whlog.txt
  echo
fi
cd /home/pi

echo "------------------------------------------------"
echo "---- Set up to load the spi driver at boot -----"
echo "------------------------------------------------"
echo
sudo sed -i "/^exit 0/c\cd /home/pi/winterhill/whsource-3v20/whdriver-3v20\nsudo insmod whdriver-3v20.ko\nexit 0" /etc/rc.local

echo "---------------------------------------------------"
echo "---- Building the main WinterHill Application -----"
echo "---------------------------------------------------"
echo
cd /home/pi/winterhill/whsource-3v20/whmain-3v20
make
if [ $? != 0 ]; then
  echo "----------------------------------------------"
  echo "- Failed to build the WinterHill Application -"
  echo "----------------------------------------------"
  echo INSTALL make of main application failed >> /home/pi/winterhill/whlog.txt
  exit
fi
cp winterhill-3v20 /home/pi/winterhill/RPi-3v20/winterhill-3v20
cd /home/pi

echo "--------------------------------------"
echo "---- Building the PIC Programmer -----"
echo "--------------------------------------"
echo
cd /home/pi/winterhill/whsource-3v20/whpicprog-3v20
./make.sh
if [ $? != 0 ]; then
  echo "--------------------------------------"
  echo "- Failed to build the PIC Programmer -"
  echo "--------------------------------------"
  echo INSTALL make of PIC Programmer failed >> /home/pi/winterhill/whlog.txt
  exit
fi
cp whpicprog-3v20 /home/pi/winterhill/PIC-3v20/whpicprog-3v20
cd /home/pi

echo "--------------------------------------------"
echo "---- Copy the shortcuts to the desktop -----"
echo "--------------------------------------------"
echo
cp /home/pi/winterhill/configs/Kill_WH           /home/pi/Desktop/Kill_WH
cp /home/pi/winterhill/configs/WH_Local          /home/pi/Desktop/WH_Local
cp /home/pi/winterhill/configs/WH_Anyhub         /home/pi/Desktop/WH_Anyhub
cp /home/pi/winterhill/configs/WH_Anywhere       /home/pi/Desktop/WH_Anywhere
cp /home/pi/winterhill/configs/WH_Multihub       /home/pi/Desktop/WH_Multihub
cp /home/pi/winterhill/configs/WH_Fixed          /home/pi/Desktop/WH_Fixed
cp /home/pi/winterhill/configs/PIC_Prog          /home/pi/Desktop/PIC_Prog
cp /home/pi/winterhill/configs/Show_IP           /home/pi/Desktop/Show_IP
cp /home/pi/winterhill/configs/Shutdown          /home/pi/Desktop/Shutdown
cp /home/pi/winterhill/configs/Check_for_Update  /home/pi/Desktop/Check_for_Update

echo "--------------------------------------------------------------------"
echo "---- Enable Autostart for the selected WinterHill mode at boot -----"
echo "--------------------------------------------------------------------"
echo
mkdir /home/pi/.config/autostart
cp /home/pi/winterhill/configs/startup.desktop /home/pi/.config/autostart/startup.desktop

# Save git source used
echo "${GIT_SRC}" > /home/pi/${GIT_SRC_FILE}

echo
echo "SD Card Serial:"
cat /sys/block/mmcblk0/device/cid

# Reboot
echo
echo "--------------------------------"
echo "----- Complete.  Rebooting -----"
echo "--------------------------------"
echo INSTALL Reached end of install script >> /home/pi/winterhill/whlog.txt

sleep 1

sudo reboot now
exit


