-- ============================================================================
-- 01_init.sql
-- School Clinic Management System — Database, Users & Privileges (MySQL)
-- ============================================================================
-- Run this file as a MySQL root/admin user:
--   mysql -u root -p < 01_init.sql
-- ============================================================================

-- --------------------------------------------------------
-- 1. Create the databases
-- --------------------------------------------------------
-- MySQL does not support schemas like PostgreSQL. We use two databases:
--   school_clinic     — application tables, views, and functions
--   school_clinic_audit — immutable audit trail (append-only)

DROP DATABASE IF EXISTS school_clinic;
DROP DATABASE IF EXISTS school_clinic_audit;

CREATE DATABASE school_clinic
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE DATABASE school_clinic_audit
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 2. Create application users
-- --------------------------------------------------------
-- MySQL does not have NOLOGIN group roles like PostgreSQL.
-- We create individual MySQL users for each role. The application
-- connects as 'clinic_app' and the API layer selects the correct
-- user session variables to enforce role-based access.
--
-- In practice, the app connects as clinic_app and sets:
--   SET @app_current_user_id = <user_id>;
--   SET @app_current_role = '<role>';
--   SET @app_encryption_key = '<key>';
--
-- Views and stored procedures enforce access based on these variables.

-- Drop users if they exist (for idempotency)
DROP USER IF EXISTS 'clinic_admin'@'%';
DROP USER IF EXISTS 'clinic_doctor'@'%';
DROP USER IF EXISTS 'clinic_nurse'@'%';
DROP USER IF EXISTS 'clinic_student'@'%';
DROP USER IF EXISTS 'clinic_faculty'@'%';
DROP USER IF EXISTS 'clinic_app'@'%';

-- Create role-based users
CREATE USER 'clinic_admin'@'%'   IDENTIFIED BY 'change_me_in_production';
CREATE USER 'clinic_doctor'@'%'  IDENTIFIED BY 'change_me_in_production';
CREATE USER 'clinic_nurse'@'%'   IDENTIFIED BY 'change_me_in_production';
CREATE USER 'clinic_student'@'%' IDENTIFIED BY 'change_me_in_production';
CREATE USER 'clinic_faculty'@'%' IDENTIFIED BY 'change_me_in_production';

-- Application service account — the web app connects as this user
CREATE USER 'clinic_app'@'%' IDENTIFIED BY 'change_me_in_production';

-- --------------------------------------------------------
-- 3. Grant basic database access
-- --------------------------------------------------------
-- Detailed table-level grants are defined in 06_grants.sql.
-- Here we only grant the ability to connect and use the databases.

GRANT USAGE ON *.* TO 'clinic_admin'@'%';
GRANT USAGE ON *.* TO 'clinic_doctor'@'%';
GRANT USAGE ON *.* TO 'clinic_nurse'@'%';
GRANT USAGE ON *.* TO 'clinic_student'@'%';
GRANT USAGE ON *.* TO 'clinic_faculty'@'%';
GRANT USAGE ON *.* TO 'clinic_app'@'%';

-- clinic_app needs the ability to set session variables and execute routines
GRANT SELECT, INSERT, UPDATE, DELETE ON school_clinic.* TO 'clinic_app'@'%';
GRANT SELECT ON school_clinic_audit.* TO 'clinic_app'@'%';
GRANT EXECUTE ON school_clinic.* TO 'clinic_app'@'%';

FLUSH PRIVILEGES;

-- ============================================================================
-- Verification
-- ============================================================================
-- Run these queries to verify setup:
--   SHOW DATABASES LIKE 'school_clinic%';
--   SELECT user, host FROM mysql.user WHERE user LIKE 'clinic_%';
-- ============================================================================
