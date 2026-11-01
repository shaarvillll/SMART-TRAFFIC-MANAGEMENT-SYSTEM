@echo off
setlocal
:: ============================================================
::  Smart Traffic Simulator — Windows Launch Script
::  Connects to the deployed backend at Render.
:: ============================================================

set "BACKEND_URL=https://smart-traffic-management-system-xtar.onrender.com"
set "SIM_DIR=%~dp0traffic_simulation"

echo ========================================================
echo   Smart Traffic Simulator (JavaFX Desktop)
echo   Backend: %BACKEND_URL%
echo ========================================================

:: Detect Java (try common locations)
if exist "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
) else if exist "C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot"
) else if exist "C:\Program Files\Eclipse Adoptium\jdk-17.0.11.9-hotspot\bin\java.exe" (
    set "JAVA_HOME=C:\Program Files\Eclipse Adoptium\jdk-17.0.11.9-hotspot"
) else (
    echo [Info] JAVA_HOME not detected at standard paths. Using system java.
    set "JAVA_HOME="
)

if defined JAVA_HOME (
    set "PATH=%JAVA_HOME%\bin;%PATH%"
)

:: Detect Maven
if exist "C:\tools\apache-maven-3.9.6\bin\mvn.cmd" (
    set "M2_HOME=C:\tools\apache-maven-3.9.6"
    set "PATH=%M2_HOME%\bin;%PATH%"
)

cd /d "%SIM_DIR%"

:: Build if needed
if not exist "traffic-desktop\target\traffic-desktop-1.0.0-SNAPSHOT.jar" (
    echo [Build] Compiling — this only runs once...
    call mvn clean package -pl traffic-core,traffic-desktop -am -DskipTests -q
    if errorlevel 1 (
        echo [Error] Build failed. Make sure Java 17+ and Maven 3.9+ are installed.
        pause
        exit /b 1
    )
    echo [Build] Done.
)

set "JAR=%SIM_DIR%\traffic-desktop\target\traffic-desktop-1.0.0-SNAPSHOT.jar"

echo [Launch] Starting simulator...
start "Traffic Simulator" java ^
    --enable-native-access=ALL-UNNAMED ^
    -DBACKEND_URL="%BACKEND_URL%" ^
    -jar "%JAR%"

echo App launched in separate window!
exit /b 0
