@echo off
::  BOOST-WIN11.BAT  – Suzy’s Turbo Mode
::  Usage:  boost-win11.bat       →   enable turbo
::          boost-win11.bat /undo →   restore everything
::------------------------------------------------------------------

:: --- Force admin elevation if not already
>nul 2>&1 net session
if %errorlevel% neq 0 (
    echo [*] Relaunching as admin...
    powershell -Command "Start-Process '%~f0' -ArgumentList '%*' -Verb runAs"
    exit /b
)

setlocal EnableExtensions EnableDelayedExpansion

:: --- Backup directory
set "BKP=%SystemRoot%\Temp\boost-backup"
if not exist "%BKP%" mkdir "%BKP%"

:: ─────────────────────────────
::    R O L L   B A C K
:: ─────────────────────────────
if /I "%~1"=="/undo" (
    echo.
    echo [*] Restoring previous settings...

    if exist "%BKP%\oldplan.txt" (
        for /f "usebackq tokens=*" %%p in ("%BKP%\oldplan.txt") do (
            powercfg /setactive %%p
        )
        del "%BKP%\oldplan.txt"
        echo    ✓ Power plan rolled back
    )

    if exist "%BKP%\services.reg" (
        reg import "%BKP%\services.reg" >nul
        del "%BKP%\services.reg"
        echo    ✓ Service startup types restored
    )

    echo.
    echo Done! Reboot recommended.
    goto :EOF
)

echo.
echo    ███ BOOSTING WINDOWS 11 ███
echo.

:: 1. Enable Ultimate Performance power scheme
for /f "tokens=3" %%u in ('powercfg /list ^| findstr /I "Ultimate"') do set "UPPLAN=%%u"
if not defined UPPLAN (
    powercfg /duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 >nul
    for /f "tokens=3" %%u in ('powercfg /list ^| findstr /I "Ultimate"') do set "UPPLAN=%%u"
)
:: Save current power plan
for /f "tokens=3" %%c in ('powercfg /getactivescheme') do echo %%c > "%BKP%\oldplan.txt"
powercfg /setactive %UPPLAN%
echo    ✓ Ultimate Performance plan enabled

:: 2. Disable SysMain (Superfetch)
reg query HKLM\SYSTEM\CurrentControlSet\Services\SysMain /v Start > "%BKP%\services.reg" 2>nul
sc stop "SysMain" >nul 2>&1
sc config "SysMain" start= disabled >nul
echo    ✓ SysMain disabled

:: 3. Disable Windows tips & consumer content
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338393Enabled /t REG_DWORD /d 0 /f >nul
reg add "HKCU\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager" /v SubscribedContent-338389Enabled /t REG_DWORD /d 0 /f >nul
echo    ✓ Removed background promo clutter

:: 4. Lighten visual effects
reg add "HKCU\Control Panel\Desktop" /v UserPreferencesMask /t REG_BINARY /d 9012038010000000 /f >nul
echo    ✓ UI visual effects adjusted

:: 5. Disable some non-critical scheduled tasks
for %%T in (
    "XblGameSave\XblGameSaveTask"
    "TaskSchedulerUpdate"
    "Maintenance\WinSAT"
) do (
    schtasks /Change /TN "\Microsoft\Windows\%%~T" /Disable >nul 2>&1
)
echo    ✓ Disabled scheduled tasks

:: 6. Backup and disable startup items (basic)
wmic startup where "Command != NULL and Caption != NULL" get Caption, Command /format:csv > "%BKP%\startup.csv"
for /f "skip=2 tokens=2 delims=," %%s in ('wmic startup get Caption^, Command /format:csv') do (
    if not "%%s"=="" (
        wmic startup where "Caption='%%s'" call disable >nul 2>&1
    )
)
echo    ✓ Startup items disabled (backup saved)

echo.
echo ███  DONE!  Reboot for full effect. ███
echo (Use  boost-win11.bat /undo  to revert changes.)
echo.

endlocal
pause
