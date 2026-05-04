-- ============================================================================
-- 01_init.sql
-- School Clinic Management System — Database, Schemas, Extensions & Roles
-- ============================================================================
-- Run this file as a PostgreSQL superuser (e.g., postgres):
--   psql -U postgres -f 01_init.sql
-- ============================================================================

-- --------------------------------------------------------
-- 1. Create the database
-- --------------------------------------------------------
-- Connect to the default 'postgres' database first, then create our DB.
-- If running via psql, you may need to run this outside a transaction block.
--
-- Safety:
--   - Existing databases are NOT dropped unless you pass:
--       -v recreate_database=1

SELECT EXISTS(
        SELECT 1
        FROM pg_database
        WHERE datname = 'school_clinic_db'
) AS db_exists
\gset

\if :db_exists
    \if :{?recreate_database}
        SELECT pg_terminate_backend(pid)
        FROM pg_stat_activity
        WHERE datname = 'school_clinic_db' AND pid <> pg_backend_pid();

        DROP DATABASE school_clinic_db;
        CREATE DATABASE school_clinic_db
                WITH ENCODING = 'UTF8'
                         LC_COLLATE = 'en_US.UTF-8'
                         LC_CTYPE = 'en_US.UTF-8'
                         TEMPLATE = template0;
    \else
        \echo 'INFO: school_clinic_db already exists; skipping create/drop. Pass -v recreate_database=1 to recreate.'
    \endif
\else
    CREATE DATABASE school_clinic_db
            WITH ENCODING = 'UTF8'
                     LC_COLLATE = 'en_US.UTF-8'
                     LC_CTYPE = 'en_US.UTF-8'
                     TEMPLATE = template0;
\endif

-- --------------------------------------------------------
-- 2. Connect to the new database
-- --------------------------------------------------------
\connect school_clinic_db;

-- --------------------------------------------------------
-- 3. Create schemas
-- --------------------------------------------------------
-- 'clinic' schema — all application tables and views
-- 'audit'  schema — audit trail (isolated for security)

CREATE SCHEMA IF NOT EXISTS clinic;
CREATE SCHEMA IF NOT EXISTS audit;

-- Remove default privileges on public schema
REVOKE ALL ON SCHEMA public FROM PUBLIC;

COMMENT ON SCHEMA clinic IS 'Core application schema for school clinic management';
COMMENT ON SCHEMA audit  IS 'Isolated audit trail — restricted access';

-- --------------------------------------------------------
-- 4. Install extensions
-- --------------------------------------------------------
CREATE EXTENSION IF NOT EXISTS pgcrypto SCHEMA public;
-- pgcrypto provides: pgp_sym_encrypt(), pgp_sym_decrypt(), gen_random_uuid(), crypt(), gen_salt()

-- --------------------------------------------------------
-- 5. Create application roles (NOLOGIN group roles)
-- --------------------------------------------------------
-- These are inherited by login roles via SET ROLE or membership.

DO $$
BEGIN
    -- Drop existing roles if they exist (for idempotency)
    -- Must revoke memberships first to avoid dependency errors
    BEGIN
        REASSIGN OWNED BY clinic_admin TO postgres;
        DROP OWNED BY clinic_admin;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_doctor TO postgres;
        DROP OWNED BY clinic_doctor;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_nurse TO postgres;
        DROP OWNED BY clinic_nurse;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_student TO postgres;
        DROP OWNED BY clinic_student;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_faculty TO postgres;
        DROP OWNED BY clinic_faculty;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_app TO postgres;
        DROP OWNED BY clinic_app;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_trigger_owner TO postgres;
        DROP OWNED BY clinic_trigger_owner;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY clinic_rls_owner TO postgres;
        DROP OWNED BY clinic_rls_owner;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
    BEGIN
        REASSIGN OWNED BY audit_writer_owner TO postgres;
        DROP OWNED BY audit_writer_owner;
    EXCEPTION WHEN undefined_object THEN NULL;
    END;
END $$;

