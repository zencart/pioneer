#!/usr/bin/env bash

printf "\nHABITAT=\"zencart\"\n" | tee -a /home/vagrant/.profile

# Set up some folders for syncing
mkdir -pv /home/vagrant/habitat/
mkdir -pv /home/vagrant/web

# Update Package List

apt-get update

apt-get upgrade -y

# Install Some PPAs

apt-get install -y software-properties-common

apt-add-repository ppa:nginx/stable -y
apt-add-repository ppa:rwky/redis -y
apt-add-repository ppa:chris-lea/node.js -y
apt-add-repository ppa:ondrej/php5 -y

# Update Package Lists using added repos

apt-get update

# Install Some Basic Packages

apt-get install -y build-essential curl dos2unix gcc git libmcrypt4 libpcre3-dev \
make re2c supervisor unattended-upgrades whois vim tig nfs-common

# Install A Few Helpful Python Packages

#apt-get install -y python2.7-dev python-pip
#pip install httpie
#pip install fabric
#pip install python-simple-hipchat

# Set My Timezone

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Write Bash Aliases

cp /vagrant/aliases /home/vagrant/.bash_aliases

# Install PHP Stuff

apt-get install -y php5-cli php5-dev php-pear \
php5-mysqlnd php5-apcu php5-json php5-curl php5-gd \
php5-imap php5-mcrypt php5-xdebug php5-memcached

# Make MCrypt Available

ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available
sudo php5enmod mcrypt

# Install Composer

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer

# Add Composer Global Bin To Path

printf "\nPATH=\"/home/vagrant/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile

# Install some code optimization tools
# - some default gitignore values
# - basic composer install, with phpunit-related components
# - selenium for scripted functional testing

sudo su vagrant <<'EOF'
cp /vagrant/.gitignore_global /home/vagrant/.gitignore_global
git config --global --add core.excludesfile ~/.gitignore_global
mkdir ~/tools
cd ~/tools
cp /vagrant/unittest .
mkdir composer
cd composer
cp /vagrant/composer.json .
composer install
cd ..
mkdir selenium
cd selenium
wget http://selenium-release.storage.googleapis.com/2.42/selenium-server-standalone-2.42.2.jar
mv selenium-server-standalone-2.42.2.jar selenium-server-standalone.jar
chmod a+x selenium-server-standalone.jar
EOF

# Set Some PHP CLI Settings

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php5/cli/php.ini

# Install Nginx & PHP-FPM

apt-get install -y nginx php5-fpm

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart

# Setup Some PHP-FPM Options

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/fpm/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 512M/" /etc/php5/fpm/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 512M/" /etc/php5/fpm/php.ini
sudo sed -i "s/html_errors = .*/html_errors = Off/" /etc/php5/fpm/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php5/fpm/php.ini
sudo sed -i "s/error_log = .*/error_log = \/home\/vagrant\/habitat\/php5-fpm.log/" /etc/php5/fpm/php-fpm.conf

# Set The Nginx & PHP-FPM User

sed -i "s/user www-data;/user vagrant;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf
sed -i "s/\/var\/log\/nginx/\/home\/vagrant\/habitat/" /etc/nginx/nginx.conf

sed -i "s/user = www-data/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = vagrant/" /etc/php5/fpm/pool.d/www.conf

sed -i "s/;listen\.owner.*/listen.owner = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.group.*/listen.group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf

service nginx restart
service php5-fpm restart

# Add Vagrant User To WWW-Data

usermod -a -G www-data vagrant
id vagrant
groups vagrant


