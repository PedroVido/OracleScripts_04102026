-- ########################################################################################################
--                                                                                                       --
-- File Name     : consumo_tbs.sql                                                                       --
-- Description   : Displays info tablaspaces.                                                            --
-- Comments      : N/A                                                                                   --
-- Requirements  : Access to the DBA views.                                                              --
-- Call Syntax   : @consumo_tbs                                                                          --
-- Last Modified : 18/03/2025  - V2 - Adicao de metrica historica para Capacity                          --
-- Author        : Pedro Vido - https://pedrovidodba.blogspot.com                                        --
--                                                                                                       --
-- ########################################################################################################


set lines 9999 pages 9999
set feedback off;
set heading off;
select '--------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
select 'CONSUMO TABLESPACES : DATA --> '||TO_CHAR(SYSDATE,'DD/MM/RRRR HH24:MI:SS') 																				   FROM dual;
select 'AMBIENTE --> '||instance_name||' - '||host_name||' - '||status||' - '||VERSION								 FROM v$instance;
select '--------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;
PROMPT
PROMPT

COL TABLESPACE   FOR A35          HEADING 'Tablespace'
COL TBS_SIZE     FOR 999,999,990  HEADING 'Tamanho|atual'       JUSTIFY RIGHT
COL TBS_EM_USO   FOR 999,999,990  HEADING 'Em uso'              JUSTIFY RIGHT
COL TBS_MAXSIZE  FOR 999,999,990  HEADING 'Tamanho|maximo'      JUSTIFY RIGHT
COL FREE_SPACE   FOR 999,999,990  HEADING 'Espaco|livre atual'  JUSTIFY RIGHT
COL SPACE        FOR 999,999,990  HEADING 'Espaco|livre total'  JUSTIFY RIGHT
COL PERC         FOR 990          HEADING '%|Ocupacao'          JUSTIFY RIGHT
COL bigfile      FOR A7           HEADING 'BigFile'             JUSTIFY RIGHT
COL TBS_FILES    FOR 999,999,990  HEADING 'Qtde|Arquivos'       JUSTIFY LEFT
COL autoextensible    FOR A11          HEADING 'Auto|Extensible'       JUSTIFY LEFT
--set wrap off
--set lines 145
--set pages 999
set verify off

break on report on tablespace_name skip 1
compute sum label "Total: " of tbs_em_uso tbs_size tbs_maxsize free_space space on report

select /*+ RULE */ d.tablespace,
       CASE a.autoextensible WHEN 'YES' 
       THEN 'YES' 
       ELSE 'NO'
       end as autoextensible,
       b.bigfile,
       f.tbs_files,
       trunc((d.tbs_size-nvl(s.free_space, 0))/1024/1024) tbs_em_uso,
       trunc(d.tbs_size/1024/1024) tbs_size,
       trunc(d.tbs_maxsize/1024/1024) tbs_maxsize,
       trunc(nvl(s.free_space, 0)/1024/1024) free_space,
       trunc((d.tbs_maxsize - d.tbs_size + nvl(s.free_space, 0))/1024/1024) space,
       trunc((d.tbs_size-nvl(s.free_space, 0))*100/d.tbs_maxsize) perc
from
  ( select /*+ RULE */ SUM(bytes) tbs_size,
           SUM(decode(sign(maxbytes - bytes), -1, bytes, maxbytes)) tbs_maxsize,
           tablespace_name tablespace
    from ( select /*+ RULE */ nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name
           from dba_data_files
           union all
           select /*+ RULE */ nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name
           from dba_temp_files
         )
    group by tablespace_name
  ) d,
  ( select /*+ RULE */ SUM(bytes) free_space,
           tablespace_name tablespace
    from dba_free_space
    group by tablespace_name
  ) s,
  (
    SELECT  COUNT (*) tbs_files, tablespace_name tablespace
    FROM dba_data_files
    GROUP BY tablespace_name
  ) f,
  (
    SELECT DISTINCT tablespace_name tablespace, autoextensible
    FROM dba_data_files
    WHERE autoextensible = 'YES'
  ) a,
  (
    SELECT DISTINCT tablespace_name tablespace, bigfile
    FROM dba_tablespaces
  ) b
where d.tablespace = s.tablespace(+)
and   d.tablespace = f.tablespace(+)
and   d.tablespace = a.tablespace(+)
and   d.tablespace = b.tablespace(+)
order by 10 desc
/
set verify on
--
-- Fim
--

set lines 999
set pages 999
set feedback off;
set heading off;
select '----------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
select 'CONSUMO TABLESPACES HISTORICO PARA CAPACITY E ANALISE DE CRESCIMENTO EM DIAS'	FROM dual;
select '----------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;
PROMPT
PROMPT
@tbs_hist.sql



--==========================================================
-- another script 
--==========================================================

COLUMN tablespace_name FORMAT A25
COLUMN used_percent FORMAT 999.99
COLUMN total_gb FORMAT 999,999.99
COLUMN used_gb FORMAT 999,999.99
COLUMN free_gb FORMAT 999,999.99
COLUMN status FORMAT A10
COLUMN extent_management FORMAT A10
COLUMN segment_space_management FORMAT A10
COLUMN usage_bar FORMAT  A50 word_wrap trunc

