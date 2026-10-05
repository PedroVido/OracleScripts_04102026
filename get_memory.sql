set markup html on spool on entmap off -
head "<title>Oracle Memory Report</title>
<style>
body {
  font-family: Segoe UI, Arial, sans-serif;
  background-color: #f4f6f8;
  color: #333;
  margin: 20px;
}

h1 {
  background: linear-gradient(to right, #4a90e2, #6fb1fc);
  color: white;
  padding: 12px;
  border-radius: 6px;
}

h2 {
  color: #4a90e2;
  border-bottom: 2px solid #4a90e2;
  padding-bottom: 4px;
  margin-top: 30px;
}

table {
  border-collapse: collapse;
  width: 100%;
  margin-top: 10px;
  margin-bottom: 25px;
}

th {
  background-color: #4a90e2;
  color: white;
  padding: 8px;
  border: 1px solid #ddd;
}

td {
  border: 1px solid #ddd;
  padding: 6px;
}

tr:nth-child(even) {
  background-color: #f2f2f2;
}

hr {
  border: none;
  border-top: 1px solid #ccc;
  margin: 25px 0;
}
</style>"

set echo off
set feedback off
set verify off
set trimspool on
set pagesize 50000
set linesize 200

-- CRÍTICO: HTML correto
set markup html on spool on entmap off preformat off

spool memory_report.html

alter session set nls_date_format='dd/mm/yyyy hh24:mi:ss';

-- HEADER
prompt <h1>Oracle Memory Report - &&_DATE</h1>

--------------------------------------------------
prompt <h2>MEMORY OS</h2>

SELECT * FROM (
select INST_ID,STAT_NAME NAME,TRUNC(VALUE/1024/1024/1024) || ' GB' VALUE 
from gv$osstat where stat_name IN ('PHYSICAL_MEMORY_BYTES')
UNION 
select inst_id, upper(name) NAME, value
from gv$parameter where upper(name) in ('LOCK_SGA'))
order by 1,2 desc;

--------------------------------------------------
prompt <h2>AUTOMATIC MEMORY MANAGEMENT CONFIG</h2>

select inst_id, upper(name) NAME, value
from gv$parameter 
where upper(name) in ('MEMORY_TARGET','MEMORY_MAX_TARGET') 
order by name;

--------------------------------------------------
prompt <h2>AUTOMATIC MEMORY MANAGEMENT DYNAMIC COMPONENTS</h2>

SELECT inst_id, component, oper_count, last_oper_type, last_oper_time,
ROUND(current_size/1024/1024) AS current_size_mb,
ROUND(min_size/1024/1024) AS min_size_mb,
ROUND(max_size/1024/1024) AS max_size_mb
FROM gv$memory_dynamic_components
WHERE current_size != 0
ORDER BY inst_id,component;

--------------------------------------------------
prompt <h2>SGA TARGET ADVICE</h2>

select * from v$sga_target_advice order by sga_size;

--------------------------------------------------
prompt <h2>PGA MEMORY CONFIG</h2>

select inst_id, upper(name) NAME, value
from gv$parameter 
where upper(name) in ('PGA_AGGREGATE_TARGET','PGA_AGGREGATE_LIMIT',
'WORKAREA_SIZE_POLICY');

--------------------------------------------------
prompt <h2>PGA TARGET ADVICE</h2>

SELECT INST_ID,
ROUND(pga_target_for_estimate/1024/1024) target_mb,
pga_target_factor,
estd_pga_cache_hit_percentage cache_hit_perc,
estd_overalloc_count
FROM GV$PGA_TARGET_ADVICE 
ORDER BY INST_ID,pga_target_factor;


--------------------------------------------------
prompt <h2>AUTOMATIC PGA MEMORY MANAGEMENT TARGET ADVICE HISTOGRAM</h2>

SELECT
   INST_ID,
   low_optimal_size/1024 "Low(K)",
   (high_optimal_size+1)/1024 "High(K)",
   estd_optimal_executions "Optimal",
   estd_onepass_executions "One Pass",
   estd_multipasses_executions "Multi-Pass"
FROM
   gv$pga_target_advice_histogram
WHERE
   pga_target_factor = 1
AND
   estd_total_executions != 0
ORDER BY
   1,2;
--------------------------------------------------
prompt <h2>PGA MEMORY USAGE BY PROCESS</h2>
SELECT 
    s.inst_id,
    s.sid,
    s.serial#,
    p.spid AS os_pid,
    s.username,
    s.program,
    ROUND(p.pga_alloc_mem/1024/1024,2) AS pga_alloc_mb,
    ROUND(p.pga_used_mem/1024/1024,2) AS pga_used_mb,
    ROUND(p.pga_max_mem/1024/1024,2) AS pga_max_mb
FROM gv$process p
JOIN gv$session s 
  ON p.addr = s.paddr 
 AND p.inst_id = s.inst_id
ORDER BY pga_used_mb DESC;


--------------------------------------------------
prompt <h2>PGA MEMORY USAGE BY PROCESS</h2>
SELECT 
    p.spid AS os_pid,
    s.sid,
    s.serial#,
    s.username,
    s.program,
    ROUND(p.pga_used_mem/1024/1024,1)  AS pga_used_mb,
    ROUND(p.pga_alloc_mem/1024/1024,1) AS pga_alloc_mb,
    s.status,
    s.event
FROM v$process p
JOIN v$session s ON s.paddr = p.addr
ORDER BY p.pga_alloc_mem DESC;


prompt <h2>MEMORY GOLDEN GATE CAPTURE PROCESS</h2>
SELECT
  c.capture_name,
  c.state,
  trunc(s.total_memory_allocated/1024/1024) AS streams_mb_used,
  trunc(s.current_size/1024/1024) AS streams_mb_total
FROM v$goldengate_capture c,
     v$streams_pool_statistics s;

spool off

set markup html off

