#!/usr/bin/env bash

# Install Zend Server
# (Trial Enterprise Edition is good for 30 days,
#  or Developer Mode can be enabled by obtaining a registered license key)
# Developers can use its debugging and profiling tools in conjunction with IDEs like PhpStorm, ZendStudio, Eclipse, etc.
# For more information, see: http://files.zend.com/help/Zend-Server/zend-server.htm
# To configure Zend Server after installed, visit this URL in your browser:
#     http://this_server_name:10081/ZendServer
#   ... or simply click the Zend Server icon which will appear in the bottom of the browser.
#
# NOTE: Zend Server currently resets PHP to PHP 5.5.13, as there is no PHP 5.6 version available yet for Zend Server

# set up dependencies
sudo printf "\ndeb http://repos.zend.com/zend-server/7.0/deb_apache2.4 server non-free\n" | sudo tee -a /etc/apt/sources.list
sudo printf "\ndeb http://repos.zend.com/zend-server/7.0/deb_ssl1.0 server non-free\n" | sudo tee -a /etc/apt/sources.list
wget http://repos.zend.com/zend.key -O- | sudo apt-key add -
sudo apt-get -y update

# Set php logs back to defaults (Habitat had redirected them to a shared folder for convenience)
sudo sed -i "s/;error_log = .*/error_log = php_errors.log/" /etc/php5/cli/php.ini
sudo sed -i "s/;error_log = .*/error_log = php_errors.log/" /etc/php5/apache2/php.ini

#apache version:
sudo apt-get -y remove nginx php5-fpm
sudo apt-get -y install zend-server-php-5.5

#nginx version:
#sudo apt-get -y remove apache2 php5
#sudo apt-get -y install zend-server-nginx-php-5.5

#reset some defaults in zendserver ... this may put the server in a "warning" state; simply "apply changes" and restart, using GUI.
sudo sed -i "s/memory_limit=.*/memory_limit = 512M/" /usr/local/zend/etc/php.ini #resource limits
sudo sed -i "s/post_max_size=.*/post_max_size = 512M/" /usr/local/zend/etc/php.ini #data-handling
sudo sed -i "s/upload_max_filesize=.*/upload_max_filesize = 512M/" /usr/local/zend/etc/php.ini #fs/streams

# Clean up
echo "Removing unneeded packages ..."
sudo apt-get -y autoremove
sudo apt-get -y clean
# Clear unused space from the VM
# (this may take a minute to run, at the end of the script, and may look like it's hanging; just be patient)
echo "Clearing empty space ... (this may take 1-2 minutes) ..."
sudo dd if=/dev/zero of=/EMPTY bs=1M
sudo rm -f /EMPTY
echo "Done."