WITH ts_data AS (
    SELECT 
        tablespace_name,
        SUM(bytes) AS total_bytes,
        COUNT(*) AS file_count
    FROM dba_data_files
    GROUP BY tablespace_name
),
ts_usage AS (
    SELECT 
        d.tablespace_name,
        u.used_percent,
        (u.tablespace_size * t.block_size) AS total_bytes,
        (u.used_space * t.block_size) AS used_bytes,
        ((u.tablespace_size - u.used_space) * t.block_size) AS free_bytes
    FROM dba_tablespace_usage_metrics u
         JOIN dba_tablespaces t ON u.tablespace_name = t.tablespace_name
         JOIN dba_tablespaces d ON d.tablespace_name = t.tablespace_name
),
ts_free AS (
    SELECT 
        tablespace_name,
        NVL(SUM(bytes),0) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
),
ts_final AS (
    SELECT 
        d.tablespace_name,
        NVL(u.used_percent, 0) AS used_percent,
        NVL(d.status, 'UNKNOWN') AS status,
        d.extent_management,
        d.segment_space_management,
        NVL(u.total_bytes, a.total_bytes) AS total_bytes,
        NVL(u.used_bytes, (a.total_bytes - f.free_bytes)) AS used_bytes,
        NVL(f.free_bytes, 0) AS free_bytes
    FROM dba_tablespaces d
    LEFT JOIN ts_data a ON d.tablespace_name = a.tablespace_name
    LEFT JOIN ts_free f ON d.tablespace_name = f.tablespace_name
    LEFT JOIN ts_usage u ON d.tablespace_name = u.tablespace_name
    WHERE d.tablespace_name LIKE UPPER('&&ts')
)
SELECT 
    tablespace_name,
    ROUND(total_bytes/1024/1024/1024,2) AS total_gb,
    ROUND(used_bytes/1024/1024/1024,2) AS used_gb,
    ROUND(free_bytes/1024/1024/1024,2) AS free_gb,
    status,
    extent_management,
    segment_space_management,
    TO_CHAR(used_percent, '990.99') || '%' AS used_percent,
    --RPAD('X', ROUND(used_percent / 10), 'X') AS usage_bar
    RPAD('X', ROUND(used_percent / 10), 'X') AS usage_bar,
    ROUND(used_percent) as PCT_ROUNDED,
    ROUND(used_percent / 10) as PCT_ROUNDED_1
FROM ts_final
ORDER BY used_percent DESC;


--==========================================================
-- another script 
--==========================================================

set colsep |
set linesize 200 pages 100 trimspool on numwidth 14 
col name format a15
col owner format a15 
col "Used(GB)" format a10
col "Free(GB)" format a10
col "(Used)%" format a10
col "Size(GB)" format a10 
col "MaxSize(GB)" format a11
col "(Used)%" format a10
col Suggestion format a26

select Name,"MaxSize(GB)","Size(GB)","Used(GB)","Free(GB)","(Used)%",
Case when AcctoMaxSizeUsed >= 80 then 'NeedtoAddDatafile' else '' end as Suggestion
from 
(
SELECT d.status "Status", d.tablespace_name as Name, 
 TO_CHAR(NVL(a.maxbytes / 1024 / 1024 /1024, 0),'999999.90') "MaxSize(GB)",
 TO_CHAR(NVL(a.bytes / 1024 / 1024 /1024, 0),'999999.90') "Size(GB)", 
 TO_CHAR(NVL(a.bytes - NVL(f.bytes, 0), 0)/1024/1024 /1024,'999999.90') "Used(GB)", 
 TO_CHAR(NVL(f.bytes / 1024 / 1024 /1024, 0),'999999.90') "Free(GB)", 
 TO_CHAR(NVL((a.bytes - NVL(f.bytes, 0)) / a.bytes * 100, 0), '990.00') "(Used)%",
 TO_CHAR(NVL( (NVL(a.bytes, 0))  / a.maxbytes * 100, 0), '990.00') as AcctoMaxSizeUsed
 FROM sys.dba_tablespaces d, 
 (select tablespace_name, sum(bytes) bytes, SUM( CASE WHEN autoextensible = 'YES' THEN maxbytes ELSE bytes END ) as maxbytes from dba_data_files group by tablespace_name) a, 
 (select tablespace_name, sum(bytes) bytes from dba_free_space group by tablespace_name) f WHERE 
 d.tablespace_name = a.tablespace_name(+) AND d.tablespace_name = f.tablespace_name(+) AND NOT 
 (d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY') 
UNION ALL 
SELECT d.status 
 "Status", d.tablespace_name as Name, 
 TO_CHAR(NVL(a.maxbytes / 1024 / 1024 /1024, 0),'999999.90') "MaxSize(GB)",
 TO_CHAR(NVL(a.bytes / 1024 / 1024 /1024, 0),'999999.90') "Size(GB)", 
 TO_CHAR(NVL(t.bytes,0)/1024/1024 /1024,'999999.90') "Used(GB)",
 TO_CHAR(NVL((a.bytes -NVL(t.bytes, 0)) / 1024 / 1024 /1024, 0),'999999.90') "Free(GB)", 
 TO_CHAR(NVL(t.bytes / a.bytes * 100, 0), '990.00') "(Used)%" ,
  TO_CHAR(NVL( NVL(a.bytes, 0) / a.maxbytes * 100, 0), '990.00') as AcctoMaxSizeUsed
 FROM sys.dba_tablespaces d, 
 (select tablespace_name, sum(bytes) bytes,SUM( CASE WHEN autoextensible = 'YES' THEN maxbytes ELSE bytes END ) as maxbytes from dba_temp_files group by tablespace_name) a, 
 (select tablespace_name, sum(bytes_cached) bytes from v$temp_extent_pool group by tablespace_name) t 
 WHERE d.tablespace_name = a.tablespace_name(+) AND d.tablespace_name = t.tablespace_name(+) AND 
 d.extent_management like 'LOCAL' AND d.contents like 'TEMPORARY'
 ) k order by suggestion;