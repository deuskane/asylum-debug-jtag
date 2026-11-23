#!/bin/bash
#-----------------------------------------------------------------------------
# Title      : Hooks of the jtag_bitbang OpenOCD co-simulation
# Project    : Asylum
#-----------------------------------------------------------------------------
# File       : cosim.sh
# Author     : mrosiere
#-----------------------------------------------------------------------------
# Description: Hooks of the sim_openocd target (cwd = work root, files in
#              openocd/) :
#                build : pre_build, librbb.so (rbb_server.c)
#                start : pre_run, starts in the background : wait for the
#                        remote_bitbang port of the simulation, then OpenOCD
#                        with openocd/jtag.cfg (openocd.log), which runs the
#                        checks and shuts down : the simulation ends
#                check : post_run, prints openocd.log, fails unless the
#                        checks passed
#              Needs openocd.
#-----------------------------------------------------------------------------
# Copyright (c) 2026
#-----------------------------------------------------------------------------
# Revisions  :
# Date        Version  Author   Description
# 2026-11-22  1.0      mrosiere Created
#-----------------------------------------------------------------------------

PORT=9824

# True when the TCP port is listening
listening() {
    awk -v p=$(printf ':%04X' $1) '$2 ~ p"$" && $4 == "0A" {f = 1} END {exit !f}' /proc/net/tcp
}

# Wait (seconds) until the port listens or the process $2 ends
wait_port() {
    for t in $(seq 1 300); do
        listening $1 && return 0
        kill -0 $2 2>/dev/null || return 1
        sleep 1
    done
    return 1
}

background() {
    if wait_port $PORT $1; then
        timeout 600 openocd -f openocd/jtag.cfg > openocd.log 2>&1
        grep -qx "SCENARIO PASS" openocd.log && echo PASS > result || echo "FAIL : see openocd.log" > result
    else
        echo "FAIL : no simulation" > result
    fi
}

case $1 in
    build)
        gcc -shared -fPIC -O2 -Wall -o librbb.so openocd/rbb_server.c ;;
    start)
        rm -f result openocd.log
        setsid bash $0 background $PPID < /dev/null > cosim.log 2>&1 &
        echo "cosim.sh : OpenOCD started in the background" ;;
    background)
        background $2 ;;
    check)
        for t in $(seq 1 60); do [ -s result ] && break; sleep 1; done
        echo "===== openocd.log"; cat openocd.log
        echo "===== co-simulation : $(cat result)"
        [ "$(cat result)" = PASS ] ;;
esac
