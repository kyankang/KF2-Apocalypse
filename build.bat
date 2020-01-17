@echo off

set KF2_BIN="G:\SteamLibrary\SteamApps\common\killingfloor2\Binaries\Win64"

set MY_KF2="C:\Users\kyankang\Documents\My Games\KillingFloor2"
set MY_LOG=%MY_KF2%\KFGame\Logs
set MY_SCRIPT=%MY_KF2%\Development\Unpublished\BrewedPC\Script

set Options=-full -useunpublished

del %MY_LOG%\*.log
del %MY_LOG%\*.dmp
del %MY_SCRIPT%\Apoc*.u

%KF2_BIN%\KFEditor.exe make %Options%
