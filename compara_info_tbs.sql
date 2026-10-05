-- ########################################################################################################
--                                                                                                       -- 
-- File Name     : compara_info_tbs.sql                                                                          --
-- Description   : Displays info of Tablespace.                                                          --
-- Comments      : N/A                                                                                   --
-- Requirements  : Access to the DBA views.                                                              --
-- Call Syntax   : @info_tbs <TBS_NAME>                                                                  --
-- Last Modified : 07/07/2023                                                                            --
-- Author        : Pedro Vido - https://pedrovidodba.blogspot.com                                        --
--                                                                                                       --
-- ########################################################################################################

set lines 9999 
set pages 9999 
set verify off
col value for a10;
col CMD for a200;
col file_name for a100
COL INCREMENT_MB FOR 999,999,990  HEADING 'MB|INCREMENT' JUSTIFY RIGHT
COL QTDE_EXTENSIONS_REMAIN FOR 999,999,990  HEADING 'QTDE|EXTENSIONS REMAINS' JUSTIFY RIGHT
COL QTDE_EXTENSIONS_DONE FOR 999,999,990  HEADING 'QTDE|EXTENSIONS DONE' JUSTIFY RIGHT

set linesize 200 
set pages 9999
set feedback off;
set heading off;
select '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
select 'LEVAMTAMENTO DE DATAFILES COM INCREMENTO DIFERENTES : DATA --> '||TO_CHAR(SYSDATE,'DD/MM/RRRR HH24:MI:SS') 																				   FROM dual;
select 'AMBIENTE --> '||instance_name||' - '||host_name||' - '||status||' - '||VERSION								 FROM v$instance;
select '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;
PROMPT
PROMPT


set feedback off;
set heading off;
select 'Block Size Value'																				   FROM dual;
set feedback ON;
set heading ON;
column value new_val blksize
select value from v$parameter where name = 'db_block_size'
/

prompt 
prompt 

-- Chamada do script de tablespaces

@consumo_tbs_new

prompt 
prompt


-- Valida quantidade de datafiles com Incremento diferente

set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Quantidade de Datafiles por tablespace com Incremento Diferente' FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

with tb1 as (
select TABLESPACE_NAME, (increment_by*(bytes/blocks)/1024/1024) as INCREMENT_MB
from   dba_data_files
where 1=1
and AUTOEXTENSIBLE = 'YES'
)
select count(*) as QTDE, tb1.TABLESPACE_NAME, tb1.INCREMENT_MB
from tb1
where 1=1
and tb1.INCREMENT_MB <> 512
and tb1.INCREMENT_MB <> 1024
group by tb1.TABLESPACE_NAME,tb1.INCREMENT_MB
order by 1,2 desc;

prompt 
prompt


-- Mostra os datafiles com Incremento diferente
set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Desc de cada Datafiles por tablespace com Incremento Diferente ' FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

with tb as (
select file_id,
       file_name, 
       AUTOEXTENSIBLE, 
       (increment_by*(bytes/blocks)/1024/1024) "INCREMENT_MB",
      --(maxbytes-bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_REMAIN",
       --(bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_DONE",
       ceil(bytes / 1024 / 1024) size_MB, 
       ceil(maxbytes / 1024 / 1024) maxsize_MB
from   dba_data_files
where  1=1 
and AUTOEXTENSIBLE = 'YES'
)
select * from 
tb
where (tb.INCREMENT_MB <> 512 and tb.INCREMENT_MB <> 1024);



-- info detalhada de cada datafile com incremento diferente
 set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Desc de consumo de Datafiles por tablespace com Incremento Diferente ' FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

with tb_inc as (
select TABLESPACE_NAME, (increment_by*(bytes/blocks)/1024/1024) as INCREMENT_MB
from   dba_data_files
where 1=1
and (increment_by*(bytes/blocks)/1024/1024) <> 512
and (increment_by*(bytes/blocks)/1024/1024) <> 1024
and AUTOEXTENSIBLE = 'YES'
)
select file_name,
       ceil( (nvl(hwm,1)*8192)/1024/1024 ) smallest,
       ceil( blocks*8192/1024/1024) currsize,
       ceil( blocks*8192/1024/1024) -
       ceil( (nvl(hwm,1)*8192)/1024/1024 ) savings,
	   AUTOEXTENSIBLE
from dba_data_files a,
     ( select file_id, max(block_id+blocks-1) hwm
         from dba_extents
        group by file_id ) b
where a.file_id = b.file_id(+)
and tablespace_name in (select tb_inc.tablespace_name from tb_inc)
/



-- Comando de resize para os datafiles com valores diferentes

 set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Comando para padronizar o incremento dos datafiles ' FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

with tb as (
select file_id,
       file_name, 
       AUTOEXTENSIBLE, 
       (increment_by*(bytes/blocks)/1024/1024) "INCREMENT_MB",
      --(maxbytes-bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_REMAIN",
       --(bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_DONE",
       ceil(bytes / 1024 / 1024) size_MB, 
       ceil(maxbytes / 1024 / 1024) maxsize_MB
from   dba_data_files
where  1=1 
and AUTOEXTENSIBLE = 'YES'
)
select 'alter database datafile '||''''||tb.file_name||''''||' autoextend on next 512m maxsize unlimited'||';' as CMD
from tb
where (tb.INCREMENT_MB <> 512 and tb.INCREMENT_MB <> 1024);


--validacao pos alteracao

 set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Validacao dos datafiles apos a alteracao de Incremento  ' FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

with tb as (
select file_id,
       file_name, 
       AUTOEXTENSIBLE, 
       (increment_by*(bytes/blocks)/1024/1024) "INCREMENT_MB",
      --(maxbytes-bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_REMAIN",
       --(bytes)/(increment_by*(bytes/blocks)) "QTDE_EXTENSIONS_DONE",
       ceil(bytes / 1024 / 1024) size_MB, 
       ceil(maxbytes / 1024 / 1024) maxsize_MB
from   dba_data_files
where  1=1 
and AUTOEXTENSIBLE = 'YES'
)
select * from 
tb
where (tb.INCREMENT_MB <> 512 and tb.INCREMENT_MB <> 1024);


prompt 
prompt 

set feedback off;
set heading off;
select '---------------------------------------------------------------------' FROM dual;
select 'Fim do Report em: '||TO_CHAR(SYSDATE,'DD/MM/RRRR HH24:MI:SS') 			 FROM dual;
select '---------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;

SET SQLFORMAT
prompt 
prompt 
