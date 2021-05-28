# DFS_xTupleInstaller_RHEL8
Installs the PostgreSQL requirements to support xTuple on RHEL 8

Requirements:
- Red Hat Enterprise Linux 8.x
- Root or Sudo permissions

Will Compile/Install:
- PostgreSQL 10/12/13
- plv8 2.3.15

Configure the following variables in install.sh prior to running:
- PG_VER
- PG_PORT
- XT_ROLE
- XT_ADMIN
- XT_ADMIN_PASS

execute by running:
```
cd /root/
git clone https://github.com/DFSupply/DFS_xTupleInstaller_RHEL8.git
cd DFS_xTupleInstaller_RHEL8
chmod +x install.sh
./install.sh
```

PostgreSQL will be running on the port you requested
You will need to import the plv8 extension that was created.
```
psql -U postgres
=# CREATE EXTENSION plv8;
=# SELECT plv8_version();
exit;
```