PROMP
PROMP # = Child Number

set linesize 300
col inst_id heading "Inst | ID" format 99
col sql_id format a18
col first_load_time format a20
col child heading "#" format 99
col plan_hash_value heading "Plan | Hash Value" format 999999999999
col sql_profile format a30
col sql_plan_baseline format a30
col sql_patch format a30
col signature format 999999999999999999999
col is_bind_sensitive heading "Is|Bind|Sens"
col is_bind_aware heading "Is|Bind|Aware"
select inst_id, 
       sql_id, 
	   child_number as child, 
	   plan_hash_value, 
	   first_load_time, 
	   sql_profile, 
	   sql_plan_baseline, 
	   sql_patch, 
	   exact_matching_signature as signature,
	   is_bind_sensitive,
	   is_bind_aware 
from   gv$sql 
where  sql_id='&1';
