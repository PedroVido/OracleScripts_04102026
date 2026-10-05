-- Define o prompt para mostrar o nome do usuário e o identificador de conexão
set sqlprompt "@|blue _USER|@@@|red _CONNECT_IDENTIFIER|@@|blue > |@";

-- Ajuste de sessão
SET ECHO OFF;
SET FEEDBACK OFF;
SET LONG 20000
SET LONGCHUNKSIZE 20000
ALTER SESSION SET NLS_DATE_FORMAT = 'DD-MON-YYYY HH24:MI:SS';




-- Definição de módulo para monitoramento de atividades
EXEC dbms_application_info.set_module( module_name => 'DBA - Pedro Vido Acc - TRABALHANDO - SQLPLUS', action_name => 'Atividade XXXX');


-- Mensagem de boas-vindas personalizada
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT | DBA      : Pedro Vido - SME Accenture                                                     |
PROMPT | Blog     : https://pedrovidodba@blogspot.com.br/                                          |
PROMPT | Ambiente : Prod                                                                           |
PROMPT | Versao   : 1.1 - Adicionado informacao sobre container databases                          |
PROMPT +-------------------------------------------------------------------------------------------+
PROMPT


-- select de indentificacao da minha sessao
set sqlformat
set lines 9999 
set pages 9999
COL Identificador FOR a15  HEADING 'Sid|Serial' JUSTIFY LEFT WORD_WRAP TRUNC
COL Action FOR a40  HEADING 'Desc|Atividade' JUSTIFY LEFT WORD_WRAP TRUNC
COL username FOR a20  HEADING 'DB|User' JUSTIFY LEFT WORD_WRAP TRUNC
COL osuser FOR a20  HEADING 'SO|User' JUSTIFY LEFT WORD_WRAP TRUNC
COL module FOR a40  HEADING 'Module|Identificacao' JUSTIFY LEFT WORD_WRAP TRUNC
COL machine FOR a20  HEADING 'DBA|Machine' JUSTIFY LEFT WORD_WRAP TRUNC
COL service_name FOR a30  HEADING 'Servico' JUSTIFY LEFT WORD_WRAP TRUNC
COL schemaname FOR a20  HEADING 'DB|Schema' JUSTIFY LEFT WORD_WRAP TRUNC


select sid||','||serial#||',@'||inst_id as Identificador,
       schemaname ,
       username, 
       osuser,
       machine, 
       service_name,
       module,
       Action
from gv$session 
WHERE sid in (SELECT sid FROM v$mystat WHERE ROWNUM=1)
and osuser ='pcvido';

PROMPT
PROMPT
PROMPT
PROMPT

-- select de identificacao do banco
COL STARTUP_TIME FOR a20
COL DTHORA FOR a20
SELECT INSTANCE_NAME, STATUS, HOST_NAME, DATABASE_ROLE, OPEN_MODE, TO_CHAR(STARTUP_TIME,'DD/MM/YYYY HH24:MI:SS') AS STARTUP_TIME,
TO_CHAR(SYSDATE,'DD/MM/YYYY HH24:MI:SS')  AS DTHORA
FROM V$INSTANCE, V$DATABASE;
alter session set optimizer_mode=rule;
PROMPT
PROMPT
--SET TIMING ON;

show con_name;
PROMPT
PROMPT

--show pdbs;

SET SERVEROUTPUT ON
 
DECLARE
v_version_major NUMBER;
BEGIN
SELECT distinct TO_NUMBER(REGEXP_SUBSTR(BANNER, '(\d)(\d)'))
INTO v_version_major
FROM v$version;
DBMS_OUTPUT.PUT_LINE('Versao detectada: ' || v_version_major||'c.');
IF v_version_major <= 12 THEN
DBMS_OUTPUT.PUT_LINE('=========================================================================');
DBMS_OUTPUT.PUT_LINE('Banco versao inferior a 12c. Não será realizada a consulta dos PDBs.');
DBMS_OUTPUT.PUT_LINE('=========================================================================');
ELSE
FOR r IN (
SELECT con_id,
name,
open_mode
FROM v$pdbs
ORDER BY con_id
)
LOOP
DBMS_OUTPUT.PUT_LINE('=========================================================================');
DBMS_OUTPUT.PUT_LINE(
RPAD(r.name, 30) ||
' CON_ID=' || r.con_id ||
' OPEN_MODE=' || r.open_mode
);
DBMS_OUTPUT.PUT_LINE('=========================================================================');
END LOOP;
END IF;
END;
/

PROMPT
PROMPT

SET FEEDBACK ON;
