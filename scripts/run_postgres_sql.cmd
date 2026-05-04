@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ============================================================================
REM run_postgres_sql.cmd - Execute PostgreSQL SQL files (excluding seed files)
REM ============================================================================
REM Usage:
REM   scripts\run_postgres_sql.cmd
REM
REM Optional environment variables:
REM   DB_NAME (default: school_clinic_db)
REM   DB_USER (default: postgres)
REM   DB_HOST (default: localhost)
REM   DB_PORT (default: 5432)
REM   SQL_DIR  (default: database\postgres)
REM ============================================================================

if "%DB_NAME%"=="" set "DB_NAME=school_clinic_db"
if "%DB_USER%"=="" set "DB_USER=postgres"
if "%DB_HOST%"=="" set "DB_HOST=localhost"
if "%DB_PORT%"=="" set "DB_PORT=5432"
if "%SQL_DIR%"=="" set "SQL_DIR=database\postgres"

where psql >nul 2>&1
if errorlevel 1 (
    echo ERROR: psql is not installed or not in PATH.
    exit /b 1
)

if not exist "%SQL_DIR%" (
    echo ERROR: SQL directory not found: %SQL_DIR%
    exit /b 1
)

for /f "delims=" %%A in ('powershell -Command "[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode((Read-Host 'Enter PostgreSQL password for %DB_USER%' -AsSecureString)))"') do set "PGPASSWORD=%%A"

echo ========================================
echo  Running PostgreSQL SQL Files
echo  Database: %DB_NAME%
echo  Host: %DB_HOST%:%DB_PORT%
echo  User: %DB_USER%
echo  SQL dir: %SQL_DIR%
echo  Including all .sql files
echo ========================================

set /a TOTAL=0
for /f "delims=" %%F in ('dir /b /on "%SQL_DIR%\*.sql"') do (
    set /a TOTAL+=1
)

if %TOTAL% EQU 0 (
    echo No SQL files found to execute.
    exit /b 0
)

set /a INDEX=0
for /f "delims=" %%F in ('dir /b /on "%SQL_DIR%\*.sql"') do (
    set /a INDEX+=1
    echo.
    echo [!INDEX!/%TOTAL%] Executing %SQL_DIR%\%%F ...

    set "CURRENT_FILE=%%~nxF"
    if /I "!CURRENT_FILE!"=="01_init.sql" (
        psql -h "%DB_HOST%" -p "%DB_PORT%" -U "%DB_USER%" -v ON_ERROR_STOP=1 -v recreate_database=1 -f "%SQL_DIR%\%%F"
    ) else if /I "!CURRENT_FILE!"=="init.sql" (
        psql -h "%DB_HOST%" -p "%DB_PORT%" -U "%DB_USER%" -v ON_ERROR_STOP=1 -f "%SQL_DIR%\%%F"
    ) else (
        psql -h "%DB_HOST%" -p "%DB_PORT%" -U "%DB_USER%" -d "%DB_NAME%" -v ON_ERROR_STOP=1 -f "%SQL_DIR%\%%F"
    )
    if errorlevel 1 (
        echo ERROR: Execution failed for %SQL_DIR%\%%F
        exit /b 1
    )

    echo Completed: %SQL_DIR%\%%F
)

echo.
echo ========================================
echo  All SQL files executed successfully
echo ========================================

set PGPASSWORD=

exit /b 0
