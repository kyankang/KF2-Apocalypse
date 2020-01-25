@echo off

set KF2_BIN="G:\SteamLibrary\SteamApps\common\killingfloor2\Binaries\Win64"

set Map=KF-Outpost
set GameMode=?game=ApocControlledDifficulty.CD_Survival
set Mutators=?mutator=ApocMutLoader.ApocMutLoader
set Difficulty=?Difficulty=2
set Length=?GameLength=1
set AccessPlus=
set AdminName=?AdminName=
set AdminPasswd=?AdminPassword=
set GamePasswd=?GamePassword=
set Port=
set Options=-NOSPLASH -log -nomovie -useunpublished

%KF2_BIN%\KFGame.exe %Map%%GameMode%%Difficulty%%Length%%Mutators%%AccessPlus%%AdminName%%AdminPasswd%%GamePasswd%%Port% %Options%
