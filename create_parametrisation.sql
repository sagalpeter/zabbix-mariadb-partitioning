CREATE TABLE manage_partitions (
tablename VARCHAR(64) NOT NULL COMMENT 'Table name',
period VARCHAR(64) NOT NULL COMMENT 'Period - daily or monthly',
keep_history INT(3) UNSIGNED NOT NULL DEFAULT '1' COMMENT 'For how many days or months to keep the partitions',
last_updated DATETIME DEFAULT NULL COMMENT 'When a partition was added last time',comments VARCHAR(128) DEFAULT '1' COMMENT 'Comments',
PRIMARY KEY (tablename)
) ENGINE=INNODB;

INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history', 'day', 750, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_uint', 'day', 750, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_str', 'day', 750, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_text', 'day', 750, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('history_log', 'day', 750, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('trends', 'month', 48, now(), '');
INSERT INTO manage_partitions (tablename, period, keep_history, last_updated, comments) VALUES ('trends_uint', 'month', 48, now(), '');
