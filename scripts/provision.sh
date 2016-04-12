#!/usr/bin/env bash
export DEBIAN_FRONTEND=noninteractive

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
apt-get install -y language-pack-en

echo "LC_ALL=en_US.UTF-8" >> /etc/default/locale
locale-gen en_US.UTF-8

# Install Some PPAs

apt-get install -y software-properties-common curl

#Ubuntu Precise 12.04 includes PHP 5.3.10 by default
#Ubuntu Trusty 14.04 installs PHP 5.5.9 by default

apt-add-repository ppa:ondrej/php -y

#PHP 7.0
apt-add-repository ppa:ondrej/php70 -y
#PHP 5.6
#apt-add-repository ppa:ondrej/php5-5.6 -y
#PHP 5.5
#apt-add-repository ppa:ondrej/php5 -y
#PHP 5.4:
#apt-add-repository ppa:ondrej/php5-oldstable -y

#MySQL versions
#apt-add-repository ppa:ondrej/mysql-5.6 -y
#apt-add-repository ppa:ondrej/mysql-5.7 -y
#apt-add-repository ppa:ondrej/mariadb-5.5 -y

# gpg: key 5072E1F5: public key "MySQL Release Engineering <mysql-build@oss.oracle.com>" imported
apt-key adv --keyserver ha.pool.sks-keyservers.net --recv-keys 5072E1F5
sh -c 'echo "deb http://repo.mysql.com/apt/ubuntu/ trusty mysql-5.7" >> /etc/apt/sources.list.d/mysql.list'


# Update Package Lists

apt-get update

# Install Some Basic Packages

apt-get install -y build-essential dos2unix gcc git libpcre3-dev \
make python2.7-dev python-pip re2c supervisor unattended-upgrades whois vim libnotify-bin \
libmcrypt4 \
tig nfs-common ntp

# Set My Timezone

ln -sf /usr/share/zoneinfo/UTC /etc/localtime

# Write Bash Aliases

cp /vagrant/aliases /home/vagrant/.bash_aliases

# Install PHP 7
apt-get install -y --force-yes php7.0-cli php7.0-dev \
php-sqlite3 php-gd php-apcu \
php-curl php7.0-mcrypt \
php-imap php-mysql php-memcached php7.0-readline php-xdebug \
php-mbstring php-xml php7.0-zip php7.0-intl php7.0-bcmath

sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/cli/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/cli/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/cli/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/cli/php.ini


# Install Composer

curl -sS https://getcomposer.org/installer | php
mv composer.phar /usr/local/bin/composer
crontab -e * 12 * * * /usr/local/bin/composer self-update >/dev/null 2>&1

# Add Composer Global Bin To Path

printf "\nPATH=\"$(composer config -g home 2>/dev/null)/vendor/bin:\$PATH\"\n" | tee -a /home/vagrant/.profile


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
#wget http://selenium-release.storage.googleapis.com/2.53/selenium-server-standalone-2.53.0.jar
#mv selenium-server-standalone-2.53.0.jar selenium-server-standalone.jar
#chmod a+x selenium-server-standalone.jar
cd ~
ssh-keyscan github.com >> ~/.ssh/known_hosts
ssh-keyscan bitbucket.org >> ~/.ssh/known_hosts
EOF


# sync error logs
#sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php7.0/cli/php.ini

# Add Vagrant User To WWW-Data

usermod -a -G www-data vagrant
id vagrant
groups vagrant

# Install Apache
apt-get install -y apache2 libapache2-mod-php7.0 apache2-utils
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
sudo sed -i "s/error_reporting = .*/error_reporting = E_ALL/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/display_errors = .*/display_errors = On/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/memory_limit = .*/memory_limit = 512M/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/;date.timezone.*/date.timezone = UTC/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/post_max_size = .*/post_max_size = 512M/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/upload_max_filesize = .*/upload_max_filesize = 512M/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/html_errors = .*/html_errors = Off/" /etc/php/7.0/apache2/php.ini
sudo sed -i "s/;error_log = php_errors.log/error_log = \/home\/vagrant\/habitat\/php_errors.log/" /etc/php/7.0/apache2/php.ini

# Install SQLite

apt-get install -y sqlite3 libsqlite3-dev

# Install MySQL

debconf-set-selections <<< "mysql-community-server mysql-community-server/data-dir select ''"
debconf-set-selections <<< "mysql-community-server mysql-community-server/root-pass password zencart"
debconf-set-selections <<< "mysql-community-server mysql-community-server/re-root-pass password zencart"
apt-get install -y mysql-server

# Add Timezone Support To MySQL

echo "Adding timezone support to MySQL ..."
mysql_tzinfo_to_sql /usr/share/zoneinfo | mysql --user=root --password=zencart mysql

# Configure MySQL Password Lifetime

echo "default_password_lifetime = 0" >> /etc/mysql/my.cnf

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
apt-add-repository ppa:nijel/phpmyadmin -y
apt-get -y install phpmyadmin libapache2-mod-php7.0
sudo sed -i "s/$cfg\['UploadDir'] = .*;/$cfg['UploadDir'] = '\/var\/lib\/phpmyadmin\/tmp';/" /etc/phpmyadmin/config.inc.php
sudo sed -i "s/$cfg\['SaveDir'] = .*;/$cfg['SaveDir'] = '\/var\/lib\/phpmyadmin\/tmp';/" /etc/phpmyadmin/config.inc.php
#ln -s /usr/share/phpmyadmin /usr/share/nginx/html


# Add Zend Server installer script, for developer optimization benefits (can be installed manually if developers desire)
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

# removed because the vagrant-cachier plugin takes care of it:
#apt-get -y clean

# Enable Swap Memory

# /bin/dd if=/dev/zero of=/var/swap.1 bs=1M count=256
# /sbin/mkswap /var/swap.1
# /sbin/swapon /var/swap.1

### Compress Image Size
# Zero out the free space to save space in the final image
# (this may take a minute to run, at the end of the script, and may look like it's hanging; just be patient)
echo "Minimizing disk image ..."
dd if=/dev/zero of=/EMPTY bs=1M
rm -f /EMPTY
sync
echo "Done."
