#!/bin/bash
apt -y update
apt -y install apache2
echo "Hello, World!" > /var/www/html/index.html
sudo service apache2 start
chkconfig apache2 on