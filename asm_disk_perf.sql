-- ASM disks Performance

set linesize 300
set pagesize 200
rem
ttitle 'ASM Disk Perf. Info'
rem

col GROUP_NUMBER    format 999  heading 'GRP|NBR'
col DISK_NUMBER     format 999  heading 'DSK|NBR'
col PATH            format a35  heading 'Path'
col READS           format 999,999,999

col READ_TIME       format 999,999,999.99 heading 'Read Time|Hundreths of Sec'
col READ_ERRS       format 999,999 heading 'READ|ERR'
col WRITES          format 999,999,999
col WRITE_TIME      format 999,999,999.99 heading 'Write Time|Hundreths of Sec'
col WRITE_ERRS      format 999,999 heading 'WRITE|ERR'

select GROUP_NUMBER
      ,DISK_NUMBER
      ,PATH
      ,READS
      ,READ_TIME/READS READ_TIME
      ,READ_ERRS
      ,WRITES
      ,WRITE_TIME/WRITES WRITE_TIME
      ,WRITE_ERRS
  from gv$asm_disk
where reads is not null
   or writes is not null
 order by group_number
         ,disk_number
;


set lines 132
col name format a15
col group_number format 999 heading 'GRP|NBR'
col path format a25
col reads format 999,999,999
col writes format 9999999
col rd_avg forma 9999.00 head 'READ|SVC|TIME|(ms)'

col wr_avg forma 9999.00 head 'WRITE|SVC|TIME|(ms)'
col byte_read format 999999999 head 'Bytes|per|Read'
col byte_write format 999999999 head 'Bytes|per|Write'
col total_mb format 999,999,999 head 'TOTAL MB'
col free_mb format 9,999,999 head 'FREE MB'
break on report skip 1 on group_number skip 1
compute sum of total_mb free_mb on report group_number
select
       group_number,
       name,
       path,
       -- create_date,
       -- mount_date,
       reads,
       -- read_time,
       read_time/decode(reads, 0, 1, reads)*1000 rd_avg,
       bytes_read/decode(reads,0,1, reads) byte_read,
       writes,
       write_time/decode(writes, 0, 1, writes)*1000 wr_avg,
       bytes_written/decode(writes,0,1, writes) byte_write
       , total_mb,
       free_mb
  from v$asm_disk
 order by
       group_number,
       name,
       path
/