#!/bin/bash
#
# RHEL8 xTuple Installer
#
# DF Supply, Inc.
# 05/27/2021

# DO NOT USE IN PRODUCTION WITHOUT PRIOR TESTING
#
# Requires:
# RHEL 8.x
#
# Built for RHEL 8 by Scott D Moore @ DF Supply - scott@dfsupplyinc.com
# Parts of this script are based on the work of Perry Clark @ xTuple - pclark@xtuple.com
#
# Notes:
# This only installs repo versions of PostgreSQL
# PLV8 will be compiled during install

if [[ $(id -u) -ne 0 ]]
	then
		echo "Please run this script as root or sudo... Exit."
		exit 1
fi

if grep -q -i "Oracle Linux Server release 8" /etc/oracle-release; then
	echo "running Oracle Linux 8.x"
	OS_VER="ORCL8"
elif grep -q -i "Red Hat Enterprise Linux release 8" /etc/redhat-release; then
	echo "running RHEL 8.x"
	OS_VER="RHEL8"
elif grep -q -i "Rocky Linux release 8" /etc/redhat-release; then
	echo "running Rocky Linux 8.x"
	OS_VER="ROCKY8"
elif grep -q -i "CentOS Stream release 8" /etc/redhat-release; then
	echo "running CentOS Stream 8.x"
	OS_VER="COSTR8"
elif grep -q -i "Fedora release 34" /etc/redhat-release; then
	echo "running Fedora 34"
	OS_VER="FED34"
elif grep -q -i "AlmaLinux release 8" /etc/redhat-release; then
	echo "running AlmaLinux 8.x"
	OS_VER="ALMA8"
else
	echo "Unsupported OS. See README for tested distributions."
	OS_VER="UNSUP"
	exit 1
fi


# 10, 12, and 13 available in 8.4+
# 10 & 12 availabe in 8.3+
# support for PERCONA PG13 using "PERC13"
PG_VER="PERC13"
PG_PORT="5432"
XT_ROLE="xtrole"
XT_ADMIN="admin"
XT_ADMIN_PASS="admin"
XT_AUTHMETHOD="local" # Options: local or ldap. Will configure pg_hba for either. May need to change ip restrictions and ldap server location after setup.
POSTGRES_ACCTPASSWORD=$(cat /dev/urandom | tr -dc 'a-zA-Z0-9' | fold -w 18 | head -n 1)


echo "xTuple PostgreSQL Setup Script (for RHEL 8.x systems)"
echo "DF Supply, Inc."
echo ""
echo "PostgreSQL version $PG_VER on port $PG_PORT with $XT_AUTHMETHOD authentication"
echo "$XT_ADMIN / $XT_ADMIN_PASS / $XT_ROLE"

echo ""
echo "Please confirm you wish to proceed? (y/n)"
read -r
if [[ ! "$REPLY" =~ ^[Yy]$ ]]; then
	echo "Cancelling..."
	exit 1
fi

if [ "$PG_VER" == "PERC13" ]; then
	echo "Installing Percona Release Utility..."
	yum install https://repo.percona.com/yum/percona-release-latest.noarch.rpm -y || exit
	dnf module disable postgresql rust-toolset llvm-toolset -y || exit
	percona-release setup ppg-13 -y || exit
	
	echo "Installing Percona PG v13..."
	yum install percona-postgresql13-server -y || exit
	yum install percona-pg_repack13 percona-pgaudit percona-pgbackrest percona-patroni percona-pg-stat-monitor13 percona-pgbouncer percona-pgaudit13_set_user percona-wal2json13 percona-postgresql13-contrib -y || exit
	yum install postgresql-devel -y || exit

	echo "Initializing..."
	/usr/pgsql-13/bin/postgresql-13-setup initdb
	
	echo "Adding Percona PG location to PATH"
	export PATH="$PATH:/usr/pgsql-13/bin/"

	PG_DATA_PATH="/var/lib/pgsql/13/data/"
else
	echo "Switching PostgreSQL streams and installing..."
	yum update -y
	yum module reset postgresql -y
	yum module enable postgresql:${PG_VER} -y || exit
	yum install postgresql postgresql-server postgresql-devel postgresql-server-devel postgresql-contrib -y || exit
	
	echo "Initializing..."
	postgresql-setup initdb
	PG_DATA_PATH="/var/lib/pgsql/data/"
fi




echo "PLV8 compilation prereqs..."
if [ "$OS_VER" == "RHEL8" ]; then
	subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
elif [ "$OS_VER" == "ORCL8" ]; then
	dnf config-manager --set-enabled ol8_codeready_builder
elif [ "$OS_VER" == "COSTR8" ]; then		
	dnf config-manager --set-enabled powertools
elif [ "$OS_VER" == "ALMA8" ]; then		
	dnf config-manager --set-enabled powertools
elif [ "$OS_VER" == "ROCKY8" ]; then		
	dnf config-manager --set-enabled powertools
	dnf install https://dl.fedoraproject.org/pub/epel/epel-release-latest-8.noarch.rpm -y
	yum install snapd -y
	systemctl enable --now snapd.socket
	ln -s /var/lib/snapd/snap /snap
	sleep 5 # wait and make sure snap has come up
	yum remove cmake -y
	sleep 2
	hash -r cmake
	snap wait system seed.loaded
	snap install cmake --classic
	hash -r cmake
