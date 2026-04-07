#!/bin/sh
killall telnetd
telnetd -l /bin/sh -p 23