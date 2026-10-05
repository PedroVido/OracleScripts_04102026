-- how to mount and umount disk / change map on fstab

--================================================
--> Com root 
--================================================

--===========================================
--> Desmontar mapeamentos que deseja alterar 
--===========================================
umount /mnt/bkp_wallet
umount /mnt/dum

--====================================
--> Acessar o arquivo de mapeamento
--====================================

cat /etc/fstab 
vi cat /etc/fstab 

--====================================
--> Alterar o caminho 
--====================================

-- De
//10.1.1.225/dunnhunby

--Para
//fsraia01/dunnhunby

--====================================
--> Montar Mapeamento  
--====================================

mount -a