fi
yum update -y
yum install git python2 python3 gcc pkg-config ninja-build make ncurses-compat-libs redhat-rpm-config clang llvm-devel libatomic libstdc++ -y || exit
if [ "$OS_VER" != "ROCKY8" ]; then		
	yum install cmake -y || exit # install repo version of cmake on everything but rocky (its version is too old to build. Latest snap version installed prior.)
fi
# need python 2 for compilation
alternatives --set python /usr/bin/python2 || alternatives --install /usr/bin/python python /usr/bin/python2 1


echo "Compiling libcxx..."
git clone -b llvmorg-12.0.0 https://github.com/llvm/llvm-project.git llvm-project
cd llvm-project || exit
cd libcxx || exit
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ || exit
make || exit
cd ../../ || exit

echo "Compiling libcxxabi..."
cd libcxxabi || exit
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DLIBCXX_CXX_ABI=libstdc++ -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include || exit
make || exit
make install || exit
cd ../../ || exit

echo "Compiling libcxx again w/ libcxxabi..."
cd libcxx || exit
rm -Rf build
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include || exit
make || exit
make install || exit
cd ../../../ || exit

echo "Compiling PLV8..."
git clone -b v2.3.15 https://github.com/plv8/plv8.git plv8-2.3.15
cd plv8-2.3.15 || exit
make || exit
make install || exit
cd ../ || exit

echo "Linking to LD Library..."
echo "/usr/local/lib/" > /etc/ld.so.conf.d/plv8.conf || exit
ldconfig

echo "Overwriting the pg_hba.conf configuration..."

if [ "$XT_AUTHMETHOD" == "ldap" ]; then
	echo '
local   all             toby                               peer
local   all             all                                     trust
host    all             all             127.0.0.1/32            md5
host    all             all             ::1/128                 md5
host    all     admin   172.16.80.0/21  md5
host    all     all     172.16.233.0/24 ldap ldapserver=172.16.80.244 ldapprefix="NETWORK\"
host    all             all             172.16.80.0/21              ldap ldapserver=172.16.80.244 ldapprefix="NETWORK\"' > "${PG_DATA_PATH}pg_hba.conf"
else
	echo "
local      all             postgres                        trust
local      replication     all                             peer
host       replication     all             127.0.0.1/32    ident
host       replication     all             ::1/128         ident
host    all     admin   172.16.80.0/21  md5
host       all             postgres        0.0.0.0/0       reject
hostssl    all             postgres        0.0.0.0/0       reject
hostnossl  all             all             0.0.0.0/0       reject
hostssl    all             +xtrole         0.0.0.0/0       md5" > "${PG_DATA_PATH}pg_hba.conf"
fi


chpasswd <<< "postgres:$POSTGRES_ACCTPASSWORD"

if [ "$PG_VER" == "PERC13" ]; then
	systemctl enable postgresql-13
	service postgresql-13 start
else
	systemctl enable postgresql
	service postgresql start
fi

echo "Creating admin username/password..."
psql -At -U postgres -c "CREATE ROLE ${XT_ROLE} WITH NOLOGIN; CREATE ROLE ${XT_ADMIN} WITH PASSWORD '${XT_ADMIN_PASS}' SUPERUSER CREATEDB CREATEROLE LOGIN IN ROLE ${XT_ROLE};" 1> /dev/null 2> /dev/null

echo "Importing Extensions..."
psql -At -U postgres -c "CREATE EXTENSION IF NOT EXISTS \"uuid-ossp\"; CREATE EXTENSION IF NOT EXISTS \"plv8\";"

echo "Allowing through firewall..."
firewall-cmd --new-zone=xtuple-db --permanent
firewall-cmd --reload
firewall-cmd --zone=xtuple-db --add-source=172.16.80.1/21 --permanent
firewall-cmd --zone=xtuple-db --add-source=172.16.64.1/21 --permanent
if [ "$PG_PORT" != "5432" ]; then
	firewall-cmd --zone=xtuple-db --add-port="$PG_PORT/tcp" --permanent
else
	firewall-cmd --zone=xtuple-db --add-service=postgresql --permanent
fi

firewall-cmd --reload

echo "Listen on all ip addresses..."
echo  "
listen_addresses = '*'"  >> "${PG_DATA_PATH}postgresql.conf"

echo "Setting xTuple plv8 configuration in postgresql.conf..."
echo  "
max_locks_per_transaction = 256
plv8.start_proc='xt.js_init'"  >> "${PG_DATA_PATH}postgresql.conf"

echo "Binding postgresql to port configured..."
if [ "$PG_PORT" != "5432" ]; then
	echo "Configuring selinux to allow postgresql to bind to non-std port"
	semanage port -a -t postgresql_port_t "$PG_PORT" -p tcp
	echo "
port = $PG_PORT"  >> "${PG_DATA_PATH}postgresql.conf"
	
else
	echo "Default port. No configuration necessary..."
fi

if [ "$PG_VER" == "PERC13" ]; then
	service postgresql-13 restart
else
	service postgresql restart
fi

#finished. output the info....
echo ""
echo "Finished!"
echo ""
echo "PostgreSQL version $PG_VER on port $PG_PORT"
echo ""
echo "Local postgres account password: $POSTGRES_ACCTPASSWORD"