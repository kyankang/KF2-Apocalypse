class ApocGameInfo_Survival extends KFGameInfo_LegacySurvival;

`include(ClassicGameInfo.uci);

function PostBeginPlay()
{
    local sGameMode GameMode;

    Super.PostBeginPlay();

    if( !bSavedGametypes )
    {
        bSavedGametypes = true;

        GameMode.FriendlyName = "Apoc Survival";
        GameMode.ClassNameAndPath = "ApocGameModeSrv.ApocGameInfo_Survival";
        GameMode.bSoloPlaySupported = True;
        GameMode.DifficultyLevels = 4;
        GameMode.Lengths = 4;
        GameMode.LocalizeID = 0;

        GameModes.AddItem(GameMode);
        SaveConfig();
    }
}

static event class<GameInfo> SetGameType(string MapName, string Options, string Portal)
{
	// if we're in the menu level, use the menu gametype
	if ( class'WorldInfo'.static.IsMenuLevel(MapName) )
	{
        return class<GameInfo>(DynamicLoadObject("ApocClassicMenu.ApocGameInfo_Survival", class'Class'));
	}

	return Default.class;
}

defaultproperties
{
}
