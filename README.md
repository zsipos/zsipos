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

Also please setup the haskell compiler:

	$ stack config set system-ghc --global true

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

### Building the linux/sel4 ssh test program

To build the linux/sel4 ssh test program please run its build script:

	$ build-dist.sh rebuild

### Running the linux/sel4 ssh test program

You need the zsipos hardware to run the linux/sel4 ssh test program.
First you have to flash the fpga hardware. Either connect the hardware and run the command

	$ build-board.sh --nobuild --flashrom

or flash the file `./output/fpga-romboot.mcs` to the fpga with the vivado tools.

After that unpack the file `./output/rootfs.tar` to the root directory of a SD-card containing a empty ext4 filesystem. 
This is the root filesystem of the fpga system. You may want to edit the file `/etc/init.d/S40network`
to match your network configuration. Start the fpga. 
**The first time you start the system sshd will generate its keys. This can take some minutes.**
After that you can open a ssh session to the linux system on the fpga:

	$ ssh your_ip_address -l root

The initial password of user `root` is `root`. It is a good practice to change this for security reasons.

### Building the linux/sel4 test suite

To build the linux/sel4 test suite please run its build script:

	$ build-sel4test.sh

### Running the linux/sel4 test suite

To run the linux/sel4 test suite please run 

	$ run-sel4test.sh

Both the linux system and the sel4test program write their output to the same console, so the output gets mixed.
To verify that the linux system is functional you can give a shell command, e.g. `ls -l` during the sel4test.
At the end of the sel4test you should see the following message:

	Test suite passed. 115 tests passed. 46 tests disabled.
	All is well in the universe


The linux shell keeps accepting commands. To exit qemu please type **`Ctrl+A X`**.


