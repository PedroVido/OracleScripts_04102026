SET VERIFY OFF
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
col sql_id         HEADING  "SQL Id"               format a18
col avg_px         HEADING  "(AVG Px)"             format a20
col offload        HEADING  "(Offload)"            format a10
col io_saved_perc  HEADING  "(IO Saved %)"         format 999,999.99
col child_number   HEADING  "Child"                format 999
col inst_id        HEADING  "Inst"                 format 99 
col plan_hash_value HEADING "PHV"                  format 999999999999
select sql_id,
       plan_hash_value, 
       child_number,
       inst_id,
       (executions) Execs,
       (buffer_gets)       / (case when executions = 0 then 1 else executions end) Buffer_Gets,
       (disk_reads)        / (case when executions = 0 then 1 else executions end) Disk_Reads,
       (rows_processed)    / (case when executions = 0 then 1 else executions end) rows_processed,
       (cpu_time/1000)     / (case when executions = 0 then 1 else executions end) CPU_Time,
       (elapsed_time/1000) / (case when executions = 0 then 1 else executions end) Elapsed_Time,
       decode(io_cell_offload_eligible_bytes, 0, 'No', 'Yes')  offload,
       decode(io_cell_offload_eligible_bytes, 0, 0, 100 *(io_cell_offload_eligible_bytes - io_interconnect_bytes) 
         / decode(io_cell_offload_eligible_bytes,0, 1, io_cell_offload_eligible_bytes)
        ) io_saved_perc
from gv$sql
where sql_id in ('&1')
order by child_number, inst_id;
