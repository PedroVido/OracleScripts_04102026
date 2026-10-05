-- ##############################################################################################################
--                                                                                                             --
-- File Name     : consumo_tbs_new.sql                                                                         --
-- Description   : Displays info tablaspaces.                                                                  --
-- Comments      : N/A                                                                                         --
-- Requirements  : Access to the DBA views, This query user the dba_tablespace_usage_metrics                   --
-- Call Syntax   : @consumo_tbs_new                                                                            --
-- Last Modified : 03/07/2026  - V1 - Adicao dba_tablespace_usage_metrics fo metrics allign whit ASM metrics   --
-- Author        : Pedro Vido - https://pedrovidodba.blogspot.com                                              --
--                                                                                                             --
-- ##############################################################################################################

/*
Descricao da consulta:

Baseando os resultados da consulta apenas pelos views dba_data_files, dba_free_space,dba_tablespaces e dba_tmp_tablespaces
Temos o consumo das tablespaces e seus datafiles com os valores que foram alocados e isso nao reflete se o valor alocado pode ser comportado pelo espaco disponivel para alocacao no ASM.

Dessa forma, usando a view DBA_TABLESPACE_USAGE_METRICS que foi recentemente introduzida nas novas versoes do Oracle podemos avaliar se o valor alocado no maxsize pode de fato ser alocado dentro do ASM.

--=============================================================
-- Descicao dos campos da view - dba_tablespace_usage_metrics
--=============================================================

TABLESPACE_SIZE: 
Se o tablespace contiver algum arquivo de dados com autoextensão ativada, 
esta coluna mostra o tamanho máximo ao qual o tablespace pode crescer. 
O espaço livre de armazenamento subjacente, como o Oracle ASM ou o armazenamento do sistema de arquivos, é levado em consideração ao calcular esse valor. 
Em um CDB, se o valor da propriedade MAX_PDB_STORAGE da visão CDB_PROPERTIES for diferente de zero, esse valor também é considerado.

Por exemplo:
1 - Se um tablespace tem um tamanho atual de 5 GB, o tamanho máximo combinado de seus datafiles é de 32 GB e o armazenamento subjacente tem 20 GB de espaço livre, então esta coluna terá um valor de aproximadamente 25 GB.
2 - Se um tablespace tem um tamanho atual de 10 GB, o tamanho máximo combinado de seus datafiles é de 20 GB e o armazenamento subjacente tem 25 GB de espaço livre, então esta coluna terá um valor de aproximadamente 20 GB.
3 - Se um tablespace tem um tamanho atual de 15 GB, o tamanho máximo combinado de seus datafiles é de 32 GB, seu armazenamento subjacente tem 90 GB de espaço livre, o tamanho atual do PDB é de 40 GB, e MAX_PDB_STORAGE é 50 GB, 
então esta coluna terá um valor de aproximadamente 25 GB.

USED_PERCENT:
Porcentagem do espaço usado, em função do tamanho máximo possível do tablespace


*/


set linesize 200 
set pages 9999
set feedback off;
set heading off;
select '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
select 'CONSUMO TABLESPACES : DATA --> '||TO_CHAR(SYSDATE,'DD/MM/RRRR HH24:MI:SS') 																				   FROM dual;
select 'AMBIENTE --> '||instance_name||' - '||host_name||' - '||status||' - '||VERSION								 FROM v$instance;
select '-----------------------------------------------------------------------------------------------------------------------------------------------------------------------' FROM dual;
set feedback ON;
set heading ON;
PROMPT
PROMPT

SET SQLFORMAT
COLUMN tablespace_name     FORMAT a25            HEADING "Tablespace Name"                  
COLUMN file_count          FORMAT a15            HEADING "Quantidade|Datafiles"            
COLUMN used_percent        FORMAT a10            HEADING "Used %"                                      
COLUMN total_gb            FORMAT 999,999.99     HEADING "Total Em GB|With Maxsize"            
COLUMN used_gb             FORMAT 999,999.99     HEADING "Used Em GB"                          
COLUMN free_gb             FORMAT 999,999.99     HEADING "Free Em GB"                          
COLUMN max_gb              FORMAT 999,999.99     HEADING "Maxsize Em GB"                       
COLUMN status              FORMAT a10             HEADING "Status"                            
COLUMN AUTOEXTENSIBLE      FORMAT a10            HEADING "Auto|Extensible"                     
COLUMN bigfile             FORMAT a10            HEADING "Is|BigFile ?"                        
COLUMN df_graph            FORMAT a20            HEADING "Graphic % of|Maximum Utilization"   
COLUMN maxsize_togrowth_gb FORMAT a20            HEADING "Aloccate to Growth"                
--COLUMN extent_management                                                            FORMAT a20 
--COLUMN segment_space_management                                                     FORMAT a20


