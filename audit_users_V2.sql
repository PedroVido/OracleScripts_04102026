-- ########################################################################################################
--                                                                                                       -- 
-- File Name     : audit_users.sql                                                                       --
-- Description   : Displays info of users                                                                --
-- Comments      : Display info about user: last_login, qtd Object for non Oracle Users                  --
--               : --> Show users tha never connects (Last_login is NUll)                                --
--               : --> Validacao e criacao de diretorio                                                  --
--               : --> Show users with super privileges                                                  --
-- Requirements  : Access to the DBA views.                                                              --
-- Call Syntax   : @audit_users                                                                          --
-- Last Modified : 26/09/2026                                                                            --
-- Author        : Pedro Vido - https://pedrovidodba.blogspot.com                                        --
--                                                                                                       --
-- ########################################################################################################

--=====================================================
-- Query Base
--=====================================================
/*

SELECT
u.username,
u.account_status,
u.created,
u.last_login,
u.oracle_maintained,
COUNT(o.object_name) qtd_objetos
FROM dba_users u
LEFT JOIN dba_objects o
ON o.owner = u.username
WHERE u.oracle_maintained = 'N'
and (u.last_login >=sysdate-360 or u.last_login is null)
GROUP BY
u.username,
u.account_status,
u.created,
u.last_login,
u.oracle_maintained
HAVING COUNT(o.object_name) = 0
ORDER BY u.last_login;

*/
--=====================================================
-- Bloco PL que gera o HTML 
--=====================================================

-- PRE REQUES
/*
CREATE OR REPLACE DIRECTORY AUDIT_DIR AS '/u01/reports';
*/

SET SERVEROUTPUT ON SIZE UNLIMITED;
set define off;
set verify off;

DECLARE
    ---------------------------------------------------------------------------
    -- Configurações do relatório
    ---------------------------------------------------------------------------
    c_directory_name CONSTANT VARCHAR2(30)  := 'AUDIT_DIR';
    c_file_name      CONSTANT VARCHAR2(255) := 'auditoria_usuarios_privilegios.html';

    ---------------------------------------------------------------------------
    -- Variáveis
    ---------------------------------------------------------------------------
    v_file             UTL_FILE.FILE_TYPE;
    v_dias_sem_login   NUMBER;
    v_cor              VARCHAR2(20);
    v_classificacao    VARCHAR2(100);
    v_instance_name    VARCHAR2(128);
    v_total_registros  PLS_INTEGER := 0;
    v_total_verdes     PLS_INTEGER := 0;
    v_total_laranjas   PLS_INTEGER := 0;
    v_total_privilegios PLS_INTEGER := 0;
    v_total_criticos    PLS_INTEGER := 0;
    v_total_altos       PLS_INTEGER := 0;
    v_total_medios      PLS_INTEGER := 0;
	v_directory_name VARCHAR2(30) := 'AUDIT_DIR';
    v_directory_path VARCHAR2(500) := '/u01/reports';
    v_count NUMBER;

    ---------------------------------------------------------------------------
    -- Obtém o nome da instância Oracle atual
    --
    -- Em ambiente RAC, retorna a instância na qual a sessão está conectada.
    ---------------------------------------------------------------------------
    PROCEDURE get_instance_name(
        p_instance_name OUT VARCHAR2
    )
    IS
    BEGIN
        p_instance_name :=
            SYS_CONTEXT(
                'USERENV',
                'INSTANCE_NAME'
            );

        IF p_instance_name IS NULL THEN
            p_instance_name := 'INSTANCIA_NAO_IDENTIFICADA';
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            p_instance_name := 'ERRO_AO_IDENTIFICAR_INSTANCIA';
    END get_instance_name;


    ---------------------------------------------------------------------------
    -- Validacao de diretorio para geracao de relatorio
    --
    -- Valida sej a existe, senao cria
    ---------------------------------------------------------------------------
