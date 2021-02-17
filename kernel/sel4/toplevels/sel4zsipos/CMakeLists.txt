# SPDX-FileCopyrightText: 2020 Stefan Adams <stefan.adams@vipcomag.de>
# SPDX-License-Identifier: GPL-3.0-or-later

cmake_minimum_required(VERSION 3.7.2)

include(settings.cmake)

project(sel4ipsrv C CXX ASM)

# project include directories
include_directories(${CMAKE_CURRENT_LIST_DIR}/include)

# used packages
find_package(camkes-tool REQUIRED)
find_package(libpicotcpng REQUIRED)

# import/setup
camkes_tool_setup_camkes_build_environment()
libpicotcpng_import_library()

# sources
DeclareCAmkESComponent(MSTick 
	INCLUDES
		include 
	SOURCES
		components/MSTick/src/mstick.c
)

DeclareCAmkESComponent(IPServ 
	INCLUDES
		include 
	SOURCES
		components/IPServ/src/ipserv.c
		components/IPServ/src/remcalls_s.c
		components/IPServ/src/pico_dev_litex.c
		components/IPServ/src/mt19937-64.c
	LIBS
		picotcp
)

# targets
DeclareCAmkESRootserver(ipserv.camkes)
GenerateCAmkESRootserver()

# simulation
include(simulation)
GenerateSimulateScript()
