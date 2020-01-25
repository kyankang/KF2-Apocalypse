class ApocGameInfo_Survival extends CD_Survival
	config(ApocControlledDifficulty);

var config int iVersionNumber;
var config bool bSpawnOutOfSight;
var config int MaxNumPlayers, SpawnManagerUpdateTimes;
var config int MinWaveTotalZeds, MaxWaveTotalZeds;
var config int MinSpawnZeds, MaxSpawnZeds;

function SetupDefaultConfig()
{
	if( iVersionNumber <= 1 )
	{
		bSpawnOutOfSight = false;
		MaxNumPlayers = 24;
		SpawnManagerUpdateTimes = 3;
		MinWaveTotalZeds = 64;
		MaxWaveTotalZeds = 1200;
		MinSpawnZeds = 32;
		MaxSpawnZeds = 150;
		iVersionNumber++;
	}

	SaveConfig();
}

function InitSpawnVolumes()
{
	local byte i;
	local KFSpawnVolume S;
	local int SpawnVolumeNums;

	foreach AllActors(class'KFSpawnVolume',S)
		SpawnVolumeNums++;

	if (SpawnVolumeNums>0)
	{
		SpawnVolumeNums = 0;
		foreach AllActors(class'KFSpawnVolume',S)
		{
			S.MinDistanceToPlayer = FMin(S.MinDistanceToPlayer,600.f);
			S.bOutOfSight = bSpawnOutOfSight;
			S.SpawnDerateTime = 5.f;
			S.UnTouchCoolDownTime = 3.f;
			if (S.LargestSquadType==EST_Boss)
				++SpawnVolumeNums;
			++i;
		}

		if (i<=2 && i>3)
		{
			// Needs more boss volumes.
			foreach AllActors(class'KFSpawnVolume',S)
			{
				if (S.LargestSquadType!=EST_Boss)
				{
					S.LargestSquadType = EST_Boss;
					if (--SpawnVolumeNums==0)
						break;
				}
			}
		}
	}
}

function PostBeginPlay()
{
	super.PostBeginPlay();

	SetupDefaultConfig();
	InitSpawnVolumes();
}

event InitGame( string Options, out string ErrorMessage )
{
	super.InitGame(Options, ErrorMessage);

	MaxPlayers = MaxNumPlayers;
}

function StartWave()
{
	local int i, j;
	local int SpawnMonsters;

	super.StartWave();

	SpawnMonsters = GetSpawnZeds();

	for (i = 0; i < SpawnManager.PerDifficultyMaxMonsters.length; i++)
	{
		for (j = 0; j < SpawnManager.PerDifficultyMaxMonsters[i].MaxMonsters.length; j++)
		{
			SpawnManager.PerDifficultyMaxMonsters[i].MaxMonsters[j]
				= Max(SpawnManager.PerDifficultyMaxMonsters[i].MaxMonsters[j], SpawnMonsters);
		}
	}

	SpawnManager.WaveTotalAI = GetWaveTotalZeds();
	MyKFGRI.AIRemaining = SpawnManager.WaveTotalAI;
	MyKFGRI.WaveTotalAICount = SpawnManager.WaveTotalAI;
}

function EndOfMatch(bool bVictory)
{
	super.EndOfMatch(bVictory);
}

event Timer()
{
	local int i;

	if (MyKFGRI.bMatchHasBegun)
	{
		SpawnManager.TimeUntilNextSpawn = 0;

		if (SpawnManager.ShouldAddAI())
		{
			for (i = 0; i < SpawnManagerUpdateTimes; i++)
				SpawnManager.Update();
		}
	}
}

function int GetWaveTotalZeds()
{
	local float PlayerNumPct;
	local int WaveTotalAI;

	PlayerNumPct = (NumPlayers-1) / (MaxPlayers-1);
	WaveTotalAI = Lerp(MinWaveTotalZeds, MaxWaveTotalZeds, PlayerNumPct);
	return WaveTotalAI;
}

function int GetSpawnZeds()
{
	local float PlayerNumPct;

	PlayerNumPct = (NumPlayers-1) / (MaxPlayers-1);
	return Lerp(MinSpawnZeds, MaxSpawnZeds, PlayerNumPct);
}

defaultproperties
{
}