BEGIN
SELECT COUNT(*)
INTO v_count
FROM dba_directories
WHERE directory_name = UPPER(v_directory_name);
IF v_count > 0 THEN
DBMS_OUTPUT.PUT_LINE(
'Diretorio ' || UPPER(v_directory_name) || ' ja existe.'
);
ELSE
EXECUTE IMMEDIATE
'CREATE OR REPLACE DIRECTORY '
|| UPPER(v_directory_name)
|| ' AS '''
|| v_directory_path
|| '''';
DBMS_OUTPUT.PUT_LINE(
'Diretorio ' || UPPER(v_directory_name)
|| ' criado com sucesso em '
|| v_directory_path
);
END IF;
EXCEPTION
WHEN OTHERS THEN
DBMS_OUTPUT.PUT_LINE(
'ERRO: ' || SQLCODE || ' - ' || SQLERRM
);
RAISE;
END;
    ---------------------------------------------------------------------------
    -- Fecha o arquivo sem mascarar o erro principal
    ---------------------------------------------------------------------------
    PROCEDURE close_file_safe(
        p_file IN OUT NOCOPY UTL_FILE.FILE_TYPE
    )
    IS
    BEGIN
        IF UTL_FILE.IS_OPEN(p_file) THEN
            UTL_FILE.FCLOSE(p_file);
        END IF;

    EXCEPTION
        WHEN OTHERS THEN
            DBMS_OUTPUT.PUT_LINE(
                'AVISO: não foi possível fechar o arquivo: '
                || SQLCODE || ' - ' || SQLERRM
            );
    END close_file_safe;

    ---------------------------------------------------------------------------
    -- Escapa caracteres reservados do HTML e caracteres acentuados
    --
    -- Importante:
    -- O caractere "&" precisa ser tratado antes da criação das entidades HTML.
    ---------------------------------------------------------------------------
  
    FUNCTION html_escape(
        p_text IN VARCHAR2
    ) RETURN VARCHAR2
    IS
        l_text VARCHAR2(32767);
    BEGIN
        IF p_text IS NULL THEN
            RETURN '';
        END IF;

        l_text := p_text;

        -----------------------------------------------------------------------
        -- Caracteres reservados do HTML
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, '&',   '&amp;');
        l_text := REPLACE(l_text, '<',   '&lt;');
        l_text := REPLACE(l_text, '>',   '&gt;');
        l_text := REPLACE(l_text, '"',   '&quot;');
        l_text := REPLACE(l_text, '''',  '&#39;');

        -----------------------------------------------------------------------
        -- Letra A
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'á', '&aacute;');
        l_text := REPLACE(l_text, 'à', '&agrave;');
        l_text := REPLACE(l_text, 'ã', '&atilde;');
        l_text := REPLACE(l_text, 'â', '&acirc;');
        l_text := REPLACE(l_text, 'ä', '&auml;');

        l_text := REPLACE(l_text, 'Á', '&Aacute;');
        l_text := REPLACE(l_text, 'À', '&Agrave;');
        l_text := REPLACE(l_text, 'Ã', '&Atilde;');
        l_text := REPLACE(l_text, 'Â', '&Acirc;');
        l_text := REPLACE(l_text, 'Ä', '&Auml;');

        -----------------------------------------------------------------------
        -- Letra E
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'é', '&eacute;');
        l_text := REPLACE(l_text, 'è', '&egrave;');
        l_text := REPLACE(l_text, 'ê', '&ecirc;');
        l_text := REPLACE(l_text, 'ë', '&euml;');

        l_text := REPLACE(l_text, 'É', '&Eacute;');
        l_text := REPLACE(l_text, 'È', '&Egrave;');
        l_text := REPLACE(l_text, 'Ê', '&Ecirc;');
        l_text := REPLACE(l_text, 'Ë', '&Euml;');

        -----------------------------------------------------------------------
        -- Letra I
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'í', '&iacute;');
        l_text := REPLACE(l_text, 'ì', '&igrave;');
        l_text := REPLACE(l_text, 'î', '&icirc;');
        l_text := REPLACE(l_text, 'ï', '&iuml;');

        l_text := REPLACE(l_text, 'Í', '&Iacute;');
        l_text := REPLACE(l_text, 'Ì', '&Igrave;');
        l_text := REPLACE(l_text, 'Î', '&Icirc;');
        l_text := REPLACE(l_text, 'Ï', '&Iuml;');

        -----------------------------------------------------------------------
        -- Letra O
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'ó', '&oacute;');
        l_text := REPLACE(l_text, 'ò', '&ograve;');
        l_text := REPLACE(l_text, 'õ', '&otilde;');
        l_text := REPLACE(l_text, 'ô', '&ocirc;');
        l_text := REPLACE(l_text, 'ö', '&ouml;');

        l_text := REPLACE(l_text, 'Ó', '&Oacute;');
        l_text := REPLACE(l_text, 'Ò', '&Ograve;');
        l_text := REPLACE(l_text, 'Õ', '&Otilde;');
        l_text := REPLACE(l_text, 'Ô', '&Ocirc;');
        l_text := REPLACE(l_text, 'Ö', '&Ouml;');

        -----------------------------------------------------------------------
        -- Letra U
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'ú', '&uacute;');
        l_text := REPLACE(l_text, 'ù', '&ugrave;');
        l_text := REPLACE(l_text, 'û', '&ucirc;');
        l_text := REPLACE(l_text, 'ü', '&uuml;');

        l_text := REPLACE(l_text, 'Ú', '&Uacute;');
        l_text := REPLACE(l_text, 'Ù', '&Ugrave;');
        l_text := REPLACE(l_text, 'Û', '&Ucirc;');
        l_text := REPLACE(l_text, 'Ü', '&Uuml;');

        -----------------------------------------------------------------------
        -- Cedilha e outros caracteres
        -----------------------------------------------------------------------
        l_text := REPLACE(l_text, 'ç', '&ccedil;');
        l_text := REPLACE(l_text, 'Ç', '&Ccedil;');
        l_text := REPLACE(l_text, 'ñ', '&ntilde;');
        l_text := REPLACE(l_text, 'Ñ', '&Ntilde;');

        RETURN l_text;

    EXCEPTION
        WHEN OTHERS THEN
            RETURN '[ERRO AO CONVERTER TEXTO]';
    END html_escape;



    ---------------------------------------------------------------------------
    -- Grava uma linha no arquivo
    ---------------------------------------------------------------------------
    PROCEDURE write_line(
        p_text IN VARCHAR2
    )
    IS
    BEGIN
        UTL_FILE.PUT_LINE(v_file, p_text);
    END write_line;

