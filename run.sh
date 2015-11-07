#!/bin/bash

echo "Welcome to CupBird"

if [ ! -f ~/.ssh/id_rsa_gitlab ]; then
    echo "You have to specify your gitlab key by running your VM with docker run ... -v path_of_your_rsa_gitlab:/root/.ssh/id_rsa_gitlab"
    /bin/bash
    exit 0
fi

eval `ssh-agent -s` > /dev/null 2> /dev/null
ssh-add /root/.ssh/id_rsa_gitlab > /dev/null 2> /dev/null


echo "--------------------- Vhost  -------------------------------"

echo "<VirtualHost *:80>
        ServerAdmin webmaster@localhost
        DocumentRoot /var/docker/sources/web
        ErrorLog ${APACHE_LOG_DIR}/error.log
        CustomLog ${APACHE_LOG_DIR}/access.log combined
</VirtualHost>
" > /etc/apache2/sites-enabled/000-default.conf


echo "----------------------------- START APACHE AND MYSQL -------------------------------"

service apache2 start > /tmp/null 2> /dev/null
service mysql start  > /tmp/null 2> /dev/null
mysql -u root -e "CREATE DATABASE IF NOT EXISTS cupbird " -pdocker

echo "----------------------------- CLONE CUPBIRD ----------------------------- "

choice="Y"

DIR="/var/docker/sources/"

if [ "$(ls -A $DIR)" ]; then
    echo "Source Files already Present in your shared Volumes, So we keep it. If You want new source, delete your shared volumes or move it in an other folder"
    choice="N"
fi

if [ "$choice" == "Y" ] ; then
    git clone -b master git@github.com:jordscream/cupbird.git /var/docker/sources
    php /usr/bin/composer.phar update
fi

echo "-------------------- PREPARE CUSTOM DIRECTORY (Cache,Uploads) --------------------"
# FILE upload uploads/media
if [ ! -d "/var/docker/sources/web/uploads" ]; then
  mkdir /var/docker/sources/web/uploads
fi
chmod -R 777 /var/docker/sources/web/uploads
# FILE upload uploads/media
if [ ! -d "/var/docker/sources/web/uploads/media" ]; then
  mkdir /var/docker/sources/web/uploads/media
fi
chmod -R 777 /var/docker/sources/web/uploads/media

chmod -R 777 /var/docker/sources/app/cache
chmod -R 777 /var/docker/sources/app/logs

echo "----------------------------- INIT DATABASE ----------------------------------------"


if [ -f "/var/docker/mysql/cupbird/cupbird_user.frm" ]; then
     echo "It seems your database present in your shared volume is not empty, none action required"
else
     mysql -u root -e "CREATE DATABASE IF NOT EXISTS cupbird " -pdocker
     php /var/docker/sources/app/console doctrine:schema:create
     rm -rf app/cache/*
     # symofony load fixture
     php /var/docker/sources/app/console doctrine:fixtures:load --no-interaction
fi

echo "----------------------------- SYMFONY SPECIFIC CMD  -------------------------------"
#assets install
php /var/docker/sources/app/console assets:install
#cache clear
php /var/docker/sources/app/console cache:clear
chmod -R 777 /var/docker/sources/app/cache/*

echo "----------------------------- EXECUTE SHELL STDIN ------------------------------------------"
cd /var/docker/sources && /bin/bash
