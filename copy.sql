-- FIRST (MAIN) PROCEDURE

DELIMITER //
CREATE OR REPLACE PROCEDURE
copy(
    IN select_query TEXT,
    IN with_id TINYINT
)
    BEGIN
        SET
            @db := IF(
                select_query REGEXP '(?<=FROM).*?(?=\\..*WHERE)',
                TRIM(
                    REGEXP_SUBSTR(select_query, '(?<=FROM).*?(?=\\..*WHERE)')
                ),
                DATABASE()
            ),
            @cols := TRIM(
                REGEXP_SUBSTR(select_query, '(?<=SELECT).*(?=FROM)')
            ),
            @table := TRIM(
                IF(
                    REGEXP_SUBSTR(select_query, '(?<=FROM).*?(?=WHERE|;|$)') REGEXP '\\.',
                    REGEXP_SUBSTR(
                        REGEXP_SUBSTR(select_query, '(?<=FROM).*?(?=WHERE|;)'),
                        '(?<=\\.).*'
                    ),
                    REGEXP_SUBSTR(select_query, '(?<=FROM).*?(?=WHERE|;)')
                )
            ),
            @cond := IFNULL(
                TRIM(
                    REGEXP_SUBSTR(select_query, 'WHERE.*?(?=ORDER BY|LIMIT|;|$)')
                ),
                ""
            ),
            @order := IFNULL(
                TRIM(
                    REGEXP_SUBSTR(select_query, 'ORDER BY.*?(?=LIMIT|;|$)')
                ),
                ""
            ),
            @limit := IFNULL(
                TRIM(REGEXP_SUBSTR(select_query, 'LIMIT.*?(?=;|$)')),
                ""
            );

        CALL make_insert_into_making_query(
            @db,
            @table,
            @cond,
            @order,
            @limit,
            with_id,
            @exe
        );

        PREPARE select_insert FROM @exe;

        EXECUTE select_insert;

        DEALLOCATE PREPARE select_insert;

    END;

//

DELIMITER ;

-- SECOND (HELPER) PROCEDURE

DELIMITER //

CREATE OR REPLACE PROCEDURE
make_insert_into_making_query(
    _db TEXT,
    _table TEXT,
    _cond TEXT,
    _order TEXT,
    _limit TEXT,
    _with_id TINYINT,
    OUT output TEXT
)
    BEGIN
        WITH `data` AS (
            SELECT
                _db AS `db`,
                /*name of the database if different from where you stand*/
                _table AS `table`,
                /*table name*/
                _cond AS `condition`,
                /* conditions (starting with WHEN) or empty string */
                _order AS `order_by`,
                /* order by clause (starting with ORDER BY) or empty string */
                _limit AS `limit`,
                /* limit (starting with LIMIT) or empty string */
                _with_id AS `with_id`
                /* set to 0 if you want it without the primary key */
        ),
        `columns` AS (
            SELECT
                GROUP_CONCAT(CONCAT('`', `column_name`, '`') SEPARATOR ', ') AS cols
            FROM
                information_schema.columns AS `schema`
                INNER JOIN `data` ON `data`.`db` = schema.table_schema
                AND schema.table_name = data.table
            WHERE
                IF(`schema`.extra = 'auto_increment', 1, 0) = `data`.with_id
                OR `schema`.extra != 'auto_increment'
            ORDER BY
                `schema`.ordinal_position
        )
        SELECT
            CONCAT(
                'SELECT CONCAT(',
                "'INSERT INTO ', '",
                data.table,
                "', ' (', '",
                columns.cols,
                "', ') VALUES \n',",
                'GROUP_CONCAT(sub.`query`  SEPARATOR ",\n"), ";") from (SELECT CONCAT("(",',
                GROUP_CONCAT(
                    CONCAT(
                        'IF(NOT ISNULL(',
                        CONCAT('`', `column_name`, '`'),
                        '), CONCAT(',
                        CONCAT(
                            IF(
                                data_type IN (
                                    'time',
                                    'enum',
                                    'datetime',
                                    'longtext',
                                    'mediumtext',
                                    'smalltext',
                                    'varchar',
                                    'text',
                                    'timestamp',
                                    'date'
                                ),
                                "QUOTE(`",
                                "`"
                            ),
                            `column_name`,
                            IF(
                                data_type IN (
                                    'time',
                                    'enum',
                                    'datetime',
                                    'longtext',
                                    'mediumtext',
                                    'smalltext',
                                    'varchar',
                                    'text',
                                    'timestamp',
                                    'date'
                                ),
                                '`)), "NULL")',
                                "`), 'NULL')"
                            )
                        )
                    ) SEPARATOR ', ", ",'
                ),
                ', ")") as query FROM ',
                `data`.table,
                IF(
                    `data`.condition != '',
                    CONCAT(' ', `data`.condition),
                    ''
                ),
                IF(
                    `data`.order_by != '',
                    CONCAT(' ', `data`.order_by),
                    ''
                ),
                IF(
                    `data`.limit != '',
                    CONCAT(' ', `data`.limit),
                    ''
                ),
                ') sub;'
            ) INTO output
        FROM
            information_schema.columns AS `schema`
            INNER JOIN `data` ON `data`.`db` = schema.table_schema
            AND schema.table_name = data.table
            CROSS JOIN `columns`
        WHERE
            IF(`schema`.extra = 'auto_increment', 1, 0) = `data`.with_id
            OR `schema`.extra != 'auto_increment'
        ORDER BY
            `schema`.ordinal_position;

    END;
//

DELIMITER ;

-- EXAMPLE
-- CALL copy('SELECT * FROM users WHERE id < 3 ORDER BY id DESC LIMIT 10', 0);