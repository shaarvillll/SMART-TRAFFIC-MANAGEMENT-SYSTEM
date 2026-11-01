@echo off
title Smart Traffic Management - API Server
echo ================================================
echo   Smart Traffic Management - API Server
echo   REST:  http://localhost:7070/api/
echo   WS:    ws://localhost:7070/ws/live
echo ================================================
cd /d "%~dp0"

if exist "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
) else if exist "C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot"
)
set MVN=C:\tools\apache-maven-3.9.6\bin\mvn.cmd

echo [1/2] Building traffic-api...
call "%MVN%" -pl traffic-core,traffic-api -am package -DskipTests -q
if %errorlevel% neq 0 (
    echo BUILD FAILED. Run manually to see errors:
    echo   cd traffic_simulation
    echo   mvn -pl traffic-core,traffic-api -am package -DskipTests
    pause
    exit /b 1
)

echo [2/2] Starting API server...
echo.
"%JAVA_HOME%\bin\java.exe" -jar traffic-api\target\traffic-api-1.0.0-SNAPSHOT.jar
pause
