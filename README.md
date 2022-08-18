# MariaDB utility stored procedures

This is a repository containing stored procedures for MariaDb version 10.3+.

### copy.sql

The **copy** procedure in copy.sql transforms the result set of a query (SELECT statement) into INSERT statements. The first parameter is a SELECT statement, and the second parameter tells the procedure whether to include the primary key or not.

**Example:**

--> CALL copy('SELECT * FROM users WHERE id < 3 ORDER BY id DESC LIMIT 10', 0);

*Expected output:*

INSERT INTO users (`username`, `email`, `registered_at`, `company_id`) VALUES 
('sando', 'sando@sando.com', '2018-05-10 21:46:03', 1),
('Peter', 'peter@gmail.com', '2020-01-11 03:16:51', 2),
('John', 'john@example.com', '2022-08-18 23:47:13', 2);
