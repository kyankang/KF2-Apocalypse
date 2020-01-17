class ApocMutLoader extends KFMutator
	Config(ApocMutLoader);

const INI_VERSION = 1;

var config int IniVersion;
var config array<string> Mutators;

function SetupDefaultConfig()
{
	if( IniVersion <= 0 )
	{
		IniVersion = INI_VERSION;
		Mutators.AddItem("KFExample.ExampleMut");
		SaveConfig();
	}
}

function PreBeginPlay()
{
	local int i;

	Super.PostBeginPlay();

	SetupDefaultConfig();

	for( i = 0; i < Mutators.Length; i++ )
	{
		if( Mutators[i] == "" )
		{
			continue;
		}
		else
		{
			WorldInfo.Game.AddMutator(Mutators[i], true);
            `log("  *" @ Mutators[i]);
		}
	}
}

function AddMutator( Mutator M )
{
    if( Self != M )
    {
        if( M.Class == Class )
            M.Destroy();
        else Super.AddMutator(M);
    }
}

defaultproperties
{
}
