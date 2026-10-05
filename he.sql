-- use : @he <days> <"event name">

set verify off
set feedback off
alter session set nls_date_format='dd/mm/yyyy';
set sqlformat
set lines 400
set pages 50
col begin_snap  heading "Date"    format a12
col event_name  heading "Event"    format a50
col wait_class  heading "Class"    format a15
col avg_time_ms heading "Avg Time (ms)" format 999,999.9999
col total_waits heading "Waits"   format 999,999,999,999
col min_wait_ms heading "Min Time (ms)" format 999,999.9999
col max_wait_ms heading "Max Time (ms)" format 999,999,999.9999

select
  trunc(begin_snap) as begin_snap,
  event_name,
  wait_class,
  SUM(total_waits) AS total_waits,
  AVG((time_waited/total_waits)*1000) AS avg_time_ms,
  MIN((time_waited/total_waits)*1000) AS min_wait_ms,
  MAX((time_waited/total_waits)*1000) AS max_wait_ms
from (
select
  s.instance_number inst_id,
  s.snap_id,
  s.begin_interval_time begin_snap,
  s.end_interval_time end_snap,
  event_name,
  wait_class,
  total_waits-lag(total_waits, 1, total_waits) over
   (partition by s.startup_time, s.instance_number, stats.event_name order by s.snap_id) total_waits,
  time_waited-lag(time_waited, 1, time_waited) over
   (partition by s.startup_time, s.instance_number, stats.event_name order by s.snap_id) time_waited,
  min(s.snap_id) over (partition by s.startup_time, s.instance_number, stats.event_name) min_snap_id
from (
 select dbid, instance_number, snap_id, event_name, wait_class, total_waits, (time_waited_micro/1000000) time_waited
  from dba_hist_system_event
  where event_name = '&2' -- filtro especifico
) stats, dba_hist_snapshot s
 where stats.instance_number=s.instance_number
  and stats.snap_id=s.snap_id
  and stats.dbid=s.dbid
  and s.dbid=(select dbid from v$database)
  and s.begin_interval_time >= trunc(sysdate) - &1
order by snap_id
) where snap_id > min_snap_id 
        and nvl(total_waits,1) > 0
GROUP BY trunc(begin_snap),
         event_name,
         wait_class
ORDER BY 1;

set feedback on