set verify off

WITH ts_data AS (
    SELECT 
        tablespace_name,
        SUM(bytes) AS total_bytes,
        COUNT(*) AS file_count,
        SUM(decode(sign(maxbytes - bytes), -1, bytes, maxbytes)) tbs_maxsize
        /*, AUTOEXTENSIBLE*/
    from ( select /*+ RULE */ nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name /*, AUTOEXTENSIBLE*/           
	       from dba_data_files
           union all
           select /*+ RULE */ nvl(bytes, 0) bytes, nvl(maxbytes, 0) maxbytes, tablespace_name /*, AUTOEXTENSIBLE*/
           from dba_temp_files
         )
    GROUP BY tablespace_name /*,AUTOEXTENSIBLE*/
),
ts_usage AS (
    SELECT /*+ MATERIALIZE */
        d.tablespace_name,
        d.bigfile,
        u.used_percent,
        (u.tablespace_size * t.block_size) AS total_bytes,
        (u.used_space * t.block_size) AS used_bytes,
        ((u.tablespace_size - u.used_space) * t.block_size) AS free_bytes
    FROM dba_tablespace_usage_metrics u
         JOIN dba_tablespaces t ON u.tablespace_name = t.tablespace_name
         JOIN dba_tablespaces d ON d.tablespace_name = t.tablespace_name
),
ts_free AS (
    SELECT /*+ MATERIALIZE */ tablespace_name, NVL(SUM(bytes),0) AS free_bytes
    FROM dba_free_space
    GROUP BY tablespace_name
    UNION ALL
    SELECT tablespace_name, free_space free_bytes 
    FROM dba_temp_free_space	
),
ts_final AS (
    SELECT /*+ MATERIALIZE */
        d.tablespace_name,
--        a.AUTOEXTENSIBLE,
        d.bigfile,
        a.file_count,
        NVL(u.used_percent, 0) AS used_percent,
        NVL(d.status, 'UNKNOWN') AS status,
       -- d.extent_management,
        --d.segment_space_management,
        NVL(u.total_bytes, a.total_bytes) AS total_bytes,
        NVL(u.used_bytes, (a.total_bytes - f.free_bytes)) AS used_bytes,
        NVL(f.free_bytes, 0) AS free_bytes,
        NVL(a.tbs_maxsize, 0) AS tbs_maxsize,
	    NVL(a.tbs_maxsize, 0) - a.total_bytes + NVL(f.free_bytes,0) as to_growth
    FROM dba_tablespaces d
    LEFT JOIN ts_data a ON d.tablespace_name = a.tablespace_name
    LEFT JOIN ts_free f ON d.tablespace_name = f.tablespace_name
    LEFT JOIN ts_usage u ON d.tablespace_name = u.tablespace_name
    --WHERE d.tablespace_name LIKE UPPER('&&ts')
)
SELECT 
    tablespace_name,
--    CASE autoextensible WHEN 'YES' 
--       THEN 'YES' 
--       ELSE 'NO'
--       end as autoextensible,
    bigfile,
    file_count,
    ROUND(total_bytes/1024/1024/1024,2) AS total_gb,
    ROUND(used_bytes/1024/1024/1024,2) AS used_gb,
    ROUND(free_bytes/1024/1024/1024,2) AS free_gb,
    ROUND(tbs_maxsize/1024/1024/1024,2) AS max_gb,
	ROUND(to_growth/1024/1024/1024,2) AS maxsize_togrowth_gb,
    status,
    --extent_management,
    --segment_space_management,
    TO_CHAR(used_percent, '990.99') || '%' AS used_percent,
    --RPAD('X', ROUND(used_percent / 10), 'X') AS usage_bar
    '[' || RPAD (LPAD('#',CEIL(17 * DECODE(used_percent,0,0.1,used_percent) / 100),'#'),17,' ') || ']' df_graph
FROM ts_final
ORDER BY used_percent DESC;

SET SQLFORMAT
set lines 9999 pages 9999