
--===========================================
-- Alter PGA TARGET
--===========================================

ALTER SYSTEM SET PGA_AGGREGATE_TARGET = 10240M SCOPE=BOTH;


--===========================================
-- Parametros de memory configurados
--===========================================
set pagesize 999
set long 9999999999999
column name  format a40
column value format 999,999,999,999,999

select inst_id
      ,name
      ,value
      ,unit
from gv$pgastat
order by inst_id,name;





--===========================================
-- Query to find sessions using PGA 
--===========================================

col event for a25 word_wrap trunc;
col machine for a20;
col oracle_user for a25 word_wrap trunc ;
col wait_class for a20;
col module for a25;
col os_pid for a10;
col sid_serial for a15;
SELECT
    p.spid                                          AS os_pid,
    s.sid ||','||s.serial#                               AS sid_serial,
    s.username                                      AS oracle_user,
    s.status,
    s.wait_class,
    s.event,
    ROUND(p.pga_used_mem      / 1048576, 1)        AS pga_used_mb,
    ROUND(p.pga_alloc_mem     / 1048576, 1)        AS pga_alloc_mb,
    ROUND(p.pga_freeable_mem  / 1048576, 1)        AS pga_free_mb,
    ROUND(p.pga_max_mem       / 1048576, 1)        AS pga_max_mb,
    s.sql_id,
    s.module,
    s.machine
FROM
    v$process p
    JOIN v$session s ON s.paddr = p.addr
WHERE
    s.type = 'USER'
    AND p.pga_alloc_mem > 52428800          -- processes holding more than 50 MB
ORDER BY
    p.pga_alloc_mem DESC;


  ---- 


  set linesize 9999
set pagesize 9999

col TYPE format a25
col MB format 999,999
col event format a50
col SESS format A15
col logon_time for a25

select  ss.sid||','||ss.serial# as SESS,
        ss.username,
        ss.status,
        ss.machine,
        ss.sql_id,
        ss.event,
        ss.logon_time,
        sn.name "TYPE",
        ceil(st.value / 1024 / 1024) "MB"
  from  v$sesstat st,
        v$statname sn,
        v$session ss
 where  st.statistic# = sn.statistic#
   and  st.sid = ss.sid
   and  upper(sn.name) like '%PGA%'
   and ceil(st.value / 1024 / 1024) > 100
 order by ceil(st.value / 1024 / 1024) desc, st.sid, st.value desc;






-- Finding a runaway process: locate session by OS PID and get its trace file
-- Replace &os_pid with the PID reported by top/ps on Linux
SELECT
    p.spid                                          AS os_pid,
    p.pid                                           AS oracle_pid,
    s.sid,
    s.serial#,
    s.username,
    s.status,
    s.seconds_in_wait,
    s.event,
    s.wait_class,
    s.sql_id,
    s.module,
    s.action,
    s.machine,
    p.tracefile,
    ROUND(p.pga_alloc_mem / 1048576, 1)            AS pga_alloc_mb
FROM
    v$process p
    LEFT JOIN v$session s ON s.paddr = p.addr
WHERE
    p.spid = '&os_pid';



  
  -- Summary of total PGA usage across all processes

-- all
SELECT
    ROUND(SUM(p.pga_used_mem)     / 1048576, 1)    AS total_pga_used_mb,
    ROUND(SUM(p.pga_alloc_mem)    / 1048576, 1)    AS total_pga_alloc_mb,
    ROUND(SUM(p.pga_freeable_mem) / 1048576, 1)    AS total_pga_freeable_mb,
    ROUND(SUM(p.pga_max_mem)      / 1048576, 1)    AS total_pga_peak_mb,
    COUNT(CASE WHEN p.background IS NULL  THEN 1 END) AS foreground_procs,
    COUNT(CASE WHEN p.background = '1'    THEN 1 END) AS background_procs,
    COUNT(*)                                        AS total_procs
FROM
    gv$process p;

-- for instance
    SELECT
    ROUND(SUM(p.pga_used_mem)     / 1048576, 1)    AS total_pga_used_mb,
    ROUND(SUM(p.pga_alloc_mem)    / 1048576, 1)    AS total_pga_alloc_mb,
    ROUND(SUM(p.pga_freeable_mem) / 1048576, 1)    AS total_pga_freeable_mb,
    ROUND(SUM(p.pga_max_mem)      / 1048576, 1)    AS total_pga_peak_mb,
    COUNT(CASE WHEN p.background IS NULL  THEN 1 END) AS foreground_procs,
    COUNT(CASE WHEN p.background = '1'    THEN 1 END) AS background_procs,
    COUNT(*)                                        AS total_procs
FROM
    v$process p;

-- whit subs to many instances
    SELECT
    ROUND(SUM(p.pga_used_mem)     / 1048576, 1)    AS total_pga_used_mb,
    ROUND(SUM(p.pga_alloc_mem)    / 1048576, 1)    AS total_pga_alloc_mb,
    ROUND(SUM(p.pga_freeable_mem) / 1048576, 1)    AS total_pga_freeable_mb,
    ROUND(SUM(p.pga_max_mem)      / 1048576, 1)    AS total_pga_peak_mb,
    COUNT(CASE WHEN p.background IS NULL  THEN 1 END) AS foreground_procs,
    COUNT(CASE WHEN p.background = '1'    THEN 1 END) AS background_procs,
    COUNT(*)                                        AS total_procs
FROM
    gv$process p
    where p.inst_id = &1;