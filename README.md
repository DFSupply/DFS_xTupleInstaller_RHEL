# DFS_xTupleInstaller_RHEL
Installs the PostgreSQL requirements to support xTuple database on RHEL 8/9

Requirements:
- RHEL 8.x based server
  - Red Hat Enterprise Linux 8.x
  - CentOS Stream 8.x
  - Rocky Linux 8.3RC1+
  - Fedora 34
  - Oracle Linux 8.x
  - AlmaLinux 8.x
- RHEL 9.x based server
  - Red Hat Enterprise Linux 9.x
- Root or Sudo permissions

Will Compile/Install:
- PostgreSQL
  - Official Release 10/12/13 (based on configuration PG_VER)
  - Percona PostgreSQL 13 (PERC13) [only tested on Red Hat Enterprise Linux 8.x & 9.x]
- plv8 2.3.15

Configure the following variables in install.sh prior to running:
- PG_VER (tested with 10/12/13/PERC13)
- PG_PORT
- XT_ROLE
- XT_ADMIN
- XT_ADMIN_PASS
- XT_AUTHMETHOD (local/ldap) - configures auth methods in pg_hba for either method. Further configuration may be required.

execute by running:
```
cd /root/
git clone https://github.com/DFSupply/DFS_xTupleInstaller_RHEL8.git
cd DFS_xTupleInstaller_RHEL8
chmod +x install.sh
./install.sh
```

PostgreSQL will be running on the port you requested.  
plv8 and uuid-ossp extensions will be automatically imported.  

Recommend configuring postgresql.conf using https://pgtune.leopard.in.ua/  
located at /var/lib/pgsql/data/postgresql.conf  
Sample file provided (that we utilize internally): postgresql.conf