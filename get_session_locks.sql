/*==============================================================================
 Script Name : get_session_locks.sql
 Author      : Adriano Francisco
 Version     : 1.1.0
 Status      : Production
 Last Update : 2026-09-16

------------------------------------------------------------------------------
 USAGE
------------------------------------------------------------------------------

 SQL> @get_session_locks.sql

------------------------------------------------------------------------------
 OBJECTIVE
------------------------------------------------------------------------------
 Identificar e analisar cadeias de bloqueio (locking chains) em ambientes
 Oracle, apresentando:

   - Cadeias independentes de bloqueio
   - Sessão raiz (Root Blocker)
   - SQL responsável pelo bloqueio
   - Informações da transação
   - Consumo de UNDO
   - Tempo de espera
   - Impacto da cadeia
   - Árvore hierárquica completa dos bloqueios
   - Comando de KILL SESSION para análise operacional

 Tested Versions:

   Oracle Database 12.1.0.2
   Oracle Database 19c
   Oracle RAC

------------------------------------------------------------------------------
 CONFIGURATION
------------------------------------------------------------------------------
 c_min_wait_seconds

 Define o tempo mínimo (em segundos) para que uma cadeia seja
 considerada no relatório.

 Exemplo:

   10    = Laboratório
   300   = Homologação
   600   = Produção (recomendado)

------------------------------------------------------------------------------
 LIMITATIONS
------------------------------------------------------------------------------
 - O relatório utiliza informações em tempo real das views GV$.
 - Cadeias encerradas antes da execução não serão exibidas.
 - SQL_ID pode não estar disponível caso o cursor tenha sido removido do
   Shared Pool.
 - O relatório apenas exibe o comando KILL SESSION.
 - Nenhuma ação é executada automaticamente.

------------------------------------------------------------------------------
 CHANGE LOG
------------------------------------------------------------------------------

 Version  Date        Author              Description
 -------  ----------  ------------------  --------------------------------------
 1.0.0    2026-09-16  Adriano Francisco   Initial Single /RAC hierarchical report.
 1.1.0    2026-09-16  Adriano Francisco   Added AWS RDS detection and platform-
                                          specific kill command generation.
==============================================================================*/

SET SERVEROUTPUT ON SIZE UNLIMITED
SET LINESIZE 250
SET PAGESIZE 500
SET VERIFY OFF
SET FEEDBACK OFF
SET TRIMSPOOL ON
SET TAB OFF

