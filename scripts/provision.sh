#!/usr/bin/env bash

echo "Provisioning Habitat environment ..."

printf "\nHABITAT=\"zencart\"\n" | tee -a /home/vagrant/.profile

# Set up some folders for syncing
mkdir -pv /home/vagrant/habitat/
mkdir -pv /home/vagrant/web

# Update Package List

apt-get update

# Update System Packages
apt-get -y upgrade

# Force Locale

echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Install Some PPAs

apt-get install -y software-properties-common curl

apt-add-repository ppa:nginx/stable -y
apt-add-repository ppa:chris-lea/node.js -y

#PHP 5.6
apt-add-repository ppa:ondrej/php5-5.6 -y
#PHP 5.5
#apt-add-repository ppa:ondrej/php5 -y
#PHP 5.4:
#apt-add-repository ppa:ondrej/php5-oldstable -y

#MySQL versions
#apt-add-repository ppa:ondrej/mysql-5.6 -y
#apt-add-repository ppa:ondrej/mysql-5.7 -y
#apt-add-repository ppa:ondrej/mariadb-5.5 -y

# Update Package Lists

apt-get update

# Install Some Basic Packages

apt-get install -y build-essential dos2unix gcc git libmcrypt4 libpcre3-dev \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim \
tig nfs-common ntp

# Set My Timezone

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Write Bash Aliases

cp /vagrant/aliases /home/vagrant/.bash_aliases

# Install PHP Stuff

apt-get install -y php5-cli php5-dev php-pear \
php5-mysqlnd php5-sqlite \
php5-apcu php5-json php5-curl php5-gd \
php5-gmp php5-imap php5-mcrypt php5-xdebug \
php5-memcached \
php5-xsl

# Make MCrypt Available

ln -s /etc/php5/conf.d/mcrypt.ini /etc/php5/mods-available
sudo php5enmod mcrypt

# Install Mailparse PECL Extension

pecl install mailparse
echo "extension=mailparse.so" > /etc/php5/mods-available/mailparse.ini
ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/cli/conf.d/20-mailparse.ini

# Install Composer

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
crontab -e * 12 * * * /usr/local/bin/composer self-update >/dev/null 2>&1

# Add Composer Global Bin To Path

printf "\nPATH=\"/home/vagrant/.composer/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile

# Install Laravel Envoy

sudo su vagrant <<'EOF'
/usr/local/bin/composer global require "laravel/envoy=~1.0"
EOF

# Install some code optimization tools
# - some default gitignore values
# - basic composer install, with phpunit-related components
# - selenium for scripted functional testing

sudo su vagrant <<'EOF'
cp /vagrant/.gitignore_global /home/vagrant/.gitignore_global
git config --global --add core.excludesfile ~/.gitignore_global
mkdir ~/tools
cd ~/tools
cp /vagrant/scripts/unittest .
cp /vagrant/scripts/dbtest .
cp /vagrant/scripts/generatedocs .
mkdir composer
cd composer
cp /vagrant/composer.json .
composer install
cd ..
#mkdir selenium
#cd selenium
#wget http://selenium-release.storage.googleapis.com/2.42/selenium-server-standalone-2.42.2.jar
#mv selenium-server-standalone-2.42.2.jar selenium-server-standalone.jar
#chmod a+x selenium-server-standalone.jar
cd ~
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts
EOF

# Set Some PHP CLI Settings

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/cli/php.ini

# sync error logs
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php5/cli/php.ini

# Install Nginx & PHP-FPM

apt-get install -y nginx php5-fpm

rm /etc/nginx/sites-enabled/default
rm /etc/nginx/sites-available/default
service nginx restart

# Setup Some PHP-FPM Options

ln -s /etc/php5/mods-available/mailparse.ini /etc/php5/fpm/conf.d/20-mailparse.ini

sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php5/fpm/php.ini
sed -i "s/display_errors = .*/display_errors = On/" /etc/php5/fpm/php.ini
sed -i "s/;cgi.fix_pathinfo=1/cgi.fix_pathinfo=0/" /etc/php5/fpm/php.ini
sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php5/fpm/php.ini
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 100M/" /etc/php5/fpm/php.ini
sed -i "s/post_max_size = .*/post_max_size = 512M/" /etc/php5/fpm/php.ini
sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php5/fpm/php.ini

# Additional dev settings
sed -i "s/upload_max_filesize = .*/upload_max_filesize = 512M/" /etc/php5/fpm/php.ini
sed -i "s/html_errors = .*/html_errors = Off/" /etc/php5/fpm/php.ini

# sync error logs
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php5/fpm/php.ini
sudo sed -i "s/error_log = .*/error_log = \/home\/vagrant\/habitat\/php5-fpm.log/" /etc/php5/fpm/php-fpm.conf

# Configure xdebug for remote use

echo "xdebug.remote_enable = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_connect_back = 1" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.remote_port = 9000" >> /etc/php5/fpm/conf.d/20-xdebug.ini
echo "xdebug.max_nesting_level = 250" >> /etc/php5/fpm/conf.d/20-xdebug.ini