# Install Apache
apt-get install -y apache2 libapache2-mod-php5 apache2-utils
sed -i "s/export APACHE_RUN_USER=www-data/export APACHE_RUN_USER=vagrant/" /etc/apache2/envvars
sed -i "s/export APACHE_RUN_GROUP=www-data/export APACHE_RUN_GROUP=vagrant/" /etc/apache2/envvars
sed -i "s/export APACHE_LOG_DIR=\/var\/log\/apache2$SUFFIX/export APACHE_LOG_DIR=\/home\/vagrant\/habitat\/$SUFFIX/" /etc/apache2/envvars
printf "\nServerName habitat.local\n" | tee -a /etc/apache2/apache2.conf
printf "\nexport HABITAT=zencart\n" | tee -a /etc/apache2/envvars
rm -Rf /var/www/html
ln -s /home/vagrant/web /var/www/html
#echo "<?php phpinfo(); " > /home/vagrant/web/index.php
a2enmod ssl rewrite
service apache2 restart

# Set apache2-php settings
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/apache2/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/apache2/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 512M/" /etc/php5/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 512M/" /etc/php5/apache2/php.ini
sudo sed -i "s/html_errors = .*/html_errors = Off/" /etc/php5/apache2/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php5/apache2/php.ini

# Install MySQL

debconf-set-selections <<< "mysql-server mysql-server/root_password password zencart"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password zencart"
apt-get install -y mysql-server

# Enable MySQL slow-query-logging
cp /vagrant/log_slow_queries.cnf /etc/mysql/conf.d/

# Configure MySQL Remote Access

sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 10.0.2.15/' /etc/mysql/my.cnf
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO root@'10.0.2.2' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
service mysql restart

mysql --user="root" --password="zencart" -e "CREATE DATABASE zencart;"
mysql --user="root" --password="zencart" -e "CREATE USER 'zencart'@'10.0.2.2' IDENTIFIED BY 'zencart';"
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO 'zencart'@'10.0.2.2' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO 'zencart'@'%' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
mysql --user="root" --password="zencart" -e "FLUSH PRIVILEGES;"

service mysql restart

# Install phpMyAdmin

debconf-set-selections <<< "phpmyadmin phpmyadmin/dbconfig-install boolean false"
debconf-set-selections <<< "phpmyadmin phpmyadmin/reconfigure-webserver multiselect apache2"
debconf-set-selections <<< "phpmyadmin phpmyadmin/app-password-confirm password zencart"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/admin-pass password zencart"
debconf-set-selections <<< "phpmyadmin phpmyadmin/password-confirm password zencart"
debconf-set-selections <<< "phpmyadmin phpmyadmin/setup-password password zencart"
debconf-set-selections <<< "phpmyadmin phpmyadmin/database-type select mysql"
debconf-set-selections <<< "phpmyadmin phpmyadmin/mysql/app-pass password zencart"
debconf-set-selections <<< "dbconfig-common dbconfig-common/mysql/app-pass password zencart"
debconf-set-selections <<< "dbconfig-common dbconfig-common/mysql/app-pass password"
debconf-set-selections <<< "dbconfig-common dbconfig-common/password-confirm password zencart"
debconf-set-selections <<< "dbconfig-common dbconfig-common/app-password-confirm password zencart"
debconf-set-selections <<< "dbconfig-common dbconfig-common/app-password-confirm password zencart"
debconf-set-selections <<< "dbconfig-common dbconfig-common/password-confirm password zencart"
 # Handy for debugging. clear answers phpmyadmin: echo PURGE | debconf-communicate phpmyadmin
apt-get -y install phpmyadmin
sudo sed -i "s/$cfg\['UploadDir'] = .*;/$cfg['UploadDir'] = '\/var\/lib\/phpmyadmin\/tmp';/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/$cfg\['SaveDir'] = .*;/$cfg['SaveDir'] = '\/var\/lib\/phpmyadmin\/tmp';/" /etc/phpmyadmin/config.inc.php
#ln -s /usr/share/phpmyadmin /usr/share/nginx/html

echo "Removing unneeded packages ..."
# Keep things pristine
apt-get -y autoremove
apt-get -y clean

### Compress Image Size
# Zero out the free space to save space in the final image
# (this may take a minute to run, at the end of the script, and may look like it's hanging; just be patient)
echo "Clearing empty space ..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
echo "Done."
