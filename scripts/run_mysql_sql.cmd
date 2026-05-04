@echo off
setlocal ENABLEDELAYEDEXPANSION

REM ============================================================================
REM run_mysql_sql.cmd - Execute MySQL SQL files
REM ============================================================================
REM Usage:
REM   scripts\run_mysql_sql.cmd
REM
REM Optional environment variables:
REM   DB_NAME (default: school_clinic)
REM   DB_USER (default: root)
REM   DB_HOST (default: localhost)
REM   DB_PORT (default: 3306)
REM   SQL_DIR  (default: database\mysql)
REM ============================================================================

if "%DB_NAME%"=="" set "DB_NAME=school_clinic"
if "%DB_USER%"=="" set "DB_USER=root"
if "%DB_HOST%"=="" set "DB_HOST=localhost"
if "%DB_PORT%"=="" set "DB_PORT=3306"
if "%SQL_DIR%"=="" set "SQL_DIR=database\mysql"

where mysql >nul 2>&1
if errorlevel 1 (
    echo ERROR: mysql is not installed or not in PATH.
    exit /b 1
)

if not exist "%SQL_DIR%" (
    echo ERROR: SQL directory not found: %SQL_DIR%
    exit /b 1
)

for /f "delims=" %%A in ('powershell -Command "[System.Runtime.InteropServices.Marshal]::PtrToStringAuto([System.Runtime.InteropServices.Marshal]::SecureStringToCoTaskMemUnicode((Read-Host 'Enter MySQL password for %DB_USER%' -AsSecureString)))"') do set "MYSQL_PWD=%%A"

echo ========================================
echo  Running MySQL SQL Files
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
        mysql -h "%DB_HOST%" -P "%DB_PORT%" -u "%DB_USER%" --default-character-set=utf8mb4 --binary-mode < "%SQL_DIR%\%%F"
    ) else if /I "!CURRENT_FILE!"=="init.sql" (
        mysql -h "%DB_HOST%" -P "%DB_PORT%" -u "%DB_USER%" --default-character-set=utf8mb4 --binary-mode < "%SQL_DIR%\%%F"
    ) else (
        mysql -h "%DB_HOST%" -P "%DB_PORT%" -u "%DB_USER%" --database="%DB_NAME%" --default-character-set=utf8mb4 --binary-mode < "%SQL_DIR%\%%F"
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

set MYSQL_PWD=

exit /b 0
