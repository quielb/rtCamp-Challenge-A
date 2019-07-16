#!/bin/bash
#set -x
### Script to install PHP MySQL and Nginx packages
### Install and configure a WordPress instance using Nginx

APT="apt-get"
PKGS="nginx-full mysql-server php php-fpm php-mysql"
WP_INSTALL_DIR="/var/www/wordpress"
DATABASE_NAME="example_com_db"
WP_USER_NAME="wordpress"
WP_USER_PASS="SomeSecurePassword"

# variables to track a few installed things for potential cleanup on abort
PKG_INSTALLED=""
domainAdded=0

abortCleanup () {
        [[ ${domainAdded} ]] && sed -i "s/\(127.0.0.1\|::1\).*${DOMAIN}//g" /etc/hosts
        [[ -f /tmp/wordpress-$$-latest.tar.gz ]] && rm -f /tmp/wordpress-$$-latest.tar.gz
        [[ -f /tmp/wordpress-$$-latest.tar.gz.md5 ]] && rm -f /tmp/wordpress-$$-latest.tar.gz.md5
        [[ -d ${WP_INSTALL_DIR} ]] && rm -rf ${WP_INSTALL_DIR}
        if ! [[ ${PKG_INSTALLED} = '' ]]; then
                ${APT} -y remove ${PKG_INSTALLED}
                # remove any installed dependencies
                ${APT} -y autoremove
        fi
}

successCleanup() {
        [[ -f /tmp/wordpress-$$-latest.tar.gz ]] && rm -f /tmp/wordpress-$$-latest.tar.gz
        [[ -f /tmp/wordpress-$$-latest.tar.gz.md5 ]] && rm -f /tmp/wordpress-$$-latest.tar.gz.md5
	[[ -d /tmp/wordpress ]] && rm -rf /tmp/wordpress
}

echo "This script will install and configure components necessary"
echo "for a functional WordPress site.  After the install is complete"
echo "a URL will be provided to the new site"

# Check if WordPress is already installed abort if true.
if [[ -d ${WP_INSTALL_DIR} ]]; then
        echo "Wordpress is already installed in ${WP_INSTALL_DIR}"
        echo "This should be a clean host."
        echo "Clean up and abort"
        exit 1
fi

# setup /etc/hosts with domain of site pointing to localhost
# Abort if exists.  May conflict with existing config
# Do this first, it is the least breaking change
echo "Please enter domain name of site:"
read DOMAIN
if [[ $(egrep "^(127.0.0.1|::1)\s${DOMAIN}" /etc/hosts) =~ (127.0.0.1|::1).*${DOMAIN} ]]; then
        echo "Domain already exists in the host file."
        echo "This install may conflict with existing applications and configuration.  Aborting installation"
        exit 1
else
        echo -e "127.0.0.1\t${DOMAIN}" >> /etc/hosts
        echo -e "::1\t${DOMAIN}" >> /etc/hosts
        domainAdded=1
fi

# Download WordPress latest and MD5 sum.  Exit on failure
wget --quiet -O /tmp/wordpress-$$-latest.tar.gz http://wordpress.org/latest.tar.gz 
wget --quiet -O /tmp/wordpress-$$-latest.tar.gz.md5 http://wordpress.org/latest.tar.gz.md5
if ! [[ -f /tmp/wordpress-$$-latest.tar.gz ]] || ! [[ /tmp/wordpress-$$-latest.tar.gz.md5 ]]; then
        echo "Unable to download latest WordPress components."
        echo "Clean up and abort"
        exit 1
fi
# Check MD5.  Exit if they don't match
if ! [[ $(md5sum /tmp/wordpress-$$-latest.tar.gz) =~ $(cat /tmp/wordpress-$$-latest.tar.gz.md5) ]]; then
        echo "MD5 sum of WordPress download does not match expected."
        echo "Cleanup and abort"
        abortCleanup
        exit 1
fi

# Install packages
# check to see if packages are existing.  If they are then error out.  This should be a clean host.
for pkg in $PKGS
do
        echo "Installing ${pkg} package via ${APT}"
        if ! [[ $(apt -qq list ${pkg} 2>/dev/null) =~ 'installed' ]]; then
                RESULT=$(${APT} install -y ${pkg})
                if [[ $? -ne 0 ]]; then
                        echo "Error installing package.  Output of install log, cleanup, and abort"
                        echo ${RESULT}
                        abortCleanup
                        exit 1
                else
                        PKG_INSTALLED+=" ${pkg}"
                fi
        else
                echo "Package ${pkg} is already installed. Clean up changes and abort"
                abortCleanup
                exit 1
        fi
done

# Install and configure wordpress
echo "Installing WordPress"
cd /tmp
tar xvfz /tmp/wordpress-$$-latest.tar.gz > /dev/null
mkdir -p ${WP_INSTALL_DIR}
mv /tmp/wordpress/* ${WP_INSTALL_DIR}
echo "Configuring WordPress"
cp ${WP_INSTALL_DIR}/wp-config-sample.php ${WP_INSTALL_DIR}/wp-config.php
sed -i "s/database_name_here/${DATABASE_NAME}/" ${WP_INSTALL_DIR}/wp-config.php
sed -i "s/username_here/${WP_USER_NAME}/" ${WP_INSTALL_DIR}/wp-config.php
sed -i "s/password_here/${WP_USER_PASS}/" ${WP_INSTALL_DIR}/wp-config.php

# Configure MySQL
echo "Configuring MySQL"
RESULT=$(echo "CREATE DATABASE ${DATABASE_NAME}" | mysql -u root 2>&1)
if [[ ${RESULT} =~ 'ERROR' ]]; then
        echo "There was an error during MySQL configuration:"
        echo ${RESULT}
        echo "Clean up and abort"
        abortCleanup
        exit 1
fi
RESULT=$(echo -e "GRANT ALL ON ${DATABASE_NAME}.* TO '${WP_USER_NAME}'@'localhost' IDENTIFIED BY '${WP_USER_PASS}';" | \
        mysql -u root 2>&1)
if [[ ${RESULT} =~ 'ERROR' ]]; then
        echo "There was an error during MySQL configuration:"
        echo ${RESULT}
        echo "Clean up and abort"
        abortCleanup
        exit 1
fi

# Configure nginX
echo "Configuring nginX"
rm -f /etc/nginx/sites-enabled/default
cat > /etc/nginx/sites-available/wordpress.conf <<EOF
server {
    listen 80;
    listen [::]:80;

    server_name ${DOMAIN};

    root   ${WP_INSTALL_DIR};
    index  index.html index.php;

    location / {
        try_files \$uri \$uri/ =404;
    }
    location ~ \.php$ {
            include snippets/fastcgi-php.conf;
            include fastcgi_params;
            fastcgi_pass unix:/var/run/php/php7.2-fpm.sock;
            fastcgi_param SCRIPT_FILENAME /var/www/wordpress/\$fastcgi_script_name;
    }
}
EOF
ln -s /etc/nginx/sites-available/wordpress.conf /etc/nginx/sites-enabled/wordpress.conf
systemctl reload nginx

echo "Install Completed successfully"
echo "Open http://${DOMAIN} to begin using your new wordpress site."
successCleanup
exit 0

