#!/bin/sh -eu

service mariadb start
apachectl start
cd /var/www/dwc_network_server_emulator
python master_server.py