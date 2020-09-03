# SPDX-FileCopyrightText: 2018-2019 Jonathan Richard Robert Kimmitt <jrrk2@cam.ac.uk>
# SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
#
# SPDX-License-Identifier: Apache-2.0
set -e
WRKDIR=debian-rootfs
if [ ! -d "$WRKDIR" ]
then
	#Make a directory to hold the riscv emulator
	sudo mkdir -p "$WRKDIR"/usr/bin
	#Copy the emulator
	sudo cp "$RISCV/bin/qemu-riscv64" "$WRKDIR"/usr/bin/qemu-riscv64-static
	#Make sure the correct keyring is installed
	sudo apt install debootstrap debian-ports-archive-keyring
	#Perform the first stage bootstrap
	sudo debootstrap \
		--arch=riscv64 \
		--variant=minbase \
		--keyring=/etc/apt/trusted.gpg \
	     	--include=gnupg sid "$WRKDIR" \
	     	http://deb.debian.org/debian-ports
	#Create the tmp directory (if needed)
	sudo mkdir -p -m 777 "$WRKDIR"/tmp
	#Update sources.list
	# sudo cp work/sources.list "$WRKDIR"/etc/apt
	#Install the signing key
	sudo chroot "$WRKDIR" apt-key adv --recv-keys --keyserver keyserver.ubuntu.com DA1B2CEA81DCBC61
fi

#Update apt
sudo chroot "$WRKDIR" apt update
sudo chroot "$WRKDIR" apt upgrade

#Install the development environment
sudo chroot "$WRKDIR" apt install -y \
        debian-ports-archive-keyring \
	dialog \
	locales \
	sysvinit-core \
	openssh-client \
	openssh-server 

#Enable the Ethernet interface
# sudo cp work/interfaces "$WRKDIR"/etc/network
#Update the hostname
#sudo cp work/hostname "$WRKDIR"/etc

#Set the root password 
sudo chroot "$WRKDIR" passwd root

#Setup locales
sudo chroot "$WRKDIR" dpkg-reconfigure locales

#Setup timezone
sudo chroot "$WRKDIR" dpkg-reconfigure tzdata

