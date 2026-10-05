#!/bin/bash
# Author: Pedro Vido - https://pedrovidodba.blogspot.com  -- 26/09/2026
#
# oracle_diag_cleanup.sh --> Rotaciona alert log e remove traces antigos
#
# History :
#
# 26/09/2026 - Pedro Vido - Configuracao de ORACLE_BASE
#                         - Configuracao de ORACLE_LISTENER
#                         - Rotaciona Alert log
#                         - Rotaciona listener log
#                         - Limpa .aud, .trc, .trm com base no ORACLE_BASE
#                         - Limpa Alerts Logs rotacionados mais velhos que 10 dias
#                         - Limpa Listeners logs rotacionados mais velhos que 10 dias
#
#
#
#
#                           
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#
#

#####################################################
# CONFIGURACOES
#####################################################

RETENTION_DAYS=10

DATE=$(date +%Y%m%d_%H%M%S)
  
ORACLE_BASE=/u01/app/oracle
ORACLE_LIST=/u01/app/oracle/diag/tnslsnr

LOGFILE=/var/log/oracle_diag_cleanup.${DATE}.log

#####################################################
# LOG - EXECUCAO
#####################################################

exec >> ${LOGFILE} 2>&1

echo "=================================================="
echo "Inicio: $(date)"
echo "=================================================="

#####################################################
# PROCURA ALERT LOG - ORACLE BASE
#####################################################

find ${ORACLE_BASE} \
    -type f \
    -name "alert_*.log" |
while read ALERT
do

    echo ""
    echo "Processando ${ALERT}"

    ALERT_BACKUP=${ALERT}.${DATE}

    #################################################
    # ROTATE ALERT LOG
    #################################################

    cp "${ALERT}" "${ALERT_BACKUP}"

    if [ $? -eq 0 ]
    then
        gzip "${ALERT_BACKUP}"

        : > "${ALERT}"

        echo "Alert log rotacionado:"
        echo "  ${ALERT_BACKUP}.gz"
    else
        echo "ERRO copiando ${ALERT}"
        continue
    fi

done

#####################################################
# PROCURA LISTENER LOGS
#####################################################

find ${ORACLE_LIST} \
    -type f \
    -name "listener.log" |
while read LISTENER
do

    echo ""
    echo "Processando ${LISTENER}"

    LISTENER_BACKUP=${LISTENER}.${DATE}

    #################################################
    # ROTATE LISTENER LOG
    #################################################

    cp "${LISTENER}" "${LISTENER_BACKUP}"

    if [ $? -eq 0 ]
    then
        gzip "${LISTENER_BACKUP}"

        : > "${LISTENER}"

        echo "Listener log rotacionado:"
        echo "  ${LISTENER_BACKUP}.gz"
    else
        echo "ERRO copiando ${LISTENER}"
        continue
    fi

done

#####################################################
# LIMPA TRACES ANTIGOS
#####################################################

echo ""
echo "Removendo arquivos .trc com mais de ${RETENTION_DAYS} dias"

find ${ORACLE_BASE} \
    -type f \
    -name "*.trc" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete

#####################################################
# LIMPA TRM ANTIGOS
#####################################################

echo ""
echo "Removendo arquivos .trm com mais de ${RETENTION_DAYS} dias"

find ${ORACLE_BASE} \
    -type f \
    -name "*.trm" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete
	
#####################################################
# LIMPA AUDs ANTIGOS
#####################################################

echo ""
echo "Removendo arquivos .aud com mais de ${RETENTION_DAYS} dias"

find ${ORACLE_BASE} \
    -type f \
    -name "*.aud" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete	


#####################################################
# LIMPA LISTENER LOGS ANTIGOS
#####################################################

echo ""
echo "Removendo arquivos listener_X com mais de ${RETENTION_DAYS} dias"

find ${ORACLE_LIST} \
    -type f \
    -name "listener_*.log" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete	

#####################################################
# LIMPA ALERT LOG ROTACIONADOS MUITO ANTIGOS
#####################################################

echo ""
echo "Removendo alert logs rotacionados antigos"

find ${ORACLE_BASE} \
    -type f \
    -name "alert_*.log.*.gz" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete

#####################################################
# LIMPA LISTENER LOG ROTACIONADOS MUITO ANTIGOS
#####################################################

echo ""
echo "Removendo Listener logs rotacionados antigos"

find ${ORACLE_BASE} \
    -type f \
    -name "listener_*.log.*.gz" \
    -mtime +${RETENTION_DAYS} \
    -print \
    -delete


echo ""
echo "Fim: $(date)"
echo "=================================================="

exit 0
``
