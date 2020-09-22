<!--
SPDX-FileCopyrightText: 2019 Stefan Adams <stefan.adams@vipcomag.de>
SPDX-License-Identifier: GPL-3.0-or-later
-->

# zsipos

zsipos is a fully transparent system to encrypt your sip phone calls with ZRTP. It gets plugged between your sip phone and your sip proxy.


### Getting the sources

	$ git clone https://github.com/zsipos/zsipos
	$ cd zsipos
	$ git checkout zsipos-sel4
	$ git submodule update --init --recursive


### Prerequisites

We assume Ubuntu 18.04 and bash as the build environment.

You need around 80GB of free disk space.

You must install Vivado HLS WebPack 2018.3.1 (free, registration required). 

Get it from here: https://www.xilinx.com/products/design-tools/vivado/vivado-webpack.html .

It must be installed to `/opt/Xilinx` .


For all the other dependencies we prepared a install script for you:

	$ scripts/install-deps.sh

Please configure your git identity:

	$ git config --global user.email "you@example.com"
	$ git config --global user.name "Your Name"


Also please setup the haskell compiler:

	$ stack config set system-ghc --global true

Please do not run the build from a su session.


### Initializing the build environment

For the provided build scripts a build environment must be initialized.
You must initialize this environemt by typing:

	$ source scripts/env.sh

The first time you call this script it will set up a python virtual environemnt for you which may take some time.

### Building zsipos

To build zsipos please run its build script:

	$ build-dist.sh rebuild

### Preparing the hardware

You have to flash the fpga hardware. Either connect the hardware and run the command

	$ build-board.sh --nobuild --flashrom

or flash the file `./output/fpga-romboot.mcs` to the fpga with the vivado tools.

### Preparing the boot media

Prepare a sd-card with two linux partitions. Each partition should have a size of at least 1GB. Unpack the file
`./output/rootfs.tar` to the root directory of the first partition. 

### Starting the zsipos system the first time

The first time you start the system you will be forced to enter a new system password. The initial system password is zsipos2018.
If you enable sshd the first time you start the system with sshd it will generate its keys. This can take several minutes.


