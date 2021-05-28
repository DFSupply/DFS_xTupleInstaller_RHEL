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
PG_VER="13"
PG_PORT="5434"
XT_ROLE="xtrole"
XT_ADMIN="admin"
XT_ADMIN_PASS="admin"

echo "xTuple PostgreSQL Setup Script (for RHEL 8.x systems)"
echo "DF Supply, Inc."
echo ""
echo "PostgreSQL version $PG_VER on port $PG_PORT"
echo "$XT_ADMIN / $XT_ADMIN_PASS / $XT_ROLE"

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
yum install git python2 python3 gcc pkg-config ninja-build make ncurses-compat-libs redhat-rpm-config clang cmake llvm-devel libatomic libstdc++ -y
# need python 2 for compilation
alternatives --set python /usr/bin/python2


echo "Compiling libcxx"
git clone -b llvmorg-12.0.0 https://github.com/llvm/llvm-project.git llvm-project
cd llvm-project || exit
cd libcxx || exit
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++
make
cd ../../ || exit

echo "Compiling libcxxabi"
cd libcxxabi || exit
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DLIBCXX_CXX_ABI=libstdc++ -DLIBCXXABI_LIBCXX_INCLUDES=../../libcxx/include
make
make install
cd ../../ || exit

echo "Compiling libcxx again w/ libcxxabi"
cd libcxx || exit
rm -Rf build
mkdir build && cd build || exit
cmake ../ -DCMAKE_BUILD_TYPE=Release -DCMAKE_C_COMPILER=gcc -DCMAKE_CXX_COMPILER=g++ -DLIBCXX_CXX_ABI=libcxxabi -DLIBCXX_CXX_ABI_INCLUDE_PATHS=../../libcxxabi/include
make
make install
cd ../../../ || exit

echo "Compiling PLV8"
git clone -b v2.3.15 https://github.com/plv8/plv8.git plv8-2.3.15
cd plv8-2.3.15 || exit
make
make install
cd ../ || exit