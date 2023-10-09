# Zabbix mariadb database partitioning

Based on:
 - https://blog.zabbix.com/partitioning-a-zabbix-mysql-database-with-perl-or-stored-procedures/13531/
 - https://bestmonitoringtools.com/zabbix-partitioning-tables-on-mysql-database/

Partitioning for history* and trends* tables, with periodic scheduled database event to maintain partitioning.
```
history
history_log
history_str
history_text
history_uint
trends
trends_uint
```

If you are partitioning already running zabbix database, first get dates of first history records
```mysql
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.history;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.history_str;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.history_log;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.history_text;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.history_uint;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.trends;
SELECT FROM_UNIXTIME(MIN(clock)) FROM zabbix.trends_uint;
```
Next, prepare statements to alter existing tables introducing partitions. Example `ALTER TABLE` statements:
If you are partitioning clean zabbix database, create only partitions for today and tomorrow.
```mysql
-- daily (preferred for history* tables)
ALTER TABLE history_uint PARTITION BY RANGE ( clock)
(PARTITION p2020_12_19 VALUES LESS THAN (UNIX_TIMESTAMP("2020-12-20 00:00:00")) ENGINE = InnoDB,
PARTITION p2020_12_21 VALUES LESS THAN (UNIX_TIMESTAMP("2020-12-22 00:00:00")) ENGINE = InnoDB,
PARTITION pMAX VALUES LESS THAN (MAXVALUE) ENGINE = InnoDB);
 
-- monthly (preferred for trends* tables)
ALTER TABLE trends_uint PARTITION BY RANGE ( clock)
(PARTITION p2020_10 VALUES LESS THAN (UNIX_TIMESTAMP("2020-11-01 00:00:00")) ENGINE = InnoDB,
PARTITION p2020_11 VALUES LESS THAN (UNIX_TIMESTAMP("2020-12-01 00:00:00")) ENGINE = InnoDB,
PARTITION pMAX VALUES LESS THAN (MAXVALUE) ENGINE = InnoDB);
```
Following bash snippet may help you to generate all partition lines for daily partitions
```shell
#!/bin/bash

# unix timestamp of first day 
FIRST_STAMP=1606172400
# how many days to generate
COUNTER=400
 
for ((i = 0 ; i <= $COUNTER ; i++)); do
  CURR_TIME=$(($FIRST_STAMP + $(($i * 86400))))
  NEXT_TIME=`date "+%Y-%m-%d %H:%M:%S" --date=\@$(($CURR_TIME + 86400))`
  PART_NAME="p_"`date "+%Y_%m_%d" --date=\@$CURR_TIME`
  echo "PARTITION $PART_NAME VALUES LESS THAN (UNIX_TIMESTAMP(\"$NEXT_TIME\") ENGINE = InnoDB,"
done
```

Once tables are partitioned, run `create_parametrisation.sql` script, which will create table `manage_partitions` and insert parametrisation data. Edit INSERT statements to fit your data retention needs.

Next run `create_procedures.sql` file, which will create stored procedures used to maintain partitioning.

Last file to edit&run is `create_event.sql` which will create scheduler event to run previously created procedures - create new partition daily and remove all partitions according retention settings.

Should any error occur with scheduled actions, new zabbix data will be stored in pMAX partitions (so no data will be lost). pMAX partitions can be monitored with statements, if everything is OK, following selects will return 0:
```mysql
SELECT count(*) from `history` PARTITION (pMAX);
SELECT count(*) from `history_log` PARTITION (pMAX);
SELECT count(*) from `history_str` PARTITION (pMAX);
SELECT count(*) from `history_text` PARTITION (pMAX);
SELECT count(*) from `history_uint` PARTITION (pMAX);
SELECT count(*) from `trends` PARTITION (pMAX);
SELECT count(*) from `trends_uint` PARTITION (pMAX);
```