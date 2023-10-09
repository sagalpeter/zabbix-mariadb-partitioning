DELIMITER $$
USE zabbix$$
 
-- create schedluer event to perform management regularly
CREATE EVENT IF NOT EXISTS zbx_part_manage
ON SCHEDULE EVERY 1 DAY STARTS '2022-01-20 04:00:00'
ON COMPLETION PRESERVE
ENABLE
COMMENT 'Creating and dropping partitions'
DO BEGIN
CALL zabbix.drop_partitions('zabbix');
CALL zabbix.create_next_partitions('zabbix');
 
END$$
DELIMITER ;
