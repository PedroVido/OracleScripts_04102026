/*
 Script para gerar uma matriz com a contagem de execucoes do SQL ID por dia e hora
 Sintaxe: SQL>@execs <SQL_ID> <Qtd. Dias> <Inst ID> <medida> (Onde Inst ID = 0 soma todas as instancias do cluster)
 "medida" pode ser ms para Milisegundos ou sec para segundos
 Exemplo: SQL>@execs c3bpu9sapxhpw 10 1 ms
 
 Maicon Carneiro | Salvador-BA, 11/11/2022
*/

set feedback off
alter session set nls_date_format='dd/mm Dy';
set sqlformat 
set pages 999 lines 400
col snap_date heading "Date" format a10
col h0  format 999.99
col h1  format 999.99
col h2  format 999.99
col h3  format 999.99
col h4  format 999.99
col h5  format 999.99
col h6  format 999.99
col h7  format 999.99
col h8  format 999.99
col h9  format 999.99
col h10 format 999.99
col h11 format 999.99
col h12 format 999.99
col h13 format 999.99
col h14 format 999.99
col h15 format 999.99
col h16 format 999.99
col h17 format 999.99
col h18 format 999.99
col h19 format 999.99
col h20 format 999.99
col h21 format 999.99
col h22 format 999.99
col h23 format 999.99
set feedback ON

-- obtem o nome da instancia
column NODE new_value VNODE 
SET termout off
SELECT CASE WHEN &3 = 0 THEN 'Cluster' ELSE instance_name || ' / ' || host_name END AS NODE FROM GV$INSTANCE WHERE (&3 = 0 or inst_id = &3);
SET termout ON

DEFINE vMedida = "'&4'";

-- resumo do relatorio
PROMP
PROMP Metrica...: Average Elapsed Time (&vMedida)
PROMP SQL ID....: &1
PROMP Qt. Dias..: &2 
PROMP Instance..: &VNODE
PROMP

-- query
with awr as (
 select sql_id,
        snap_id,
        begin_snap,
        hora,
        sum(elapsed_time)/greatest(sum(executions),1) as elapsed_time_avg		
 from (
   select a.sql_id,
          a.snap_id,         
          trunc(b.begin_interval_time)           as begin_snap,
          to_char(b.begin_interval_time, 'hh24') as hora,
 	      sum(executions_delta)                  as executions,
		  sum(case when  &vMedida = 'ms'  then elapsed_time_delta/1000 
		           when  &vMedida = 'sec' then elapsed_time_delta/1000000 
			       when  &vMedida = 'min' then elapsed_time_delta/1000000/60
			       else elapsed_time_delta
		      end
		    ) as elapsed_time
 	 from dba_hist_sqlstat a
 	 join dba_hist_snapshot b on (a.snap_id = b.snap_id and a.dbid = b.dbid and a.instance_number = b.instance_number)
 	where 1=1
 	  and sql_id in ('&1')
 	  and executions_delta > 0
 	  and (&3 = 0 or b.instance_number = &3)
 	  and b.begin_interval_time >= trunc(sysdate) - &2
 group by a.sql_id,
          a.snap_id,         
          trunc(b.begin_interval_time),
          TO_CHAR (b.begin_interval_time, 'hh24')
 )
 group by sql_id,
          snap_id,
          begin_snap,
          hora
)
SELECT TRUNC(begin_snap) snap_date,
       max (DECODE (hora, '00', elapsed_time_avg, null)) "h0",
       max (DECODE (hora, '01', elapsed_time_avg, null)) "h1",
       max (DECODE (hora, '02', elapsed_time_avg, null)) "h2",
       max (DECODE (hora, '03', elapsed_time_avg, null)) "h3",
       max (DECODE (hora, '04', elapsed_time_avg, null)) "h4",
       max (DECODE (hora, '05', elapsed_time_avg, null)) "h5",
       max (DECODE (hora, '06', elapsed_time_avg, null)) "h6",
       max (DECODE (hora, '07', elapsed_time_avg, null)) "h7",
       max (DECODE (hora, '08', elapsed_time_avg, null)) "h8",
       max (DECODE (hora, '09', elapsed_time_avg, null)) "h9",
       max (DECODE (hora, '10', elapsed_time_avg, null)) "h10",
       max (DECODE (hora, '11', elapsed_time_avg, null)) "h11",
       max (DECODE (hora, '12', elapsed_time_avg, null)) "h12",
       max (DECODE (hora, '13', elapsed_time_avg, null)) "h13",
       max (DECODE (hora, '14', elapsed_time_avg, null)) "h14",
       max (DECODE (hora, '15', elapsed_time_avg, null)) "h15",
       max (DECODE (hora, '16', elapsed_time_avg, null)) "h16",
       max (DECODE (hora, '17', elapsed_time_avg, null)) "h17",
       max (DECODE (hora, '18', elapsed_time_avg, null)) "h18",
       max (DECODE (hora, '19', elapsed_time_avg, null)) "h19",
       max (DECODE (hora, '20', elapsed_time_avg, null)) "h20",
       max (DECODE (hora, '21', elapsed_time_avg, null)) "h21",
       max (DECODE (hora, '22', elapsed_time_avg, null)) "h22",
       max (DECODE (hora, '23', elapsed_time_avg, null)) "h23"
 FROM awr
GROUP BY TRUNC(begin_snap)
order by 1;