BEGIN
    ---------------------------------------------------------------------------
    -- Obtém o nome da instância antes da geração do relatório
    ---------------------------------------------------------------------------
    get_instance_name(v_instance_name);

    ---------------------------------------------------------------------------
    -- Abre o arquivo para gravação
    ---------------------------------------------------------------------------
    v_file := UTL_FILE.FOPEN(
        location     => c_directory_name,
        filename     => c_file_name,
        open_mode    => 'W',
        max_linesize => 32767
    );


    ---------------------------------------------------------------------------
    -- Cabeçalho do HTML
    ---------------------------------------------------------------------------
    write_line('<!DOCTYPE html>');
    write_line('<html lang="pt-BR">');
    write_line('<head>');
    write_line('<meta charset="UTF-8">');
    write_line('<meta name="viewport" content="width=device-width, initial-scale=1.0">');
    write_line('<title>Auditoria de Usuarios e Privilegios Oracle</title>');

    write_line(q'~
<style>
    body {
        margin: 24px;
        background-color: #f4f6f8;
        color: #263238;
        font-family: Arial, Helvetica, sans-serif;
        font-size: 13px;
    }

    h1 {
        margin-bottom: 5px;
        color: #1f4e78;
    }

    .subtitulo {
        margin-top: 0;
        color: #5f6b73;
    }

    .legenda {
        margin: 18px 0;
        padding: 12px;
        background-color: #ffffff;
        border: 1px solid #d9e1e8;
        border-radius: 6px;
    }

    .item-legenda {
        display: inline-block;
        margin-right: 24px;
    }

    .marcador {
        display: inline-block;
        width: 14px;
        height: 14px;
        margin-right: 6px;
        border: 1px solid #999999;
        vertical-align: middle;
    }

    .verde {
        background-color: #c6efce;
    }

    .laranja {
        background-color: #fce4d6;
    }

    table {
        width: 100%;
        border-collapse: collapse;
        background-color: #ffffff;
        box-shadow: 0 1px 4px rgba(0, 0, 0, 0.12);
    }

    th {
        padding: 9px;
        background-color: #1f4e78;
        color: #ffffff;
        border: 1px solid #d0d7de;
        text-align: left;
    }

    td {
        padding: 8px;
        border: 1px solid #d0d7de;
    }

    tr:hover td {
        filter: brightness(96%);
    }

    .rodape {
        margin-top: 16px;
        color: #5f6b73;
        font-size: 12px;
    }
</style>
~');

    write_line('</head>');
    write_line('<body>');

    write_line(
        '<h1>'
        || html_escape('Auditoria de Usuários - Nao Gerenciados pelo Oracle - ')
        || v_instance_name
        || '</h1>'
    );

    write_line(
        '<p class="subtitulo">'
        || html_escape('Data de coleta: ')
        || TO_CHAR(SYSDATE, 'DD/MM/YYYY HH24:MI:SS')
        || '</p>'
    );

    ---------------------------------------------------------------------------
    -- Legenda
    ---------------------------------------------------------------------------
    write_line('<div class="legenda">');

    write_line(
        '<span class="item-legenda">'
        || '<span class="marcador verde"></span>'
        || html_escape('Conta OPEN com login há menos de 1 dia')
        || '</span>'
    );

    write_line(
        '<span class="item-legenda">'
        || '<span class="marcador laranja"></span>'
        || html_escape('Demais contas')
        || '</span>'
    );

    write_line('</div>');

    ---------------------------------------------------------------------------
    -- Cabeçalho da tabela
    ---------------------------------------------------------------------------
    write_line('<table>');
    write_line('<thead>');
    write_line('<tr>');
    write_line('<th>' || html_escape('Usuário') || '</th>');
    write_line('<th>Status</th>');
    write_line('<th>' || html_escape('Criado em') || '</th>');
    write_line('<th>' || html_escape('Último login') || '</th>');
    write_line('<th>' || html_escape('Dias sem login') || '</th>');
    write_line('<th>' || html_escape('Oracle Maintained') || '</th>');
    write_line('<th>' || html_escape('Qtd. objetos') || '</th>');
    write_line('<th>' || html_escape('Classificação') || '</th>');
    write_line('</tr>');
    write_line('</thead>');
    write_line('<tbody>');


    ---------------------------------------------------------------------------
    -- Consulta principal
    ---------------------------------------------------------------------------
    FOR r IN (
        SELECT
            u.username,
            u.account_status,
            u.created,
            u.last_login,
            u.oracle_maintained,
            COUNT(o.object_name) AS qtd_objetos
        FROM dba_users u
        LEFT JOIN dba_objects o
               ON o.owner = u.username
        WHERE u.oracle_maintained = 'N'
          AND (
                u.last_login >= SYSDATE - 360
                OR u.last_login IS NULL
              )
        GROUP BY
            u.username,
            u.account_status,
            u.created,
            u.last_login,
            u.oracle_maintained
        HAVING COUNT(o.object_name) = 0
        ORDER BY
            NVL(CAST(u.last_login AS DATE), DATE '1900-01-01'),
            u.username
    )
    LOOP
        v_total_registros := v_total_registros + 1;

        -----------------------------------------------------------------------
        -- Calcula a diferença em dias.
        -- O valor mantém casas decimais para validar "menos de 1 dia".
        -----------------------------------------------------------------------
        IF r.last_login IS NOT NULL THEN
            v_dias_sem_login :=
                SYSDATE - CAST(r.last_login AS DATE);
        ELSE
            v_dias_sem_login := NULL;
        END IF;

        -----------------------------------------------------------------------
        -- Regra de cores
        --
        -- Verde:
        --   status OPEN e último login há menos de 24 horas.
        --
        -- Laranja:
        --   todas as demais condições.
        -----------------------------------------------------------------------
        IF r.account_status = 'OPEN'
           AND v_dias_sem_login IS NOT NULL
           AND v_dias_sem_login >= 0
           AND v_dias_sem_login < 1
        THEN
            v_cor           := '#C6EFCE';
            v_classificacao := 'ATIVO - LOGIN RECENTE';
            v_total_verdes  := v_total_verdes + 1;
        ELSE
            v_cor             := '#FCE4D6';
            v_total_laranjas  := v_total_laranjas + 1;

            IF r.last_login IS NULL THEN
                v_classificacao := 'VALIDAR USO - NUNCA LOGOU';
            ELSIF r.account_status = 'OPEN' THEN
                v_classificacao := 'REVISAR - LOGIN ACIMA DE 1 DIA';
            ELSE
                v_classificacao := 'CONTA NÃO ESTÁ OPEN';
            END IF;
        END IF;

        -----------------------------------------------------------------------
        -- Linha do relatório
        -----------------------------------------------------------------------
        write_line(
              '<tr style="background-color:' || v_cor || ';">'
            || '<td>' || html_escape(r.username) || '</td>'
            || '<td>' || html_escape(r.account_status) || '</td>'
            || '<td>'
            || NVL(TO_CHAR(r.created, 'DD/MM/YYYY HH24:MI'), 'N/A')
            || '</td>'
            || '<td>'
            || CASE
                   WHEN r.last_login IS NULL THEN
                       html_escape('Nunca realizou login')
                   ELSE
                       TO_CHAR(
                           CAST(r.last_login AS DATE),
                           'DD/MM/YYYY HH24:MI:SS'
                       )
               END
            || '</td>'
            || '<td>'
            || CASE
                   WHEN v_dias_sem_login IS NULL THEN
                       'N/A'
                   WHEN v_dias_sem_login < 1 THEN
                       TO_CHAR(
                           ROUND(v_dias_sem_login * 24, 2),
                           'FM999999990D00',
                           'NLS_NUMERIC_CHARACTERS='',.'''
                       ) || ' hora(s)'
                   ELSE
                       TO_CHAR(TRUNC(v_dias_sem_login))
               END
            || '</td>'
            || '<td>' || TO_CHAR(r.oracle_maintained) || '</td>'
            || '<td>' || TO_CHAR(r.qtd_objetos) || '</td>'
            || '<td>' || html_escape(v_classificacao) || '</td>'
            || '</tr>'
        );

    END LOOP;


--    write_line('</tbody></table></div>');
--    write_line('<div class="summary"><b>'
--	||html_escape('Resumo da Lista 1')||'</b><br>'
--	||html_escape('Total de usuários: ')
--	||v_total_users||' | '
--	||html_escape('Verdes: ')
--	||v_green_users||' | '
--	||html_escape('Laranjas: ')
--	||v_orange_users||'</div>');

      write_line('</tbody></table>');
      write_line('</p class="summary"><b>'
        || html_escape('Total de registros: ')
        || TO_CHAR(v_total_registros)
        || ' | '
        || html_escape('Verdes: ')
        || TO_CHAR(v_total_verdes)
        || ' | '
        || html_escape('Laranjas: ')
        || TO_CHAR(v_total_laranjas)
        || '</p>'
    );

    ---------------------------------------------------------------------------
    -- Finaliza tabela e HTML
    ---------------------------------------------------------------------------
    write_line('</tbody>');
    write_line('</table>');

    ---------------------------------------------------------------------------
    -- Segunda secao: DBA, privilegios equivalentes, SYSDBA e SYSOPER
    ---------------------------------------------------------------------------
    write_line('<br><h2>Auditoria de Privilegios Administrativos</h2>');
    write_line('<div class="legenda">');
    write_line('<span class="item-legenda"><span class="marcador" style="background:#FFB3B3"></span>' || html_escape('CRITICO: DBA, SYSDBA ou SYSOPER') || '</span>');
    write_line('<span class="item-legenda"><span class="marcador" style="background:#FFD966"></span>' || html_escape('ALTO: administracao, concessao, usuarios ou dicionario') || '</span>');
    write_line('<span class="item-legenda"><span class="marcador" style="background:#D9EAD3"></span>' || html_escape('MEDIO: demais privilegios amplos') || '</span>');
    write_line('</div>');
    write_line('<table><thead><tr>');
    write_line('<th>' || html_escape('Usuario') || '</th><th>Status</th><th>' || html_escape('Criado em') || '</th>');
    write_line('<th>' || html_escape('Ultimo login') || '</th><th>Origem</th><th>' || html_escape('Privilegio') || '</th>');
    write_line('<th>Admin Option</th><th>Default Role</th><th>Criticidade</th>');
    write_line('</tr></thead><tbody>');

    FOR p IN (
        WITH dba_equiv AS (
            SELECT grantee, 'ROLE_DBA' origem, granted_role privilegio,
                   admin_option, default_role
              FROM dba_role_privs
             WHERE granted_role = 'DBA'
            UNION ALL
            SELECT grantee, 'SYS_PRIV', privilege, admin_option,
                   CAST(NULL AS VARCHAR2(3))
              FROM dba_sys_privs
             WHERE privilege IN (
                'SELECT ANY TABLE','INSERT ANY TABLE','UPDATE ANY TABLE','DELETE ANY TABLE',
                'EXECUTE ANY PROCEDURE','ALTER SYSTEM','ALTER DATABASE','CREATE ANY TABLE',
                'DROP ANY TABLE','CREATE ANY PROCEDURE','DROP ANY PROCEDURE','CREATE USER',
                'ALTER USER','DROP USER','GRANT ANY PRIVILEGE','GRANT ANY ROLE','BECOME USER',
                'CREATE ANY DIRECTORY','DROP ANY DIRECTORY','SELECT ANY DICTIONARY')
            UNION ALL
            SELECT username, 'PWFILE', 'SYSDBA',
                   CAST(NULL AS VARCHAR2(3)), CAST(NULL AS VARCHAR2(3))
              FROM v$pwfile_users
             WHERE sysdba = 'TRUE'
            UNION ALL
            SELECT username, 'PWFILE', 'SYSOPER',
                   CAST(NULL AS VARCHAR2(3)), CAST(NULL AS VARCHAR2(3))
              FROM v$pwfile_users
             WHERE sysoper = 'TRUE'
        )
        SELECT DISTINCT u.username, u.account_status, u.created, u.last_login,
               d.origem, d.privilegio, d.admin_option, d.default_role
          FROM dba_users u
          JOIN dba_equiv d ON d.grantee = u.username
         WHERE u.oracle_maintained = 'N'
           AND u.username NOT IN ('A_RAIABD','OGGADM','SYSTEM','USR_ZABBIX')
         ORDER BY u.username, d.origem, d.privilegio
    ) LOOP
        v_total_privilegios := v_total_privilegios + 1;
        IF p.privilegio IN ('DBA','SYSDBA','SYSOPER') THEN
            v_cor := '#FFB3B3'; v_classificacao := 'CRITICO';
            v_total_criticos := v_total_criticos + 1;
        ELSIF p.privilegio IN (
            'GRANT ANY PRIVILEGE','GRANT ANY ROLE','ALTER SYSTEM','ALTER DATABASE',
            'SELECT ANY DICTIONARY','BECOME USER','CREATE USER','ALTER USER','DROP USER') THEN
            v_cor := '#FFD966'; v_classificacao := 'ALTO';
            v_total_altos := v_total_altos + 1;
        ELSE
            v_cor := '#D9EAD3'; v_classificacao := 'MEDIO';
            v_total_medios := v_total_medios + 1;
        END IF;

        write_line('<tr style="background-color:' || v_cor || ';">'
          || '<td>' || html_escape(p.username) || '</td>'
          || '<td>' || html_escape(p.account_status) || '</td>'
          || '<td>' || NVL(TO_CHAR(p.created,'DD/MM/YYYY HH24:MI'),'N/A') || '</td>'
          || '<td>' || CASE WHEN p.last_login IS NULL THEN html_escape('Nunca realizou login')
                            ELSE TO_CHAR(CAST(p.last_login AS DATE),'DD/MM/YYYY HH24:MI:SS') END || '</td>'
          || '<td>' || html_escape(p.origem) || '</td>'
          || '<td>' || html_escape(p.privilegio) || '</td>'
          || '<td>' || html_escape(NVL(p.admin_option,'N/A')) || '</td>'
          || '<td>' || html_escape(NVL(p.default_role,'N/A')) || '</td>'
          || '<td><b>' || html_escape(v_classificacao) || '</b></td></tr>');
    END LOOP;

    write_line('</tbody></table>');
    write_line('<p class="summary"><b>' || html_escape('Resumo de privilegios: ') || '</b>'
      || html_escape('Total de concessoes: ') || v_total_privilegios || ' | '
      || html_escape('Criticas: ') || v_total_criticos || ' | '
      || html_escape('Altas: ') || v_total_altos || ' | '
      || html_escape('Medias: ') || v_total_medios || '</p>');

--    write_line(
--        '<p class="rodape">'
--        || html_escape('Total de registros: ')
--        || TO_CHAR(v_total_registros)
--        || ' | '
--        || html_escape('Verdes: ')
--        || TO_CHAR(v_total_verdes)
--        || ' | '
--        || html_escape('Laranjas: ')
--        || TO_CHAR(v_total_laranjas)
--        || '</p>'
--    );

    write_line('</body>');
    write_line('</html>');

    ---------------------------------------------------------------------------
    -- FLUSH explícito para detectar problemas antes do fechamento
    ---------------------------------------------------------------------------
    UTL_FILE.FFLUSH(v_file);

    ---------------------------------------------------------------------------
    -- Fechamento seguro
    ---------------------------------------------------------------------------
    close_file_safe(v_file);

    DBMS_OUTPUT.PUT_LINE(
        'Arquivo "' || c_file_name || '" gerado com sucesso no DIRECTORY '
        || c_directory_name || '.'
    );

    DBMS_OUTPUT.PUT_LINE(
        'Total de registros: ' || v_total_registros
        || ' | Verdes: ' || v_total_verdes
        || ' | Laranjas: ' || v_total_laranjas
    );

EXCEPTION
    WHEN OTHERS THEN
        DECLARE
            l_error_code    NUMBER         := SQLCODE;
            l_error_message VARCHAR2(4000) := SQLERRM;
            l_backtrace     VARCHAR2(4000) :=
                DBMS_UTILITY.FORMAT_ERROR_BACKTRACE;
        BEGIN
            -------------------------------------------------------------------
            -- Tenta registrar o erro no HTML, caso o arquivo continue válido.
            -- Se a própria gravação falhar, o erro é ignorado para preservar
            -- o erro original.
            -------------------------------------------------------------------
            BEGIN
                IF UTL_FILE.IS_OPEN(v_file) THEN
                    UTL_FILE.PUT_LINE(
                        v_file,
                          '<tr style="background-color:#FCE4D6;">'
                        || '<td colspan="9">'
                        || html_escape(
                               'Erro durante a geração do relatório: '
                               || l_error_code || ' - ' || l_error_message
                           )
                        || '</td>'
                        || '</tr>'
                    );

                    UTL_FILE.PUT_LINE(v_file, '</tbody>');
                    UTL_FILE.PUT_LINE(v_file, '</table>');
                    UTL_FILE.PUT_LINE(v_file, '</body>');
                    UTL_FILE.PUT_LINE(v_file, '</html>');

                    UTL_FILE.FFLUSH(v_file);
                END IF;
            EXCEPTION
                WHEN OTHERS THEN
                    NULL;
            END;

            -------------------------------------------------------------------
            -- Fecha o arquivo mesmo se a gravação anterior tiver falhado
            -------------------------------------------------------------------
            close_file_safe(v_file);

            DBMS_OUTPUT.PUT_LINE(
                'ERRO AO GERAR O RELATÓRIO: '
                || l_error_code || ' - ' || l_error_message
            );

            DBMS_OUTPUT.PUT_LINE(
                'BACKTRACE: ' || l_backtrace
            );

            -------------------------------------------------------------------
            -- Repropaga o erro original para o chamador/job detectar falha
            -------------------------------------------------------------------
            RAISE_APPLICATION_ERROR(
                -20001,
                SUBSTR(
                    'Falha ao gerar o arquivo HTML. Erro original: '
                    || l_error_code || ' - ' || l_error_message,
                    1,
                    2048
                )
            );
        END;
END;
/