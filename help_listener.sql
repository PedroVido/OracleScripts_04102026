--======================================================
--Troubleshooting Common Issues - Connection Problems
--======================================================

--# TNS resolution issues
tnsping MYDB
nslookup server1.company.com
telnet server1 1521

--# Listener issues
lsnrctl status
lsnrctl services
ps -ef | grep tnslsnr

--# Firewall/network issues
telnet server1 1521
netstat -an | grep 1521
iptables -L | grep 1521


--======================================================
-- Error Diagnosis
--======================================================

--# Common TNS errors and solutions

--# TNS-12541: TNS:no listener
--# - Check if listener is running
--# - Verify hostname/port in tnsnames.ora
lsnrctl status
lsnrctl start

--# TNS-12154: TNS:could not resolve the connect identifier
--# - Check tnsnames.ora syntax
--# - Verify ORACLE_HOME/network/admin path
tnsping MYDB

--# ORA-12519: TNS:no appropriate service handler found
--# - Check processes/sessions limits
--# - Verify service registration
SQL> SHOW PARAMETER processes;
SQL> ALTER SYSTEM SET processes=300 SCOPE=SPFILE;

--# ORA-12514: TNS:listener does not currently know of service
--# - Check service registration
--# - Verify database is open
lsnrctl services
SQL> SELECT name, open_mode FROM v$database;

--======================================================
--Performance Issues
--======================================================


--# Network latency testing
time tnsping MYDB

--# Connection time analysis
time sqlplus system/password@MYDB <<< "exit"

--# Trace network issues
--# Set in sqlnet.ora:
TRACE_LEVEL_CLIENT = 16
TRACE_DIRECTORY_CLIENT = /tmp

--# Analyze trace files
grep -i error /tmp/client*.trc
grep -i "elapsed time" /tmp/client*.trc