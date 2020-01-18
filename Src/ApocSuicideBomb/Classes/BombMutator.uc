class BombMutator extends KFMutator;

var transient float EndKillProtection;
var Pawn LastKilledPlayer;

function PostBeginPlay()
{
	if( WorldInfo.Game.BaseMutator==None )
		WorldInfo.Game.BaseMutator = Self;
	else WorldInfo.Game.BaseMutator.AddMutator(Self);
}

function AddMutator(Mutator M)
{
	if( M!=Self ) // Make sure we don't get added twice.
	{
		if( M.Class==Class )
			M.Destroy();
		else Super.AddMutator(M);
	}
}

function GetSeamlessTravelActorList(bool bToEntry, out array<Actor> ActorList)
{
	if (NextMutator != None)
		NextMutator.GetSeamlessTravelActorList(bToEntry, ActorList);
}

function bool PreventDeath(Pawn Killed, Controller Killer, class<DamageType> damageType, vector HitLocation)
{
	local KFWeap_SuicideBomb B;

	if( damageType==Class'DmgType_Suicided' ) // Allow normal suicide to go ahead (like people leaving from server).
		return Super.PreventDeath(Killed,Killer,damageType,HitLocation);

	B = None;
	if( damageType!=class'KFDT_SuicideExplosive' && Killer!=None && Killer!=Killed.Controller && Killed.InvManager!=None )
	{
		B = KFWeap_SuicideBomb(Killed.InvManager.FindInventoryType(class'KFWeap_SuicideBomb',true));
		if( B!=None && B.JustExploded() ) // Already about to explode, prevent additional kill messages from other mods.
		{
			LastKilledPlayer = Killed;
			EndKillProtection = WorldInfo.TimeSeconds+2.f;
			return true;
		}
	}
	if( NextMutator != None && NextMutator.PreventDeath(Killed, Killer, damageType, HitLocation) ) // Allow other mutators to override this first.
		return true;
	if( B!=None )
	{
		if( !B.InstaSuicide() )
			return false;
		Killed.Health = 100;
		Killed.SpawnTime = WorldInfo.TimeSeconds+1.f;
		LastKilledPlayer = Killed;
		EndKillProtection = WorldInfo.TimeSeconds+2.f;
		return true;
	}
	return false;
}

function NetDamage(int OriginalDamage, out int Damage, Pawn Injured, Controller InstigatedBy, vector HitLocation, out vector Momentum, class<DamageType> DamageType, Actor DamageCauser)
{
	if( LastKilledPlayer==Injured && DamageType!=class'KFDT_SuicideExplosive' && InstigatedBy!=None && InstigatedBy!=Injured.Controller && Injured.InvManager!=None && EndKillProtection>WorldInfo.TimeSeconds )
	{
		Damage = 0;
		return;
	}
	if (NextMutator != None)
		NextMutator.NetDamage(OriginalDamage, Damage, Injured, InstigatedBy, HitLocation, Momentum, DamageType, DamageCauser);
}

defaultproperties
{
   Begin Object /*Class=SpriteComponent*/ Name=Sprite Archetype=SpriteComponent'KFGame.Default__KFMutator:Sprite'
      SpriteCategoryName="Info"
      ReplacementPrimitive=None
      HiddenGame=True
      AlwaysLoadOnClient=False
      AlwaysLoadOnServer=False
      Name="Sprite"
      ObjectArchetype=SpriteComponent'KFGame.Default__KFMutator:Sprite'
   End Object
   Components(0)=Sprite
   Name="Default__BombMutator"
   ObjectArchetype=KFMutator'KFGame.Default__KFMutator'
}
