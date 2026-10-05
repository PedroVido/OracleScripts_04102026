-- Linux Usefull Commands

--===================================
-- Creating a Symbolic Link
--===================================

Step 1: Open Terminal Navigate to the directory where you want the symlink to be created.
Step 2: Use the ln Command with -s Option The basic syntax is:
ln -s [target] [link_name]

target → The existing file or directory you want to link to.

link_name → The name of the symbolic link.

Example – Link to a File:

ln -s /path/to/original/file.txt my_link.txt

Example – Link to a Directory:

ln -s /mnt/data/projects ~/projects_link

--===============================
--Overwriting an Existing Symlink
--===============================

If a symlink with the same name already exists, use the -f option:

ln -sf /path/to/new_target existing_link

--======================
--Verifying the Symlink
--======================

To confirm creation and see where it points:

ls -l my_link.txt

You’ll see output like:

lrwxrwxrwx 1 user user 12 Feb 10 10:00 my_link.txt -> file.txt

The leading l indicates it’s a link, and -> shows the target.

--======================
--Removing a Symlink
--======================

You can delete it without affecting the target file:

rm my_link.txt
or
unlink my_link.txt

--===========================
--Tips & Best Practices
--===========================

Avoid creating symlinks to non-existent targets unless intentional, as they will be broken links.

To find broken symlinks:

find ~ -type l ! -exec test -e {} \; -print

Permissions on symlinks are always shown as 777, but actual access depends on the target’s permissions.
This method works across all major Linux distributions and is the most efficient way to create symbolic links.


--===================================
-- Zipando Arquivos TAR
--===================================

-- Compactando Dir/Arquivo
tar -zcvf LOG.tar.gz LOG

-- Descompactando Dir
tar -xvf LOG.tar.gz

-- Descompactando arquivo 
tar -xf nome_do_arquivo.tar
tar -xf nome_do_arquivo.tar.gz
tar -xvf nome_do_arquivo.tar.gz --<-- ver os arquivos sendo extraídos
tar -xf nome_do_arquivo.tar.gz -C /caminho/para/o/diretorio_destino --<-- extrair o arquivo para um diretório específico



--===============================
-- Expurgando arquivos 
--===============================

-- Deletando logs de Backup
find . -name "*.log" -mtime +5 -exec rm -rf {} \;

-- Deletando logs de Banco 
 find /u01/app/grid/11.2.0/log/diag/tnslsnr/RSARIOSRVRACPRD001/listener_scan2/alert -ctime +1 -exec rm -rf "{}" \;
 find . -name "ochad.trc*" -mtime +1 -exec rm -rf {} \;
 find . -name "*.json" -mtime +5 -exec rm -rf {} \;
 find . -name "*.xml" -mtime +1 -exec rm -rf {} \;
 find . -name "*.log" -mtime +1 -exec rm -rf {} \;
 find . -name "*.trc" -mtime -4 -exec rm -rf {} \;
 find . -name "*.tr*" -mtime +1 -exec rm -rf {} \;
 find . -name "*.trm" -mtime +1 -exec rm -rf {} \;
 find . -name "*.aud" -mtime +1 -exec rm -rf {} \;
 find . -name "core.*" -mtime +30 -exec rm -rf {} \;
 find . -name "*.gz" -mtime +1 -exec rm -rf {} \;
 find . -name "*.aud" -mtime +1 -exec rm -rf {} \;
 find . -name "ora_audit_*" -mtime +1 -exec rm -rf {} \;
 find /backup/ogg/brmprd* -mtime +120 -exec rm {} \;
 find . -name "rp*" -mtime +1 -exec rm -rf {} \;
 find . -name "*.xml" -exec rm -rf {} \;
 find . -name "core.*" -exec rm -rf {} \;




--===============================
-- SCP
--===============================

-- Comando Padrao

scp -p /backup-media/dump/APDATA/backup_fechamento_2023/bkp_nov/*.dmp oracle@10.1.50.51:/dump/IMPORT_180124/                     
scp -p /backup-media/dump/APDATA/backup_fechamento_2023/bkp_nov/teste.txt oracle@10.1.50.51:/dump/IMPORT_180124/  

*/*/

--  ENTRE EXAS ou OCI Hosts
 
-- 1) mover a chave do opc do destino para o host origem 

--> dentro da origem: Mudar permissionamento

chmod 600 <chave do destino>

--> Comandos passando a chave 
scp -i /home/opc/ssh-key-2026-06-26.key opcMSAF_gru.ora opc@10.207.40.244:/home/opc/


--===============================
-- Find com DU
--===============================

du -ahx /acfs01 --threshold=1G | sort -rn | head -n 50
du -ahx /acfs01 --threshold=10G | sort -rn | head -n 50
du -ahx /u01 --threshold=10G | sort -rn | head -n 50