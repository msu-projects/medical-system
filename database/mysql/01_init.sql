-- ============================================================================
-- 01_init.sql
-- School Clinic Management System — Database, Roles & Service Account (MySQL)
-- ============================================================================
-- Run this file as a MySQL root/admin user:
--   mysql -u root -p < 01_init.sql
-- ============================================================================

-- --------------------------------------------------------
-- 1. Create the databases
-- --------------------------------------------------------
-- PostgreSQL source-of-truth uses one DB with clinic/audit schemas.
-- In MySQL, schema == database, so we keep two databases:
--   school_clinic       — clinic objects
--   school_clinic_audit — audit objects
--
-- Recreate behavior: drop existing databases, then create fresh ones.
DROP DATABASE IF EXISTS school_clinic;
DROP DATABASE IF EXISTS school_clinic_audit;

CREATE DATABASE school_clinic
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

CREATE DATABASE school_clinic_audit
    CHARACTER SET utf8mb4
    COLLATE utf8mb4_unicode_ci;

-- --------------------------------------------------------
-- 2. Create application roles (NOLOGIN-equivalent in MySQL)
-- --------------------------------------------------------
-- These mirror PostgreSQL group roles and dedicated definer owners.

DROP ROLE IF EXISTS
    'clinic_admin',
    'clinic_doctor',
    'clinic_nurse',
    'clinic_student',
    'clinic_faculty',
    'clinic_trigger_owner',
    'clinic_rls_owner',
    'audit_writer_owner';

CREATE ROLE IF NOT EXISTS
    'clinic_admin',
    'clinic_doctor',
    'clinic_nurse',
    'clinic_student',
    'clinic_faculty',
    'clinic_trigger_owner',
    'clinic_rls_owner',
    'audit_writer_owner';

-- Clean up legacy direct-login role users from older script versions.
-- DROP USER IF EXISTS 'clinic_admin'@'%';
-- DROP USER IF EXISTS 'clinic_doctor'@'%';
-- DROP USER IF EXISTS 'clinic_nurse'@'%';
-- DROP USER IF EXISTS 'clinic_student'@'%';
-- DROP USER IF EXISTS 'clinic_faculty'@'%';

-- --------------------------------------------------------
-- 3. Create the application service account (LOGIN equivalent)
-- --------------------------------------------------------
-- The app connects as clinic_app, then executes SET ROLE per request.

DROP USER IF EXISTS 'clinic_app'@'%';
CREATE USER 'clinic_app'@'%' IDENTIFIED BY 'change_me_in_production';

-- Grant clinic_app the ability to SET ROLE to any application role.
GRANT
    'clinic_admin',
    'clinic_doctor',
    'clinic_nurse',
    'clinic_student',
    'clinic_faculty'
TO 'clinic_app'@'%';

-- Force explicit role switching by the application on each request.
SET DEFAULT ROLE NONE TO 'clinic_app'@'%';

-- --------------------------------------------------------
-- 4. Bootstrap-level grants
-- --------------------------------------------------------
-- Detailed object-level grants are in 06_grants.sql.
GRANT USAGE ON *.* TO
    'clinic_app'@'%',
    'clinic_admin',
    'clinic_doctor',
    'clinic_nurse',
    'clinic_student',
    'clinic_faculty',
    'clinic_trigger_owner',
    'clinic_rls_owner',
    'audit_writer_owner';

FLUSH PRIVILEGES;

-- ============================================================================
-- Verification
-- ============================================================================
-- SHOW DATABASES LIKE 'school_clinic%';
-- SELECT user, host FROM mysql.user WHERE user = 'clinic_app';
-- SELECT from_user, from_host, to_user, to_host FROM mysql.role_edges
-- WHERE from_user = 'clinic_app';
-- ============================================================================
