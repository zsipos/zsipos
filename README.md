# zsipos

zsipos is a fully transparent system to encrypt your sip phone calls with ZRTP. It gets plugged between you sip phone and your sip proxy.


### Getting the sources

	$ git clone https://github.com/zsipos/zsipos
	$ cd zsipos
	$ git checkout zsipos-sel4
	$ git submodule update --init --recursive


### Prerequisites

We assume Ubuntu 18.04 and bash as the build environemnt.

You need around 80GB of free disk space.

You must install Vivado HLS WebPack 2018.3.1 (free, registration required). 

Get it from here: https://www.xilinx.com/products/design-tools/vivado/vivado-webpack.html .

It must be installed to `/opt/Xilinx` .


For all the other dependencies we prepared a install script for you:

	$ scripts/install-deps.sh


Please configure your git identity:

	$ git config --global user.email "you@example.com"
	$ git config --global user.name "Your Name"


Please do not run the build from a su session.


### Initializing the build environment

For the provided build scripts a build environment must be initialized.
You must initialize this environemt by typing:

	$ source scripts/env.sh

The first time you call this script it will set up a python virtual environemnt for you which may take some time.

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







