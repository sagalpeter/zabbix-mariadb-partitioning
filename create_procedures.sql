DELIMITER $$

USE zabbix$$
 
DROP PROCEDURE IF EXISTS create_next_partitions$$
 
CREATE PROCEDURE create_next_partitions(IN_SCHEMANAME VARCHAR(64))
BEGIN
DECLARE TABLENAME_TMP VARCHAR(64);
DECLARE PERIOD_TMP VARCHAR(12);
DECLARE DONE INT DEFAULT 0;
 
DECLARE get_prt_tables CURSOR FOR
    SELECT `tablename`, `period`
        FROM manage_partitions;
 
DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
 
OPEN get_prt_tables;
 
loop_create_part: LOOP
    IF DONE THEN
        LEAVE loop_create_part;
    END IF;
 
    FETCH get_prt_tables INTO TABLENAME_TMP, PERIOD_TMP;
 
    CASE WHEN PERIOD_TMP = 'day' THEN
                CALL `create_partition_by_day`(IN_SCHEMANAME, TABLENAME_TMP);
         WHEN PERIOD_TMP = 'month' THEN
                CALL `create_partition_by_month`(IN_SCHEMANAME, TABLENAME_TMP);
         ELSE
        BEGIN
                        ITERATE loop_create_part;
        END;
    END CASE;
 
            UPDATE manage_partitions set last_updated = NOW() WHERE tablename = TABLENAME_TMP;
 
END LOOP loop_create_part;
CLOSE get_prt_tables;
 
END$$

DROP PROCEDURE IF EXISTS create_partition_by_day$$
 
CREATE PROCEDURE create_partition_by_day(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;
    DECLARE BEGINTIME TIMESTAMP;
    DECLARE ENDTIME INT UNSIGNED;
    DECLARE PARTITIONNAME VARCHAR(16);
    SET BEGINTIME = DATE(NOW()) + INTERVAL 1 DAY;
    SET PARTITIONNAME = DATE_FORMAT( BEGINTIME, 'p%Y_%m_%d' );
    SET ENDTIME = UNIX_TIMESTAMP(BEGINTIME + INTERVAL 1 DAY);
 
    SELECT COUNT(*) INTO ROWS_CNT
            FROM information_schema.partitions
            WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = PARTITIONNAME;
 
IF ROWS_CNT = 0 THEN
                 SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                            ' REORGANIZE PARTITION pMAX INTO (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', ENDTIME,
                            '), PARTITION pMAX VALUES LESS THAN (MAXVALUE) ENGINE = InnoDB);' );
            PREPARE STMT FROM @SQL;
            EXECUTE STMT;
            DEALLOCATE PREPARE STMT;
    ELSE
    SELECT CONCAT("partition `", PARTITIONNAME, "` for table `",IN_SCHEMANAME, ".", IN_TABLENAME, "` already exists") AS result;
    END IF;
 
END$$

DROP PROCEDURE IF EXISTS create_partition_by_month$$
 
CREATE PROCEDURE create_partition_by_month(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;
    DECLARE BEGINTIME TIMESTAMP;
    DECLARE ENDTIME INT UNSIGNED;
    DECLARE PARTITIONNAME VARCHAR(16);
    SET BEGINTIME = DATE(NOW() - INTERVAL DAY(NOW()) DAY + INTERVAL 1 DAY + INTERVAL 1 MONTH);
    SET PARTITIONNAME = DATE_FORMAT( BEGINTIME, 'p%Y_%m' );
 
    SET ENDTIME = UNIX_TIMESTAMP(BEGINTIME + INTERVAL 1 MONTH);
    SELECT COUNT(*) INTO ROWS_CNT
            FROM information_schema.partitions
            WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = PARTITIONNAME;
 
IF ROWS_CNT = 0 THEN
                 SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                            ' REORGANIZE PARTITION pMAX INTO (PARTITION ', PARTITIONNAME, ' VALUES LESS THAN (', ENDTIME,
                            '), PARTITION pMAX VALUES LESS THAN (MAXVALUE) ENGINE = InnoDB);' );
            PREPARE STMT FROM @SQL;
            EXECUTE STMT;
            DEALLOCATE PREPARE STMT;
    ELSE
    SELECT CONCAT("partition `", PARTITIONNAME, "` for table `",IN_SCHEMANAME, ".", IN_TABLENAME, "` already exists") AS result;
    END IF;
 
