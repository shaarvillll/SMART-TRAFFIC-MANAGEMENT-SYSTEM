@echo off
setlocal
if exist "C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.20.101-hotspot"
) else if exist "C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot" (
    set "JAVA_HOME=C:\Program Files\Microsoft\jdk-17.0.14.7-hotspot"
)
set "M2_HOME=C:\tools\apache-maven-3.9.6"
set "PATH=%JAVA_HOME%\bin;%M2_HOME%\bin;%PATH%"

cd /d "%~dp0"
echo ========================================================
echo   Launching Intelligent Traffic Simulator (JavaFX Desktop)
echo ========================================================

set "JFX_LIB=%USERPROFILE%\.m2\repository\org\openjfx"
set "CP=traffic-core\target\classes;traffic-desktop\target\classes;%JFX_LIB%\javafx-base\21.0.2\javafx-base-21.0.2-win.jar;%JFX_LIB%\javafx-controls\21.0.2\javafx-controls-21.0.2-win.jar;%JFX_LIB%\javafx-graphics\21.0.2\javafx-graphics-21.0.2-win.jar;%JFX_LIB%\javafx-swing\21.0.2\javafx-swing-21.0.2-win.jar"

start "Traffic Simulator" "%JAVA_HOME%\bin\java.exe" --enable-native-access=ALL-UNNAMED -cp "%CP%" com.traffic.desktop.Launcher

echo App launched in separate window!
exit /b 0
