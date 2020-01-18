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

event Broadcast(Actor Sender, coerce string Msg, optional name Type)
{
    if ( Type == 'Say' )
	{
        if (ChatCommandHandler(Sender, Msg))
            return;
	}

    super.Broadcast(Sender, Msg, Type);
}

function bool ChatCommandHandler(Actor Sender, coerce string Msg)
{
    local bool IsCommandHandled;
    local ClassicPlayerController KFPC;

    KFPC = ClassicPlayerController(GetALocalPlayerController());

    if ( 3 == Len( Msg ) && ( Left( Msg, 3 ) ~= "!ot" ) )
    {
        if( KFPC != none )
        {
            KFPC.OpenTraderMenu();
            IsCommandHandled = true;
        }
    }

    return IsCommandHandled;
}

defaultproperties
{
}
