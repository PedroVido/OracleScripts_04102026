-- resumo do relatorio
PROMP
PROMP Metrica...: Estatisticas da GV$SQL
PROMP SQL ID....: &1
PROMP

SET TERMOUT OFF;
SET VERIFY OFF
set sqlformat
SET TERMOUT ON;


SET PAGES 50
SET LINES 400
col Data           HEADING "Data"                  format a10
col Inicio         HEADING "Inicio"                format a10
col Final          HEADING "Final"                 format a10
col Buffer_Gets    HEADING "Buffer Gets avg"       format 999,999,999,999.99
col Elapsed_Time   HEADING "(Elapsed Time avg ms)" format 999,999,999,999.99
col Execs          HEADING "Execs"                 format 999,999,999,999
col Disk_Reads     HEADING "(Disk Reads avg)"      format 999,999,999,999.99
col rows_processed HEADING "(Rows Processed avg)"  format 999,999,999,999.99
col CPU_Time       HEADING "(CPU Time avg ms)"     format 999,999,999,999.99
col sql_id         HEADING  "SQL Id"               format a20
select sql_id, 
	   plan_hash_value,
       sum(executions) Execs,
       sum(buffer_gets)       / sum(case when executions = 0 then 1 else executions end) Buffer_Gets,
	   sum(disk_reads)        / sum(case when executions = 0 then 1 else executions end) Disk_Reads,
       sum(rows_processed)    / sum(case when executions = 0 then 1 else executions end) rows_processed,
	   sum(cpu_time/1000)     / sum(case when executions = 0 then 1 else executions end) CPU_Time,
	   sum(elapsed_time/1000) / sum(case when executions = 0 then 1 else executions end) Elapsed_Time
from gv$sql
where sql_id in ('&1')
group by sql_id, plan_hash_value
order by sql_id, plan_hash_value;