DECLARE
    ----------------------------------------------------------------------------
    -- CONFIGURATION
    ----------------------------------------------------------------------------
    c_min_wait_seconds CONSTANT PLS_INTEGER := 10;

    c_separator CONSTANT VARCHAR2(200) :=
        '=================================================================================================================================================';

    c_subseparator CONSTANT VARCHAR2(200) :=
        '-------------------------------------------------------------------------------------------------------------------------------------------------';

    ----------------------------------------------------------------------------
    -- Controle para evitar loops em cadeias ciclicas
    ----------------------------------------------------------------------------
    TYPE t_visited IS TABLE OF BOOLEAN INDEX BY VARCHAR2(100);

    g_visited      t_visited;
    g_chain_count  PLS_INTEGER := 0;
    g_chain_number PLS_INTEGER := 0;
	
	----------------------------------------------------------------------------
    -- PLATFORM DETECTION
    ----------------------------------------------------------------------------
    g_is_aws_rds       BOOLEAN := FALSE;
    g_platform_name    VARCHAR2(100) := 'Single / Rac Oracle';
    g_detection_detail VARCHAR2(4000);
	

    ----------------------------------------------------------------------------
    -- Formata segundos no formato DD HH24:MI:SS
    ----------------------------------------------------------------------------
    FUNCTION format_seconds(
        p_seconds IN NUMBER
    ) RETURN VARCHAR2
    IS
        l_seconds NUMBER := GREATEST(NVL(p_seconds, 0), 0);
        l_days    NUMBER;
        l_hours   NUMBER;
        l_minutes NUMBER;
        l_secs    NUMBER;
    BEGIN
        l_days    := FLOOR(l_seconds / 86400);
        l_hours   := FLOOR(MOD(l_seconds, 86400) / 3600);
        l_minutes := FLOOR(MOD(l_seconds, 3600) / 60);
        l_secs    := FLOOR(MOD(l_seconds, 60));

        IF l_days > 0 THEN
            RETURN
                l_days || 'd ' ||
                LPAD(l_hours,   2, '0') || ':' ||
                LPAD(l_minutes, 2, '0') || ':' ||
                LPAD(l_secs,    2, '0');
        ELSE
            RETURN
                LPAD(l_hours,   2, '0') || ':' ||
                LPAD(l_minutes, 2, '0') || ':' ||
                LPAD(l_secs,    2, '0');
        END IF;
    END format_seconds;

    ----------------------------------------------------------------------------
    -- Formata bytes
    ----------------------------------------------------------------------------
    FUNCTION format_bytes(
        p_bytes IN NUMBER
    ) RETURN VARCHAR2
    IS
    BEGIN
        IF p_bytes IS NULL THEN
            RETURN 'N/D';

        ELSIF p_bytes >= POWER(1024, 4) THEN
            RETURN TO_CHAR(
                       ROUND(p_bytes / POWER(1024, 4), 2),
                       'FM999999990D00'
                   ) || ' TB';

        ELSIF p_bytes >= POWER(1024, 3) THEN
            RETURN TO_CHAR(
                       ROUND(p_bytes / POWER(1024, 3), 2),
                       'FM999999990D00'
                   ) || ' GB';

        ELSIF p_bytes >= POWER(1024, 2) THEN
            RETURN TO_CHAR(
                       ROUND(p_bytes / POWER(1024, 2), 2),
                       'FM999999990D00'
                   ) || ' MB';

        ELSIF p_bytes >= 1024 THEN
            RETURN TO_CHAR(
                       ROUND(p_bytes / 1024, 2),
                       'FM999999990D00'
                   ) || ' KB';

        ELSE
            RETURN TO_CHAR(p_bytes) || ' bytes';
        END IF;
    END format_bytes;

    ----------------------------------------------------------------------------
    -- Classifica o impacto conforme a quantidade de sessoes bloqueadas
    -- Ajuste os limites conforme o baseline do ambiente
    ----------------------------------------------------------------------------
    FUNCTION impact_severity(
        p_blocked_sessions IN NUMBER
    ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN
            CASE
                WHEN NVL(p_blocked_sessions, 0) >= 50 THEN 'CRITICAL'
                WHEN NVL(p_blocked_sessions, 0) >= 20 THEN 'HIGH'
                WHEN NVL(p_blocked_sessions, 0) >= 10 THEN 'MEDIUM'
                ELSE 'LOW'
            END;
    END impact_severity;

    ----------------------------------------------------------------------------
    -- Indicador operacional de risco de rollback
    -- Este indicador nao substitui a avaliacao tecnica da transacao
    ----------------------------------------------------------------------------
    FUNCTION rollback_risk(
        p_used_ublk IN NUMBER
    ) RETURN VARCHAR2
    IS
    BEGIN
        RETURN
            CASE
                WHEN p_used_ublk IS NULL   THEN 'NONE / UNKNOWN'
                WHEN p_used_ublk >= 100000 THEN 'HIGH'
                WHEN p_used_ublk >= 10000  THEN 'MEDIUM'
                ELSE 'LOW'
            END;
    END rollback_risk;

    ----------------------------------------------------------------------------
    -- Recupera o nome da instancia RAC
    ----------------------------------------------------------------------------
    FUNCTION get_instance_name(
        p_inst_id IN NUMBER
    ) RETURN VARCHAR2
    IS
        l_instance_name gv$instance.instance_name%TYPE;
    BEGIN
        IF p_inst_id IS NULL THEN
            RETURN 'N/D';
        END IF;

        SELECT instance_name
          INTO l_instance_name
          FROM gv$instance
         WHERE inst_id = p_inst_id;

        RETURN l_instance_name;

    EXCEPTION
        WHEN NO_DATA_FOUND THEN
            RETURN 'INST_ID=' || p_inst_id;

        WHEN OTHERS THEN
            RETURN 'INST_ID=' || p_inst_id;
    END get_instance_name;

    ----------------------------------------------------------------------------
    -- Recupera o SQL atual ou anterior no Shared Pool
    ----------------------------------------------------------------------------
    FUNCTION get_sql_text(
        p_inst_id IN NUMBER,
        p_sql_id  IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        l_sql_text VARCHAR2(4000);
    BEGIN
        IF p_sql_id IS NULL THEN
            RETURN '[SQL_ID not available]';
        END IF;

        BEGIN
            SELECT DBMS_LOB.SUBSTR(x.sql_fulltext, 4000, 1)
              INTO l_sql_text
              FROM (
                    SELECT sql_fulltext
                      FROM gv$sql
                     WHERE inst_id = p_inst_id
                       AND sql_id  = p_sql_id
                     ORDER BY
                         last_active_time DESC,
                         child_number
                   ) x
             WHERE ROWNUM = 1;

            RETURN REPLACE(
                       REPLACE(
                           NVL(l_sql_text, '[SQL text not available]'),
                           CHR(10),
                           ' '
                       ),
                       CHR(13),
                       ' '
                   );

        EXCEPTION
            WHEN NO_DATA_FOUND THEN
                RETURN
                    '[SQL_ID ' || p_sql_id ||
                    ' not found in Shared Pool]';

            WHEN OTHERS THEN
                RETURN
                    '[Error retrieving SQL text: ' ||
                    SQLERRM || ']';
        END;
    END get_sql_text;

    ----------------------------------------------------------------------------
    -- Imprime o SQL em linhas menores
    ----------------------------------------------------------------------------
    PROCEDURE print_sql(
        p_prefix   IN VARCHAR2,
        p_sql_text IN VARCHAR2
    )
    IS
        l_position PLS_INTEGER := 1;
        l_length   PLS_INTEGER;
        l_prefix   VARCHAR2(300);
        l_piece    VARCHAR2(200);
    BEGIN
        IF p_sql_text IS NULL THEN
            DBMS_OUTPUT.PUT_LINE(
                p_prefix || '[SQL text not available]'
            );
            RETURN;
        END IF;

        l_length := LENGTH(p_sql_text);
        l_prefix := p_prefix;

        WHILE l_position <= l_length LOOP
            l_piece := SUBSTR(
                           p_sql_text,
                           l_position,
                           170
                       );

            DBMS_OUTPUT.PUT_LINE(
                l_prefix || l_piece
            );

            l_prefix :=
                RPAD(' ', LENGTH(p_prefix), ' ');

            l_position := l_position + 170;
        END LOOP;
    END print_sql;

    ----------------------------------------------------------------------------
    -- Imprime recursivamente todos os descendentes da sessao informada
    ----------------------------------------------------------------------------
    PROCEDURE print_wait_chain(
        p_blocker_inst_id IN NUMBER,
        p_blocker_sid     IN NUMBER,
        p_depth           IN PLS_INTEGER
    )
    IS
        l_key         VARCHAR2(100);
        l_indent      VARCHAR2(4000);
        l_sql_id      VARCHAR2(13);
        l_sql_text    VARCHAR2(4000);
        l_child_count PLS_INTEGER := 0;
    BEGIN
        FOR s IN (
            SELECT
                ws.inst_id,
                wi.instance_name,
                ws.sid,
                ws.serial#,
                ws.username,
                ws.osuser,
                ws.machine,
                ws.service_name,
                ws.program,
                ws.module,
                ws.action,
                ws.client_identifier,
                ws.status,
                ws.logon_time,
                ws.last_call_et,
                ws.event,
                ws.wait_class,
                ws.state,
                ws.seconds_in_wait,
                ws.sql_id,
                ws.prev_sql_id,
                ws.blocking_instance,
                ws.blocking_session,
                ws.final_blocking_instance,
                ws.final_blocking_session,
                ws.row_wait_obj#,
                ws.row_wait_file#,
                ws.row_wait_block#,
                ws.row_wait_row#,

                wp.spid,

                wt.status     AS transaction_status,
                wt.start_date AS transaction_start_date,
                wt.start_scn,
                wt.used_ublk,
                wt.used_urec,

                obj.owner     AS object_owner,
                obj.object_name,
                obj.object_type

            FROM gv$session ws

            JOIN gv$instance wi
              ON wi.inst_id = ws.inst_id

            LEFT JOIN gv$process wp
              ON wp.inst_id = ws.inst_id
             AND wp.addr    = ws.paddr

            LEFT JOIN gv$transaction wt
              ON wt.inst_id  = ws.inst_id
             AND wt.ses_addr = ws.saddr

            LEFT JOIN dba_objects obj
              ON obj.object_id = ws.row_wait_obj#

            WHERE ws.blocking_session_status = 'VALID'
              AND ws.blocking_instance       = p_blocker_inst_id
              AND ws.blocking_session        = p_blocker_sid

            ORDER BY
                ws.seconds_in_wait DESC,
                ws.inst_id,
                ws.sid,
                ws.serial#
        )
        LOOP
            l_child_count := l_child_count + 1;

            l_key :=
                s.inst_id || ':' ||
                s.sid     || ':' ||
                s.serial#;

            l_indent :=
                LPAD(' ', p_depth * 4, ' ');

            --------------------------------------------------------------------
            -- Impede loop infinito em cadeias ciclicas
            --------------------------------------------------------------------
            IF g_visited.EXISTS(l_key) THEN
                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '+-- [CYCLE DETECTED] ' ||
                    '[INST ' || s.inst_id || '] ' ||
                    s.instance_name || ':' ||
                    s.sid || ',' || s.serial#
                );

                CONTINUE;
            END IF;

            g_visited(l_key) := TRUE;

            l_sql_id :=
                COALESCE(
                    s.sql_id,
                    s.prev_sql_id
                );

            l_sql_text :=
                get_sql_text(
                    s.inst_id,
                    l_sql_id
                );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '+-- [INST ' || s.inst_id || '] ' ||
                s.instance_name || ':' ||
                s.sid || ',' || s.serial# ||
                ' | SPID=' || NVL(s.spid, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Blocked by......: [INST ' ||
                s.blocking_instance || '] ' ||
                get_instance_name(s.blocking_instance) ||
                ':' || s.blocking_session
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Root blocker....: [INST ' ||
                s.final_blocking_instance || '] ' ||
                get_instance_name(
                    s.final_blocking_instance
                ) ||
                ':' || s.final_blocking_session
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    User............: ' ||
                NVL(s.username, '[BACKGROUND]')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    OS user.........: ' ||
                NVL(s.osuser, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Machine.........: ' ||
                NVL(s.machine, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Service.........: ' ||
                NVL(s.service_name, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Program.........: ' ||
                NVL(SUBSTR(s.program, 1, 100), 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Module..........: ' ||
                NVL(SUBSTR(s.module, 1, 100), 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Action..........: ' ||
                NVL(SUBSTR(s.action, 1, 100), 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Client ID.......: ' ||
                NVL(
                    SUBSTR(s.client_identifier, 1, 100),
                    'N/D'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Session status..: ' ||
                NVL(s.status, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Logon time......: ' ||
                TO_CHAR(
                    s.logon_time,
                    'YYYY-MM-DD HH24:MI:SS'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Last call.......: ' ||
                format_seconds(s.last_call_et) ||
                ' (' || s.last_call_et || ' seconds)'
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Wait event......: ' ||
                NVL(s.event, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Wait class......: ' ||
                NVL(s.wait_class, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Wait state......: ' ||
                NVL(s.state, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    Wait time.......: ' ||
                format_seconds(s.seconds_in_wait) ||
                ' (' || s.seconds_in_wait || ' seconds)' ||
                CASE
                    WHEN s.seconds_in_wait >=
                         c_min_wait_seconds
                    THEN ' [LONG WAIT]'
                    ELSE NULL
                END
            );

            DBMS_OUTPUT.PUT_LINE(
                l_indent ||
                '    SQL ID..........: ' ||
                NVL(l_sql_id, 'N/D') ||
                CASE
                    WHEN s.sql_id IS NOT NULL
                    THEN ' [CURRENT SQL]'

                    WHEN s.prev_sql_id IS NOT NULL
                    THEN ' [PREVIOUS SQL]'

                    ELSE NULL
                END
            );

            print_sql(
                l_indent || '    SQL text........: ',
                l_sql_text
            );

            IF s.transaction_start_date IS NOT NULL THEN
                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Transaction.....: ' ||
                    NVL(s.transaction_status, 'N/D')
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Transaction start: ' ||
                    TO_CHAR(
                        s.transaction_start_date,
                        'YYYY-MM-DD HH24:MI:SS'
                    )
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Transaction age..: ' ||
                    format_seconds(
                        (
                            SYSDATE -
                            s.transaction_start_date
                        ) * 86400
                    )
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Start SCN........: ' ||
                    NVL(TO_CHAR(s.start_scn), 'N/D')
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Undo blocks......: ' ||
                    NVL(TO_CHAR(s.used_ublk), '0')
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Undo records.....: ' ||
                    NVL(TO_CHAR(s.used_urec), '0')
                );
            ELSE
                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Transaction.....: ' ||
                    'not found in GV$TRANSACTION'
                );
            END IF;

            IF s.row_wait_obj# > 0 THEN
                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Wait object.....: ' ||
                    NVL(s.object_owner, 'N/D') || '.' ||
                    NVL(
                        s.object_name,
                        'OBJECT_ID=' || s.row_wait_obj#
                    ) ||
                    ' [' ||
                    NVL(s.object_type, 'N/D') ||
                    ']'
                );

                DBMS_OUTPUT.PUT_LINE(
                    l_indent ||
                    '    Row location....: FILE=' ||
                    s.row_wait_file# ||
                    ' BLOCK=' ||
                    s.row_wait_block# ||
                    ' ROW=' ||
                    s.row_wait_row#
                );
            END IF;

           -- DBMS_OUTPUT.PUT_LINE(
           --     l_indent ||
           --    '    ' ||
           --     RPAD('-', 72, '-')
           -- );

            --------------------------------------------------------------------
            -- Procura sessoes bloqueadas pela sessao atual
            --------------------------------------------------------------------
            print_wait_chain(
                p_blocker_inst_id => s.inst_id,
                p_blocker_sid     => s.sid,
                p_depth           => p_depth + 1
            );
        END LOOP;

        IF l_child_count = 0 AND p_depth = 1 THEN
            DBMS_OUTPUT.PUT_LINE(
                LPAD(' ', p_depth * 4, ' ') ||
                '[No direct child session found]'
            );
        END IF;
    END print_wait_chain;
    ----------------------------------------------------------------------------
    -- Detecta AWS Oracle RDS
    --
    -- A validacao e baseada na disponibilidade da procedure:
    --
    --     RDSADMIN.RDSADMIN_UTIL.KILL
    --
    -- ALL_PROCEDURES retorna somente objetos acessiveis ao usuario atual.
    -- Portanto, alem de identificar a package, esta validacao indica se a
    -- chamada esta visivel para o usuario executor.
    ----------------------------------------------------------------------------
    FUNCTION is_aws_oracle_rds
        RETURN BOOLEAN
    IS
        l_count PLS_INTEGER := 0;
    BEGIN
        SELECT COUNT(*)
          INTO l_count
          FROM all_procedures
         WHERE owner          = 'RDSADMIN'
           AND object_name    = 'RDSADMIN_UTIL'
           AND procedure_name = 'KILL';

        IF l_count > 0 THEN
            g_detection_detail :=
                'RDSADMIN.RDSADMIN_UTIL.KILL is available';

            RETURN TRUE;
        END IF;

        g_detection_detail :=
            'RDSADMIN.RDSADMIN_UTIL.KILL is not available';

        RETURN FALSE;

    EXCEPTION
        WHEN OTHERS THEN
            g_detection_detail :=
                'Unable to validate RDSADMIN package: ' ||
                SQLERRM;

            RETURN FALSE;
    END is_aws_oracle_rds;

    ----------------------------------------------------------------------------
    -- Gera o comando de encerramento da sessao conforme a plataforma
    --
    -- AWS Oracle RDS:
    --
    --     RDSADMIN.RDSADMIN_UTIL.KILL
    --
    -- Oracle convencional, RAC, Exadata, ExaCS ou OCI:
    --
    --     ALTER SYSTEM KILL SESSION
    --
    -- O comando e apenas exibido. Nenhuma sessao e encerrada automaticamente.
    ----------------------------------------------------------------------------
    PROCEDURE print_kill_command(
        p_sid     IN NUMBER,
        p_serial  IN NUMBER,
        p_inst_id IN NUMBER
    )
    IS
    BEGIN
        IF g_is_aws_rds THEN
            DBMS_OUTPUT.PUT_LINE(
                'Kill mechanism.....: AWS RDSADMIN package'
            );

            DBMS_OUTPUT.NEW_LINE;

            DBMS_OUTPUT.PUT_LINE('BEGIN');

            DBMS_OUTPUT.PUT_LINE(
                '    rdsadmin.rdsadmin_util.kill('
            );

            DBMS_OUTPUT.PUT_LINE(
                '        sid    => ' ||
                TO_CHAR(p_sid, 'FM99999999999999999990') ||
                ','
            );

            DBMS_OUTPUT.PUT_LINE(
                '        serial => ' ||
                TO_CHAR(p_serial, 'FM99999999999999999990') ||
                ','
            );

            DBMS_OUTPUT.PUT_LINE(
                '        method => ''IMMEDIATE'''
            );

            DBMS_OUTPUT.PUT_LINE('    );');
            DBMS_OUTPUT.PUT_LINE('END;');
            DBMS_OUTPUT.PUT_LINE('/');

            DBMS_OUTPUT.NEW_LINE;

            DBMS_OUTPUT.PUT_LINE(
                '-- PROCESS should only be considered if IMMEDIATE fails:'
            );

            DBMS_OUTPUT.PUT_LINE(
                '-- method => ''PROCESS'''
            );
        ELSE
            DBMS_OUTPUT.PUT_LINE(
                'Kill mechanism.....: ALTER SYSTEM KILL SESSION'
            );

            DBMS_OUTPUT.NEW_LINE;

            DBMS_OUTPUT.PUT_LINE(
                'ALTER SYSTEM KILL SESSION ''' ||
                TO_CHAR(p_sid, 'FM99999999999999999990') ||
                ',' ||
                TO_CHAR(p_serial, 'FM99999999999999999990') ||
                ',@' ||
                TO_CHAR(p_inst_id, 'FM99999999999999999990') ||
                ''' IMMEDIATE;'
            );
        END IF;
    END print_kill_command;



BEGIN
    DBMS_OUTPUT.ENABLE(NULL);

    ----------------------------------------------------------------------------
    -- Detecta a plataforma antes de gerar o relatorio
    ----------------------------------------------------------------------------
    g_is_aws_rds := is_aws_oracle_rds;

    IF g_is_aws_rds THEN
        g_platform_name := 'AWS ORACLE RDS';
    ELSE
        g_platform_name := 'STANDARD ORACLE / RAC';
    END IF;


    ----------------------------------------------------------------------------
    -- REPORT HEADER
    ----------------------------------------------------------------------------
        DBMS_OUTPUT.PUT_LINE(c_separator);
    DBMS_OUTPUT.PUT_LINE(
        'ORACLE BLOCKING SESSION REPORT'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Platform...........: ' ||
        g_platform_name
    );

    DBMS_OUTPUT.PUT_LINE(
        'Platform detection.: ' ||
        NVL(g_detection_detail, 'N/D')
    );

    DBMS_OUTPUT.PUT_LINE(
        'Generated at.......: ' ||
        TO_CHAR(
            SYSDATE,
            'YYYY-MM-DD HH24:MI:SS'
        )
    );

    DBMS_OUTPUT.PUT_LINE(
        'Long-wait threshold: ' ||
        c_min_wait_seconds ||
        ' seconds'
    );

    DBMS_OUTPUT.PUT_LINE(c_separator);

    ----------------------------------------------------------------------------
    -- Conta quantas cadeias independentes atendem ao filtro
    ----------------------------------------------------------------------------
    SELECT COUNT(*)
      INTO g_chain_count
      FROM (
            SELECT DISTINCT
                s.final_blocking_instance,
                s.final_blocking_session
            FROM gv$session s
            WHERE s.final_blocking_session_status = 'VALID'
              AND s.seconds_in_wait >= c_min_wait_seconds
           );

    IF g_chain_count = 0 THEN
        DBMS_OUTPUT.PUT_LINE(CHR(10));

        DBMS_OUTPUT.PUT_LINE(
            'No blocking chain with waits >= ' ||
            c_min_wait_seconds ||
            ' seconds was found.'
        );

        DBMS_OUTPUT.PUT_LINE(c_separator);
        RETURN;
    END IF;

    DBMS_OUTPUT.PUT_LINE(
        'Lock chains found: ' ||
        g_chain_count
    );

    ----------------------------------------------------------------------------
    -- CHAIN SUMMARY
    --
    -- Uma linha por cadeia independente.
    -- A cadeia e identificada por:
    --
    -- FINAL_BLOCKING_INSTANCE + FINAL_BLOCKING_SESSION
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || c_separator
    );

    DBMS_OUTPUT.PUT_LINE('CHAIN SUMMARY');
    DBMS_OUTPUT.PUT_LINE(c_separator);

    DBMS_OUTPUT.PUT_LINE(
        RPAD('#', 5) ||
        RPAD('SEVERITY', 11) ||
        RPAD('ROOT SESSION', 32) ||
        LPAD('BLOCKED', 10) ||
        LPAD('LONG WAIT', 12) ||
        LPAD('MAX WAIT', 16) ||
        '  USER / MACHINE'
    );

    DBMS_OUTPUT.PUT_LINE(
        RPAD('-', 4, '-') || ' ' ||
        RPAD('-', 10, '-') ||
        RPAD('-', 31, '-') ||
        LPAD('-', 9, '-') || ' ' ||
        LPAD('-', 11, '-') || ' ' ||
        LPAD('-', 15, '-') || '  ' ||
        RPAD('-', 60, '-')
    );

    g_chain_number := 0;

    FOR s IN (
        WITH chain_data AS
        (
            SELECT
                blocked.final_blocking_instance
                    AS root_inst_id,

                blocked.final_blocking_session
                    AS root_sid,

                COUNT(*) AS total_blocked_sessions,

                SUM(
                    CASE
                        WHEN blocked.seconds_in_wait >=
                             c_min_wait_seconds
                        THEN 1
                        ELSE 0
                    END
                ) AS long_wait_sessions,

                MAX(blocked.seconds_in_wait)
                    AS maximum_wait_seconds

            FROM gv$session blocked

            WHERE blocked.final_blocking_session_status =
                  'VALID'

            GROUP BY
                blocked.final_blocking_instance,
                blocked.final_blocking_session

            HAVING MAX(
                       CASE
                           WHEN blocked.seconds_in_wait >=
                                c_min_wait_seconds
                           THEN 1
                           ELSE 0
                       END
                   ) = 1
        )
        SELECT
            cd.root_inst_id,
            ri.instance_name,
            root.sid,
            root.serial#,
            root.username,
            root.machine,
            cd.total_blocked_sessions,
            cd.long_wait_sessions,
            cd.maximum_wait_seconds

        FROM chain_data cd

        JOIN gv$session root
          ON root.inst_id = cd.root_inst_id
         AND root.sid     = cd.root_sid

        JOIN gv$instance ri
          ON ri.inst_id = root.inst_id

        ORDER BY
            cd.total_blocked_sessions DESC,
            cd.maximum_wait_seconds DESC,
            cd.root_inst_id,
            cd.root_sid
    )
    LOOP
        g_chain_number := g_chain_number + 1;

        DBMS_OUTPUT.PUT_LINE(
            RPAD(TO_CHAR(g_chain_number), 5) ||

            RPAD(
                impact_severity(
                    s.total_blocked_sessions
                ),
                11
            ) ||

            RPAD(
                '[INST ' ||
                s.root_inst_id ||
                '] ' ||
                s.instance_name ||
                ':' ||
                s.sid ||
                ',' ||
                s.serial#,
                32
            ) ||

            LPAD(
                TO_CHAR(s.total_blocked_sessions),
                10
            ) ||

            LPAD(
                TO_CHAR(s.long_wait_sessions),
                12
            ) ||

            LPAD(
                format_seconds(
                    s.maximum_wait_seconds
                ),
                16
            ) ||

            '  ' ||

            NVL(s.username, '[BACKGROUND]') ||
            ' / ' ||
            NVL(s.machine, 'N/D')
        );
    END LOOP;

    ----------------------------------------------------------------------------
    -- DETAILS FOR ALL CHAINS
    --
    -- Este cursor repete a mesma identificacao do resumo, mas recupera todos
    -- os atributos necessarios para imprimir:
    --
    -- 1. Root blocker
    -- 2. SQL
    -- 3. Transaction
    -- 4. Impact
    -- 5. Hierarchical wait chain
    ----------------------------------------------------------------------------
    g_chain_number := 0;

    FOR r IN (
        WITH chain_data AS
        (
            SELECT
                blocked.final_blocking_instance
                    AS root_inst_id,

                blocked.final_blocking_session
                    AS root_sid,

                COUNT(*) AS total_blocked_sessions,

                SUM(
                    CASE
                        WHEN blocked.seconds_in_wait >=
                             c_min_wait_seconds
                        THEN 1
                        ELSE 0
                    END
                ) AS long_wait_sessions,

                MAX(blocked.seconds_in_wait)
                    AS maximum_wait_seconds

            FROM gv$session blocked

            WHERE blocked.final_blocking_session_status =
                  'VALID'

            GROUP BY
                blocked.final_blocking_instance,
                blocked.final_blocking_session

            HAVING MAX(
                       CASE
                           WHEN blocked.seconds_in_wait >=
                                c_min_wait_seconds
                           THEN 1
                           ELSE 0
                       END
                   ) = 1
        )
        SELECT
            cd.root_inst_id,
            cd.root_sid,
            cd.total_blocked_sessions,
            cd.long_wait_sessions,
            cd.maximum_wait_seconds,

            ri.instance_name,

            root.serial#,
            root.username,
            root.osuser,
            root.machine,
            root.port,
            root.service_name,
            root.program,
            root.module,
            root.action,
            root.client_info,
            root.client_identifier,
            root.status,
            root.logon_time,
            root.last_call_et,
            root.event,
            root.wait_class,
            root.state,
            root.seconds_in_wait,
            root.sql_id,
            root.prev_sql_id,

            rp.spid,
            rp.tracefile,

            tx.status     AS transaction_status,
            tx.start_date AS transaction_start_date,
            tx.start_scn,
            tx.used_ublk,
            tx.used_urec,

            ts.block_size,

            CASE
                WHEN tx.used_ublk IS NOT NULL
                 AND ts.block_size IS NOT NULL
                THEN
                    tx.used_ublk * ts.block_size
                ELSE
                    NULL
            END AS approximate_undo_bytes

        FROM chain_data cd

        JOIN gv$session root
          ON root.inst_id = cd.root_inst_id
         AND root.sid     = cd.root_sid

        JOIN gv$instance ri
          ON ri.inst_id = root.inst_id

        LEFT JOIN gv$process rp
          ON rp.inst_id = root.inst_id
         AND rp.addr    = root.paddr

        LEFT JOIN gv$transaction tx
          ON tx.inst_id  = root.inst_id
         AND tx.ses_addr = root.saddr

        LEFT JOIN gv$rollstat rs
          ON rs.inst_id = tx.inst_id
         AND rs.usn     = tx.xidusn

        LEFT JOIN dba_rollback_segs drs
          ON drs.segment_id = rs.usn

        LEFT JOIN dba_tablespaces ts
          ON ts.tablespace_name = drs.tablespace_name

        ORDER BY
            cd.total_blocked_sessions DESC,
            cd.maximum_wait_seconds DESC,
            cd.root_inst_id,
            cd.root_sid
    )
    LOOP
        g_chain_number := g_chain_number + 1;

        ------------------------------------------------------------------------
        -- Reinicia o controle de ciclos para cada cadeia
        ------------------------------------------------------------------------
        g_visited.DELETE;

        g_visited(
            r.root_inst_id || ':' ||
            r.root_sid     || ':' ||
            r.serial#
        ) := TRUE;

        DBMS_OUTPUT.PUT_LINE(
            CHR(10) || c_separator
        );

        DBMS_OUTPUT.PUT_LINE(
            'CHAIN #' ||
            g_chain_number ||
            ' OF ' ||
            g_chain_count ||
            ' - ROOT BLOCKER DETAILS'
        );

        DBMS_OUTPUT.PUT_LINE(c_separator);
        DBMS_OUTPUT.PUT_LINE('#SESSION BLOCKER INFO#');

        ------------------------------------------------------------------------
        -- ROOT BLOCKER IDENTIFICATION
        ------------------------------------------------------------------------
        DBMS_OUTPUT.PUT_LINE(
            'Severity...........: ' ||
            impact_severity(
                r.total_blocked_sessions
            )
        );

        DBMS_OUTPUT.PUT_LINE(
            'Root session.......: [INST ' ||
            r.root_inst_id ||
            '] ' ||
            r.instance_name ||
            ':' ||
            r.root_sid ||
            ',' ||
            r.serial#
        );

        DBMS_OUTPUT.PUT_LINE(
            'Oracle SPID........: ' ||
            NVL(r.spid, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Database user......: ' ||
            NVL(r.username, '[BACKGROUND]')
        );

        DBMS_OUTPUT.PUT_LINE(
            'OS user............: ' ||
            NVL(r.osuser, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Machine............: ' ||
            NVL(r.machine, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Client port........: ' ||
            NVL(TO_CHAR(r.port), 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Service............: ' ||
            NVL(r.service_name, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Program............: ' ||
            NVL(r.program, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Module.............: ' ||
            NVL(r.module, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Action.............: ' ||
            NVL(r.action, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Client identifier..: ' ||
            NVL(r.client_identifier, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Session status.....: ' ||
            NVL(r.status, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Logon time.........: ' ||
            TO_CHAR(
                r.logon_time,
                'YYYY-MM-DD HH24:MI:SS'
            )
        );

        DBMS_OUTPUT.PUT_LINE(
            'Last call..........: ' ||
            format_seconds(r.last_call_et) ||
            ' (' ||
            r.last_call_et ||
            ' seconds)'
        );

        DBMS_OUTPUT.PUT_LINE(
            'Current event......: ' ||
            NVL(r.event, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Wait class.........: ' ||
            NVL(r.wait_class, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Wait state.........: ' ||
            NVL(r.state, 'N/D')
        );

        DBMS_OUTPUT.PUT_LINE(
            'Trace file.........: ' ||
            NVL(r.tracefile, 'N/D')
        );

        ------------------------------------------------------------------------
        -- IMPACT
        ------------------------------------------------------------------------
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.NEW_LINE;
        DBMS_OUTPUT.PUT_LINE('#IMPACT#');
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);

        DBMS_OUTPUT.PUT_LINE(
            'Blocked sessions...: ' ||
            r.total_blocked_sessions
        );

        DBMS_OUTPUT.PUT_LINE(
            'Long-wait sessions.: ' ||
            r.long_wait_sessions ||
            ' sessions >= ' ||
            c_min_wait_seconds ||
            ' seconds'
        );

        DBMS_OUTPUT.PUT_LINE(
            'Maximum wait.......: ' ||
            format_seconds(
                r.maximum_wait_seconds
            ) ||
            ' (' ||
            r.maximum_wait_seconds ||
            ' seconds)'
        );

        ------------------------------------------------------------------------
        -- SQL
        ------------------------------------------------------------------------
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.NEW_LINE;
        DBMS_OUTPUT.PUT_LINE('#SQL#');
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);

        DECLARE
            l_root_sql_id   VARCHAR2(13);
            l_root_sql_text VARCHAR2(4000);
        BEGIN
            l_root_sql_id :=
                COALESCE(
                    r.sql_id,
                    r.prev_sql_id
                );

            l_root_sql_text :=
                get_sql_text(
                    r.root_inst_id,
                    l_root_sql_id
                );

            DBMS_OUTPUT.PUT_LINE(
                'SQL ID.............: ' ||
                NVL(l_root_sql_id, 'N/D') ||
                CASE
                    WHEN r.sql_id IS NOT NULL
                    THEN ' [CURRENT SQL]'

                    WHEN r.prev_sql_id IS NOT NULL
                    THEN ' [PREVIOUS SQL]'

                    ELSE NULL
                END
            );

            print_sql(
                'SQL text...........: ',
                l_root_sql_text
            );
        END;

        ------------------------------------------------------------------------
        -- TRANSACTION
        ------------------------------------------------------------------------
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);
        DBMS_OUTPUT.NEW_LINE;
        DBMS_OUTPUT.PUT_LINE('#TRANSACTION#');
        --DBMS_OUTPUT.PUT_LINE(c_subseparator);

        IF r.transaction_start_date IS NOT NULL THEN
            DBMS_OUTPUT.PUT_LINE(
                'Transaction status.: ' ||
                NVL(r.transaction_status, 'N/D')
            );

            DBMS_OUTPUT.PUT_LINE(
                'Transaction start..: ' ||
                TO_CHAR(
                    r.transaction_start_date,
                    'YYYY-MM-DD HH24:MI:SS'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Transaction age....: ' ||
                format_seconds(
                    (
                        SYSDATE -
                        r.transaction_start_date
                    ) * 86400
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Transaction SCN....: ' ||
                NVL(
                    TO_CHAR(r.start_scn),
                    'N/D'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Undo blocks........: ' ||
                NVL(
                    TO_CHAR(r.used_ublk),
                    '0'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Undo records.......: ' ||
                NVL(
                    TO_CHAR(r.used_urec),
                    '0'
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Undo block size....: ' ||
                format_bytes(r.block_size)
            );

            DBMS_OUTPUT.PUT_LINE(
                'Approx. undo size..: ' ||
                format_bytes(
                    r.approximate_undo_bytes
                )
            );

            DBMS_OUTPUT.PUT_LINE(
                'Rollback indicator.: ' ||
                rollback_risk(r.used_ublk)
            );
        ELSE
            DBMS_OUTPUT.PUT_LINE(
                'Transaction........: ' ||
                'not found in GV$TRANSACTION'
            );

            DBMS_OUTPUT.PUT_LINE(
                'Rollback indicator.: NONE / UNKNOWN'
            );
        END IF;

------------------------------------------------------------------------
-- KILL COMMAND FOR REVIEW
------------------------------------------------------------------------
DBMS_OUTPUT.NEW_LINE;
DBMS_OUTPUT.PUT_LINE('#KILL COMMAND#');

DBMS_OUTPUT.PUT_LINE(
    'WARNING: validate application owner, transaction size,'
);

DBMS_OUTPUT.PUT_LINE(
    'rollback impact and business criticality before execution.'
);

DBMS_OUTPUT.NEW_LINE;

IF g_is_aws_rds THEN

    DBMS_OUTPUT.PUT_LINE(
        'Kill mechanism.....: AWS RDSADMIN package'
    );

    DBMS_OUTPUT.NEW_LINE;

    DBMS_OUTPUT.PUT_LINE('BEGIN');

    DBMS_OUTPUT.PUT_LINE(
        '   rdsadmin.rdsadmin_util.kill('
    );

    DBMS_OUTPUT.PUT_LINE(
        '      sid    => ' || r.root_sid || ','
    );

    DBMS_OUTPUT.PUT_LINE(
        '      serial => ' || r.serial# || ','
    );

    DBMS_OUTPUT.PUT_LINE(
        '      method => ''IMMEDIATE'''
    );

    DBMS_OUTPUT.PUT_LINE(
        '   );'
    );

    DBMS_OUTPUT.PUT_LINE('END;');
    DBMS_OUTPUT.PUT_LINE('/');

ELSE

    DBMS_OUTPUT.PUT_LINE(
        'Kill mechanism.....: ALTER SYSTEM KILL SESSION'
    );

    DBMS_OUTPUT.NEW_LINE;

    DBMS_OUTPUT.PUT_LINE(
        'ALTER SYSTEM KILL SESSION ''' ||
        r.root_sid ||
        ',' ||
        r.serial# ||
        ',@' ||
        r.root_inst_id ||
        ''' IMMEDIATE;'
    );

END IF;
     

        ------------------------------------------------------------------------
        -- WAIT CHAIN
        ------------------------------------------------------------------------
        DBMS_OUTPUT.PUT_LINE(
            CHR(10) || c_separator
        );

        DBMS_OUTPUT.PUT_LINE(
            'CHAIN #' ||
            g_chain_number ||
            ' - WAIT CHAIN'
        );

        DBMS_OUTPUT.PUT_LINE(c_separator);

        DBMS_OUTPUT.PUT_LINE(
            '[ROOT] [INST ' ||
            r.root_inst_id ||
            '] ' ||
            r.instance_name ||
            ':' ||
            r.root_sid ||
            ',' ||
            r.serial# ||
            ' | USER=' ||
            NVL(r.username, '[BACKGROUND]') ||
            ' | STATUS=' ||
            NVL(r.status, 'N/D') ||
            ' | BLOCKED=' ||
            r.total_blocked_sessions
        );

        print_wait_chain(
            p_blocker_inst_id => r.root_inst_id,
            p_blocker_sid     => r.root_sid,
            p_depth           => 1
        );
    END LOOP;

    ----------------------------------------------------------------------------
    -- REPORT FOOTER
    ----------------------------------------------------------------------------
    DBMS_OUTPUT.PUT_LINE(
        CHR(10) || c_separator
    );

    DBMS_OUTPUT.PUT_LINE('END OF REPORT');

    DBMS_OUTPUT.PUT_LINE(
        'Total blocking chains reported: ' ||
        g_chain_count
    );

    DBMS_OUTPUT.PUT_LINE(c_separator);
END;
/