# Copy fastcgi_params to Nginx because they broke it on the PPA

cat > /etc/nginx/fastcgi_params << EOF
fastcgi_param	QUERY_STRING		\$query_string;
fastcgi_param	REQUEST_METHOD		\$request_method;
fastcgi_param	CONTENT_TYPE		\$content_type;
fastcgi_param	CONTENT_LENGTH		\$content_length;
fastcgi_param	SCRIPT_FILENAME		\$request_filename;
fastcgi_param	SCRIPT_NAME		\$fastcgi_script_name;
fastcgi_param	REQUEST_URI		\$request_uri;
fastcgi_param	DOCUMENT_URI		\$document_uri;
fastcgi_param	DOCUMENT_ROOT		\$document_root;
fastcgi_param	SERVER_PROTOCOL		\$server_protocol;
fastcgi_param	GATEWAY_INTERFACE	CGI/1.1;
fastcgi_param	SERVER_SOFTWARE		nginx/\$nginx_version;
fastcgi_param	REMOTE_ADDR		\$remote_addr;
fastcgi_param	REMOTE_PORT		\$remote_port;
fastcgi_param	SERVER_ADDR		\$server_addr;
fastcgi_param	SERVER_PORT		\$server_port;
fastcgi_param	SERVER_NAME		\$server_name;
fastcgi_param	HTTPS			\$https if_not_empty;
fastcgi_param	REDIRECT_STATUS		200;
EOF

# Set The Nginx & PHP-FPM User

sed -i "s/user www-data;/user vagrant;/" /etc/nginx/nginx.conf
sed -i "s/# server_names_hash_bucket_size.*/server_names_hash_bucket_size 64;/" /etc/nginx/nginx.conf

# sync error logs
sed -i "s/\/var\/log\/nginx/\/home\/vagrant\/habitat/" /etc/nginx/nginx.conf

sed -i "s/user = www-data/user = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/group = www-data/group = vagrant/" /etc/php5/fpm/pool.d/www.conf

sed -i "s/listen\.owner.*/listen.owner = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/listen\.group.*/listen.group = vagrant/" /etc/php5/fpm/pool.d/www.conf
sed -i "s/;listen\.mode.*/listen.mode = 0666/" /etc/php5/fpm/pool.d/www.conf

service nginx restart
service php5-fpm restart

# Now leave nginx disabled
service nginx stop
sudo update-rc.d -f nginx disable
service php5-fpm stop
sudo update-rc.d -f php5-fpm disable

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


# Install Node

apt-get install -y nodejs
/usr/bin/npm install -g grunt-cli
/usr/bin/npm install -g gulp
/usr/bin/npm install -g bower

# Install SQLite

apt-get install -y sqlite3 libsqlite3-dev

# Install MySQL

debconf-set-selections <<< "mysql-server mysql-server/root_password password zencart"
debconf-set-selections <<< "mysql-server mysql-server/root_password_again password zencart"
apt-get install -y mysql-server

# Enable MySQL slow-query-logging
cp /vagrant/log_slow_queries.cnf /etc/mysql/conf.d/

# Configure MySQL Remote Access

sed -i '/^bind-address/s/bind-address.*=.*/bind-address = 0.0.0.0/' /etc/mysql/my.cnf
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO root@'0.0.0.0' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
echo "MySQL restart 1"
service mysql restart

mysql --user="root" --password="zencart" -e "CREATE USER 'zencart'@'0.0.0.0' IDENTIFIED BY 'zencart';"
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO 'zencart'@'0.0.0.0' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
mysql --user="root" --password="zencart" -e "GRANT ALL ON *.* TO 'zencart'@'%' IDENTIFIED BY 'zencart' WITH GRANT OPTION;"
mysql --user="root" --password="zencart" -e "FLUSH PRIVILEGES;"
mysql --user="root" --password="zencart" -e "CREATE DATABASE zencart;"
echo "MySQL restart 2"
service mysql restart

# Add Timezone Support To MySQL

echo "Adding timezone support to MySQL ..."
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=zencart mysql

# Install phpMyAdmin
echo "Installing phpMyAdmin ..."
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


# Install Zend Server installer script, for developer optimization benefits (can be installed manually if developers desire)
cp /vagrant/install_zendserver.sh /home/vagrant/
chmod 744 /home/vagrant/install_zendserver.sh

# Install A Few Other Things

apt-get install -y memcached

# Apply any remaining updates to packages
apt-get update -y
apt-get upgrade -y

# Keep things pristine

echo "Removing unneeded packages ..."
apt-get -y autoremove
apt-get -y clean

# Enable Swap Memory

/bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=1024
/sbin/mkswap /var/swap.1
/sbin/swapon /var/swap.1

### Compress Image Size
# Zero out the free space to save space in the final image
# (this may take a minute to run, at the end of the script, and may look like it's hanging; just be patient)
echo "Minimizing disk image ..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
sync
echo "Done."
