cmake_minimum_required(VERSION 3.7.2)

include(settings.cmake)

project(sel4ipsrv C CXX ASM)

# used packages
find_package(camkes-tool REQUIRED)

# import/setup
camkes_tool_setup_camkes_build_environment()

# sources
DeclareCAmkESComponent(Client INCLUDES include SOURCES components/Client/src/client.c)
DeclareCAmkESComponent(Echo INCLUDES include SOURCES components/Echo/src/echo.c)
DeclareCAmkESComponent(IPServ INCLUDES include SOURCES components/IPServ/src/ipserv.c)

# targets
DeclareCAmkESRootserver(ipserv.camkes)
GenerateCAmkESRootserver()

# simulation
include(simulation)
GenerateSimulateScript()
