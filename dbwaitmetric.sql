-- ########################################################################################################
--                                                                                                       --
-- File Name     : dbwaitmetric.sql                                                                      --
-- Description   : Displays info about CPU and Wait time                                                 --
-- Comments      : N/A                                                                                   --
-- Requirements  : Access the V$ views.                                                                  --
-- Call Syntax   : @dbwaitmetric                                                                         --
-- Last Modified : 23/10/2025                                                                            --
-- Author        : Pedro Vido - pedro.carvalho.vido@accenture.com                                        --
--                                                                                                       --
-- ########################################################################################################

--=====================================
-- DB CPU vs. Wait time
--=====================================

SELECT METRIC_NAME, VALUE, METRIC_UNIT
FROM V$SYSMETRIC
WHERE METRIC_NAME IN ('Database CPU Time Ratio','Database Wait Time Ratio')
  AND INTSIZE_CSEC = (SELECT MAX(INTSIZE_CSEC) FROM V$SYSMETRIC); 


-- RAC
SELECT INST_ID, METRIC_NAME, VALUE, METRIC_UNIT
FROM GV$SYSMETRIC
WHERE METRIC_NAME IN ('Database CPU Time Ratio','Database Wait Time Ratio')
  AND INTSIZE_CSEC = (SELECT MAX(INTSIZE_CSEC) FROM GV$SYSMETRIC); 


--===========================================
-- DB CPU vs. Background CPU vs. Wait Time
--===========================================

SELECT
    ROUND(db_time        / 1e6, 2)   AS db_time_sec,
    ROUND(db_cpu         / 1e6, 2)   AS db_cpu_sec,
    ROUND(bg_cpu         / 1e6, 2)   AS background_cpu_sec,
    ROUND(db_time - db_cpu) / 1e6    AS wait_time_sec,
    ROUND(db_cpu         / NULLIF(db_time, 0) * 100, 1)   AS cpu_pct,
    ROUND((db_time - db_cpu) / NULLIF(db_time, 0) * 100, 1) AS wait_pct
FROM (
    SELECT
        SUM(CASE WHEN stat_name = 'DB time'            THEN value ELSE 0 END) AS db_time,
        SUM(CASE WHEN stat_name = 'DB CPU'             THEN value ELSE 0 END) AS db_cpu,
        SUM(CASE WHEN stat_name = 'background cpu time' THEN value ELSE 0 END) AS bg_cpu
    FROM
        v$sys_time_model
);

--===========================================
-- DB Time
--===========================================
SELECT
    stat_name,
    ROUND(value / 1e6, 2) AS seconds,
    ROUND(
        value / NULLIF(
            (SELECT value FROM v$sys_time_model WHERE stat_name = 'DB time'),
            0
        ) * 100, 2
    ) AS pct_of_db_time
FROM
    v$sys_time_model
ORDER BY
    value DESC;


--=====================================================================
-- Parse Time Analysis — Hard Parse, Failed Parse, and Bind Mismatch
--=====================================================================

SELECT
    stat_name,
    ROUND(value / 1e6, 4) AS seconds,
    ROUND(
        value / NULLIF(
            (SELECT value FROM v$sys_time_model WHERE stat_name = 'parse time elapsed'),
            0
        ) * 100, 2
    )  AS pct_of_parse_time,
    ROUND(
        value / NULLIF(
            (SELECT value FROM v$sys_time_model WHERE stat_name = 'DB time'),
            0
        ) * 100, 4
    ) AS pct_of_db_time
FROM
    v$sys_time_model
WHERE
    stat_name IN (
        'parse time elapsed',
        'hard parse elapsed time',
        'hard parse (sharing criteria) elapsed time',
        'hard parse (bind mismatch) elapsed time',
        'failed parse elapsed time',
        'failed parse (out of shared memory) elapsed time'
    )
ORDER BY
    value DESC;


