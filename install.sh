#!/bin/bash

# Requires:
# Red Hat Enterprise Linux 8.x
# A working internet connection.
# If behind a firewall, open up ports 22,5434

# Questions/Errors? Contact Perry Clark - pclark@xtuple.com - 757-461-3022 x107
# Modified for RHEL 8 by Scott D Moore @ DF Supply - scott@dfsupplyinc.com

# Notes:
# This only installs official Red Hat repo versions of PostgreSQL
# PLV8 will be compiled during install

if [[ $(id -u) -ne 0 ]]
	then
		echo "Please run this script as root or sudo... Exit.";
		exit 1;
fi

if grep -q -i "Red Hat Enterprise Linux release 8" /etc/redhat-release
	then
		echo "running RHEL 8.x";
	else
		echo "Only Red Hat 8.x supported at this time.";
		exit 1;
fi


# 10, 12, and 13 available in official REPO as of 5/27/2021
PG_VER=13
PG_PORT=5434
XT_ROLE=xtrole
XT_ADMIN=admin
XT_ADMIN_PASS=admin

echo "Switch PostgreSQL streams and install"
yum update -y
yum module reset postgresql -y
yum module enable postgresql:${PG_VER} -y
yum install postgresql postgresql-server postgresql-devel postgresql-server-devel -y

echo "Initializing..."
postgresql-setup initdb


echo "PLV8 compilation prereqs"
subscription-manager repos --enable=codeready-builder-for-rhel-8-x86_64-rpms
yum update -y
yum install git python2 python3 gcc pkg-config ninja-build make ncurses-compat-libs redhat-rpm-config clang cmake llvm-devel -y
# need python 2 for compilation
alternatives --set python /usr/bin/python2

echo "Compiling libc++abi"
git clone https://github.com/llvm/llvm-project.git llvm-project
cd llvm-project
mkdir build && cd build
cmake -DLLVM_ENABLE_PROJECTS=libcxxabi ../llvm  -DCMAKE_C_COMPILER=clang -DCMAKE_CXX_COMPILER=clang++
make

echo "Compiling PLV8"
wget https://github.com/plv8/plv8/archive/v2.3.15.tar.gz
tar -xzvf v2.3.15.tar.gz
cd plv8-2.3.15
make