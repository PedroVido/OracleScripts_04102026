-- Switch log file on RDS instance

BEGIN
    rdsadmin.rdsadmin_util.switch_logfile;
END;
/