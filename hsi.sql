-- ########################################################################################################
--                                                                                                       -- 
-- File Name     : hsi.sql                                                                               --
-- Description   : Displays sql information by hour                                                      --
-- Comments      : N/A                                                                                   --
-- Requirements  : Access to the DBA views.                                                              --
-- Call Syntax   : @hsi <sql_id> <qtde_dias> <inst_id>                                                   --
-- Last Modified : 15/08/2024                                                                            --
-- Author        : Maicon Carneiro                                                                       --
--                                                                                                       --
-- ########################################################################################################

set feedback off
set sqlformat
SET VERIFY OFF
SET PAGES 50
SET LINES 400
col Data           HEADING "Data"                  format a10
col Inicio         HEADING "Inicio"                format a10
col Final          HEADING "Final"                 format a10
col Execs          HEADING "Execs"                 format 999,999,999,999
col Buffer_Gets    HEADING "(Buffer Gets avg)"     format 999,999,999,999.99
col Elapsed_Time   HEADING "(Elapsed Time avg ms)" format 999,999,999,999.99
col Disk_Reads     HEADING "(Disk Reads avg)"      format 999,999,999,999.99
col rows_processed HEADING "(Rows Processed avg)"  format 999,999,999,999.99
col CPU_Time       HEADING "(CPU Time avg ms)"     format 999,999,999,999.99
col Elapsed_Time   HEADING "(Elapsed avg ms)"      format 999,999,999,999.9999
col sql_id         HEADING  "SQL Id"               format a20
ALTER SESSION SET NLS_DATE_FORMAT='DD/MM/YYYY';
ALTER SESSION SET NLS_TIMESTAMP_FORMAT='DD/MM/YYYY';
set feedback on

-- obtem o nome da instancia
column NODE new_value VNODE 
SET termout off
SELECT CASE WHEN &3 = 0 THEN 'Cluster' ELSE instance_name || ' / ' || host_name END AS NODE FROM GV$INSTANCE WHERE (&3 = 0 or inst_id = &3);
SET termout ON

-- resumo do relatorio
PROMP
PROMP Metrica...: Historico do SQL_ID por Data e Snapshot
PROMP SQL ID....: &1
PROMP Qt. Dias..: &2
PROMP Instance..: &VNODE
PROMP


select sql_id,
plan_hash_value,
a.snap_id, a.instance_number as inst_id,
min(b.begin_interval_time)                                       as Data,
to_char(min(b.begin_interval_time),'hh24:mi:ss')                 as Inicio,
to_char(max(b.end_interval_time),'hh24:mi:ss')                   as Final,
sum(executions_delta)                                            as Execs,
sum(buffer_gets_delta)       / greatest(sum(executions_delta),1) as Buffer_Gets,
sum(disk_reads_delta)        / greatest(sum(executions_delta),1) as Disk_Reads,
sum(rows_processed_delta)    / greatest(sum(executions_delta),1) as rows_processed,
sum(cpu_time_delta/1000)     / greatest(sum(executions_delta),1) as CPU_Time,
sum(elapsed_time_delta/1000) / greatest(sum(executions_delta),1) as Elapsed_Time
from dba_hist_sqlstat a
join dba_hist_snapshot b on (a.snap_id = b.snap_id and a.instance_number = b.instance_number)
where 1=1
and sql_id in ('&1')
--and executions_delta > 0
and b.begin_interval_time >= trunc(sysdate) - &2
and (&3 = 0 or b.instance_number = &3)
group by sql_id, plan_hash_value, a.snap_id,  a.instance_number
order by snap_id, inst_id, plan_hash_value;
