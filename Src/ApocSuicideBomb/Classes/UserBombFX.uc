Class UserBombFX extends Actor
	transient;

var byte ActivateTeam;
var repnotify ObjectReferencer AssetRef;
var repnotify Pawn PawnOwner;
var repnotify bool bExplode,bIgnite;

replication
{
	if ( true )
		AssetRef,PawnOwner,bExplode,bIgnite;
}

function PostBeginPlay()
{
	PawnOwner = Pawn(Owner);
	ActivateTeam = PawnOwner.GetTeamNum();
	AssetRef = ObjectReferencer'ApocSuicideBomb_rc.Arch.AllAssets';
}
function GoBoom()
{
	bIgnite = false;
	if( PawnOwner!=None && PawnOwner.Health>0 && PawnOwner.Controller!=None && ActivateTeam==PawnOwner.GetTeamNum() )
		CauseExplosion();
	LifeSpan = 0.8f;
}
function DoIgnite()
{
	bIgnite = true;
	if( WorldInfo.NetMode!=NM_DedicatedServer )
		SpawnEffects();
	SetTimer(2.3,false,'GoBoom');
}

simulated function CauseExplosion()
{
	local ParticleSystemComponent P;
	bExplode = true;

	HurtRadius(45000.f,8000.f,class'KFDT_SuicideExplosive',30000.f,Location,PawnOwner,PawnOwner!=None ? PawnOwner.Controller : None);
	if( WorldInfo.NetMode!=NM_Client && PawnOwner!=None )
	{
		PawnOwner.Health = Min(PawnOwner.Health,1);
		PawnOwner.TakeDamage(20000,PawnOwner.Controller,PawnOwner.Location,vect(0,0,9000),class'KFDT_SuicideExplosive',,Self);
	}

	if( WorldInfo.NetMode!=NM_DedicatedServer && AssetRef!=None )
	{
		PlaySound(SoundCue(AssetRef.ReferencedObjects[1]),true);
		P = WorldInfo.MyEmitterPool.SpawnEmitter(ParticleSystem'WEP_3P_MKII_EMIT.FX_MKII_Grenade_Explosion',Location,,Self);
		P.SetScale(4.f);
	}
}

simulated function ReplicatedEvent(name VarName)
{
	switch( VarName )
	{
	case 'bIgnite':
		if( bIgnite )
			SpawnEffects();
		break;
	case 'PawnOwner':
		SetLocation(PawnOwner.Location);
		break;
	case 'bExplode':
		CauseExplosion();
		break;
	}
}

simulated final function SpawnEffects()
{
	if( AssetRef!=None )
	{
		PlaySound(SoundCue(AssetRef.ReferencedObjects[0]),true);
		WorldInfo.MyEmitterPool.SpawnEmitter(ParticleSystem(AssetRef.ReferencedObjects[2]),Location,,Self);
	}
}

simulated function Tick( float Delta )
{
	if( PawnOwner!=None )
		SetLocation(PawnOwner.Location);
}

defaultproperties
{
   RemoteRole=ROLE_SimulatedProxy
   bAlwaysRelevant=True
   Name="Default__UserBombFX"
   ObjectArchetype=Actor'Engine.Default__Actor'
}
