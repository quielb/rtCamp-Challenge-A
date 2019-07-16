# rtCamp Challenge A

## Assumptions
* This should be a clean host.  Any conflicts with existing packages/configuration is considered a fatal error.  Changes are rolled back.
* Host only runs one site.  nginX config files named for application not domain.
* Latest packages are used from the repo.
* Coding style and standards are unknown.
* Install path standards for non-packaged applications is unknown. /var/www/wordpress was used.  But can be configured in the script.
* Unknown standard for php processing for nginX.  php-fpm (currently 7.2) was used.
* Unknown security standards.  Suggest implementing the following:


  i.   mysql_secure_installation
  ii.  SSL cert for nginX
  iii. WordPress "Authentication Unique Keys and Salts"
* MySQL database name changed to example_com_db from example.com_db.  Use of dots in names is highly discouraged.

## Libraries
Since the state of the host is unknown, the most commonly available tools are used in an effort to minimize dependencies.
* apt (Not script friendly only used for install status of packages.  Could of used dpkg)
* apt-get
* sed
* grep
* echo
* tar
* rm
* cat

## Instructions
 Since this script is stand-alone, simply clone/pull the repo, confirm execute permissions, and run as root.

 This script does have a few configuration options, but the defaults should be acceptable.
 ```
 # Pakcages to install
PKGS="nginx-full mysql-server php php-fpm php-mysql"
# Location of WordPress install
WP_INSTALL_DIR="/var/www/wordpress"
# Name of the MySQL database
DATABASE_NAME="example_com_db"
# Database user name
WP_USER_NAME="wordpress"
# Database user password
WP_USER_PASS="SomeSecurePassword"
```
