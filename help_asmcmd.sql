--==============================================================
1. Listing ASM Diskgroups
--==============================================================
ASMCMD> lsdg

Sample output:

State    Type  Rebal  Sector  Block  AU   Total_MB  Free_MB  Name
MOUNTED  EXTERN N     512     4096   1M   102400    51200    DATA/
MOUNTED  NORMAL N     512     4096   4M   204800    153600   FRA/

👉 If you want to include dismounted diskgroups:

ASMCMD> lsdg --discovery

Or list across all cluster nodes:

ASMCMD> lsdg -g --discovery


--==============================================================
2. Exploring ASM Disks
--==============================================================

Disks are the backbone of diskgroups. To see all available disks:Data Backup & Recovery

ASMCMD> lsdsk -k

Path             Size_MB  Free_MB  Name   Failgroup  Label  UDID
/dev/asm-disk1   51200    25600    DATA_0001  DATA_0001  -   -
/dev/asm-disk2   51200    25600    DATA_0002  DATA_0002  -   -
For a specific diskgroup (CDATA)

ASMCMD> lsdsk -k -G CDATA
Output:

Path             Size_MB  Free_MB  Name       Failgroup
/dev/asm-cdata1  102400   40960    CDATA_0001 CDATA_0001
/dev/asm-cdata2  102400   40960    CDATA_0002 CDATA_0002

--==============================================================
3. Checking ASM Diskgroup Attributes
--==============================================================
Diskgroups come with attributes like allocation unit size and access control.

ASMCMD> lsattr -lm
Output:

Group_Name  Name                     Value      RO  Sys
DATA        au_size                  1048576    Y   Y
DATA        cell.smart_scan_capable  FALSE      N   N
FRA         au_size                  4194304    Y   Y
FRA         compatible.rdbms         11.2.0.0.0 N   N

For a specific diskgroup (DMARCH):

ASMCMD> lsattr -lm -G DMARCH

--==============================================================
4. Mounting and Unmounting Diskgroups
--==============================================================

Unmount all diskgroups:
ASMCMD> umount -a


Unmount specific:
ASMCMD> umount ARCH


Mount all:
ASMCMD> mount -a


Mount one:
ASMCMD> mount ARCH

Remember: These work only on the local node. In RAC, you need to repeat on all nodes.


--==============================================================
5. Rebalancing a Diskgroup
--==============================================================
When disks are added/removed, ASM rebalances automatically. But you can trigger it manually:

ASMCMD> rebal --power 8 ARCH


Check progress:
ASMCMD> lsop

Output:

Group_Name  Pass       State   Power  EST_WORK  EST_RATE  EST_TIME
ARCH        COMPACT    RUN     8      1000      20000     2


--==============================================================
6. Password File Management
--==============================================================

Find the password file for a database:Data Management

ASMCMD> pwget --dbuniquename DBACLASS
Output:

+DATA/DBACLASS/PASSWORD/pwddbaclass.256.899912377

For ASM password file:

ASMCMD> pwget --asm


--==============================================================
7. ASM Templates
--==============================================================
Templates define redundancy and striping for file types.

ASMCMD> lstmpl -l -G ARCH
Output:

Group_Name  Name            Stripe   Redund  Sys
ARCH        ARCHIVELOG      COARSE   UNPROT  Y
ARCH        BACKUPSET       COARSE   UNPROT  Y
ARCH        CONTROLFILE     FINE     MIRROR  Y

--==============================================================
8. Cluster and Version Info
--==============================================================

Check if Flex ASM is enabled:
ASMCMD> showclustermode
ASM cluster : Flex mode disabled


Check cluster state:
ASMCMD> showclusterstate
Normal


Check version:
ASMCMD> showversion
ASM version : 19.0.0.0.0


--==============================================================
10. Monitoring Clients
--==============================================================
See which databases are connected to a diskgroup:

ASMCMD> lsct DMARCH
Output:

DB_Name   Status     Software_Version  Instance_Name  Disk_Group
DBACLASS  CONNECTED  19.0.0.0.0        DBACLASS1      DMARCH

--==============================================================
11. Other Useful Commands
--==============================================================

ASM Diskstring:
ASMCMD> dsget

parameter: ORCL:*
profile:   ORCL:*


List ASM users:Data Management
ASMCMD> lspwusr

Username  sysdba  sysoper  sysasm
SYS       TRUE    TRUE     TRUE
ASMSNMP   TRUE    FALSE    FALSE


Open files for a diskgroup:
ASMCMD> lsof -G ARCH


Open files for a database:
ASMCMD> lsof --dbname DBACLASS


Filter driver state:
ASMCMD> afd_state

ASMCMD-9526: The AFD state is 'NOT INSTALLED' and filtering is 'DEFAULT'

List filter driver disks:
ASMCMD> afd_lsdsk