DROP ROLE IF EXISTS clinic_admin;
DROP ROLE IF EXISTS clinic_doctor;
DROP ROLE IF EXISTS clinic_nurse;
DROP ROLE IF EXISTS clinic_student;
DROP ROLE IF EXISTS clinic_faculty;
DROP ROLE IF EXISTS clinic_app;
DROP ROLE IF EXISTS clinic_trigger_owner;
DROP ROLE IF EXISTS clinic_rls_owner;
DROP ROLE IF EXISTS audit_writer_owner;

-- Group roles (NOLOGIN — these are inherited, not used directly)
CREATE ROLE clinic_admin   NOLOGIN NOINHERIT;
CREATE ROLE clinic_doctor  NOLOGIN NOINHERIT;
CREATE ROLE clinic_nurse   NOLOGIN NOINHERIT;
CREATE ROLE clinic_student NOLOGIN NOINHERIT;
CREATE ROLE clinic_faculty NOLOGIN NOINHERIT;

-- Dedicated owners for SECURITY DEFINER functions (least-privilege)
CREATE ROLE clinic_trigger_owner NOLOGIN NOINHERIT NOBYPASSRLS;
CREATE ROLE clinic_rls_owner     NOLOGIN NOINHERIT BYPASSRLS;
CREATE ROLE audit_writer_owner   NOLOGIN NOINHERIT NOBYPASSRLS;

COMMENT ON ROLE clinic_admin   IS 'System administrator — full access to all data and audit logs';
COMMENT ON ROLE clinic_doctor  IS 'School doctor — diagnoses, prescriptions, medical certificates';
COMMENT ON ROLE clinic_nurse   IS 'School nurse / clinic staff — consultations, dispensing, check-ins';
COMMENT ON ROLE clinic_student IS 'Student — view own medical records via masked views';
COMMENT ON ROLE clinic_faculty IS 'Teacher / faculty — view clearance status only';
COMMENT ON ROLE clinic_trigger_owner IS 'Owner of clinic SECURITY DEFINER trigger helpers; minimal DML rights only';
COMMENT ON ROLE clinic_rls_owner     IS 'Owner of RLS identity helper functions; BYPASSRLS for policy-safe lookups';
COMMENT ON ROLE audit_writer_owner   IS 'Owner of audit SECURITY DEFINER trigger function; insert-only on audit log';

-- --------------------------------------------------------
-- 6. Create the application service account (LOGIN role)
-- --------------------------------------------------------
-- The web application connects as clinic_app, then uses SET ROLE
-- to assume the appropriate group role per authenticated request.

CREATE ROLE clinic_app LOGIN PASSWORD 'change_me_in_production'
    NOBYPASSRLS
    NOCREATEDB
    NOCREATEROLE;

-- Grant clinic_app the ability to SET ROLE to any group role
GRANT clinic_admin   TO clinic_app;
GRANT clinic_doctor  TO clinic_app;
GRANT clinic_nurse   TO clinic_app;
GRANT clinic_student TO clinic_app;
GRANT clinic_faculty TO clinic_app;

COMMENT ON ROLE clinic_app IS 'Application service account — connects to DB, then SET ROLE per request';

-- --------------------------------------------------------
-- 7. Grant schema usage to roles
-- --------------------------------------------------------
GRANT USAGE ON SCHEMA clinic TO clinic_admin, clinic_doctor, clinic_nurse, clinic_student, clinic_faculty;
GRANT USAGE ON SCHEMA audit  TO clinic_admin, audit_writer_owner;

-- Admin needs full control for DDL operations
GRANT CREATE ON SCHEMA clinic TO clinic_admin;
GRANT CREATE ON SCHEMA audit  TO clinic_admin;

-- --------------------------------------------------------
-- 8. Set default search path for the application
-- --------------------------------------------------------
ALTER DATABASE school_clinic_db SET search_path TO clinic, public;

-- ============================================================================
-- Verification
-- ============================================================================
-- Run these queries to verify setup:
--   \dn                          -- List schemas: clinic, audit
--   \dx                          -- List extensions: pgcrypto
--   \du                          -- List roles: clinic_admin, clinic_doctor, etc.
--   SELECT current_database();   -- Should show: school_clinic_db
-- ============================================================================