END$$

DROP PROCEDURE IF EXISTS drop_partitions$$
 
CREATE PROCEDURE drop_partitions(IN_SCHEMANAME VARCHAR(64))
BEGIN
    DECLARE TABLENAME_TMP VARCHAR(64);
    DECLARE PARTITIONNAME_TMP VARCHAR(64);
    DECLARE VALUES_LESS_TMP INT;
    DECLARE PERIOD_TMP VARCHAR(12);
    DECLARE KEEP_HISTORY_TMP INT;
    DECLARE KEEP_HISTORY_BEFORE INT;
    DECLARE DONE INT DEFAULT 0;
    DECLARE get_partitions CURSOR FOR SELECT p.table_name, p.partition_name, LTRIM(RTRIM(p.partition_description)), mp.period, mp.keep_history FROM information_schema.partitions p JOIN manage_partitions mp ON mp.tablename = p.table_name WHERE p.table_schema = IN_SCHEMANAME AND LTRIM(RTRIM(p.partition_description)) <> 'MAXVALUE' ORDER BY p.table_name, p.subpartition_ordinal_position;
    DECLARE CONTINUE HANDLER FOR NOT FOUND SET done = 1;
 
OPEN get_partitions;
 
loop_check_prt: LOOP
    IF DONE THEN
        LEAVE loop_check_prt;
    END IF;
 
    FETCH get_partitions INTO TABLENAME_TMP, PARTITIONNAME_TMP, VALUES_LESS_TMP, PERIOD_TMP, KEEP_HISTORY_TMP;
    CASE WHEN PERIOD_TMP = 'day' THEN
            SET KEEP_HISTORY_BEFORE = UNIX_TIMESTAMP(DATE(NOW() - INTERVAL KEEP_HISTORY_TMP DAY));
         WHEN PERIOD_TMP = 'month' THEN
            SET KEEP_HISTORY_BEFORE = UNIX_TIMESTAMP(DATE(NOW() - INTERVAL KEEP_HISTORY_TMP MONTH - INTERVAL DAY(NOW())-1 DAY));
         ELSE
        BEGIN
            ITERATE loop_check_prt;
        END;
    END CASE;
 
 
    IF KEEP_HISTORY_BEFORE >= VALUES_LESS_TMP THEN
            CALL drop_old_partition(IN_SCHEMANAME, TABLENAME_TMP, PARTITIONNAME_TMP);
    END IF;
    END LOOP loop_check_prt;
    CLOSE get_partitions;
 
END$$

DROP PROCEDURE IF EXISTS drop_old_partition$$
 
CREATE PROCEDURE drop_old_partition(IN_SCHEMANAME VARCHAR(64), IN_TABLENAME VARCHAR(64), IN_PARTITIONNAME VARCHAR(64))
BEGIN
    DECLARE ROWS_CNT INT UNSIGNED;
    SELECT COUNT(*) INTO ROWS_CNT
            FROM information_schema.partitions
            WHERE table_schema = IN_SCHEMANAME AND table_name = IN_TABLENAME AND partition_name = IN_PARTITIONNAME;
 
IF ROWS_CNT = 1 THEN
                 SET @SQL = CONCAT( 'ALTER TABLE `', IN_SCHEMANAME, '`.`', IN_TABLENAME, '`',
                            ' DROP PARTITION ', IN_PARTITIONNAME, ';' );
            PREPARE STMT FROM @SQL;
            EXECUTE STMT;
            DEALLOCATE PREPARE STMT;
    ELSE
    SELECT CONCAT("partition `", IN_PARTITIONNAME, "` for table `", IN_SCHEMANAME, ".", IN_TABLENAME, "` not exists") AS result;
    END IF;
 
END$$

DELIMITER ;
