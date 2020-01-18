// Jihad explosive, written by Marco.
class KFWeap_SuicideBomb extends KFWeap_MeleeBase;

var KFGFxWorld_C4Screen ScreenUI;
var AkEvent DetonateAkEvent;
var transient float NextExplosionTimer;

simulated function PostBeginPlay()
{
	local Mutator M;

	// Make sure game has this mutator!
	if( WorldInfo.NetMode!=NM_Client )
	{
		for( M=WorldInfo.Game.BaseMutator; M!=None; M=M.NextMutator )
			if( BombMutator(M)!=None )
				break;
		if( M==None )
			Spawn(class'BombMutator');
	}
	Super.PostBeginPlay();
}

simulated function StartFire(byte FireModeNum)
{
	InstaSuicide();

	// Get attack type and send to server
	if( FireModeNum == DEFAULT_FIREMODE || FireModeNum == HEAVY_ATK_FIREMODE || FireModeNum == BASH_FIREMODE )
	{
		Super(KFWeapon).StartFire(DEFAULT_FIREMODE);
		return;
	}
	Super(KFWeapon).StartFire(FireModeNum);
}

simulated function AttachWeaponTo( SkeletalMeshComponent MeshCpnt, optional Name SocketName )
{
	super.AttachWeaponTo( MeshCpnt, SocketName );

	if( Instigator != none && Instigator.IsLocallyControlled() )
	{
		// Create the screen's UI piece
		if (ScreenUI == none)
		{
			ScreenUI = new( self ) class'KFGFxWorld_C4Screen';
			ScreenUI.Init();
			ScreenUI.Start(true);
		}
		ScreenUI.SetPause(false);
		ScreenUI.SetMaxCharges(2);
		ScreenUI.SetActiveCharges(1);
	}
}

/** Turn off the UI screen when we unequip the weapon */
simulated function DetachWeapon()
{
	super.DetachWeapon();
	if ( ScreenUI != none )
		ScreenUI.SetPause();
}

simulated event Destroyed()
{
	if ( ScreenUI != none)
	{
		ScreenUI.Close();
		ScreenUI = None;
	}
	super.Destroyed();
}

final function bool JustExploded()
{
	return (NextExplosionTimer>WorldInfo.TimeSeconds);
}
simulated function Projectile ProjectileFire()
{
	local UserBombFX B;

	if( WorldInfo.NetMode!=NM_Client && !JustExploded() )
	{
		NextExplosionTimer = WorldInfo.TimeSeconds + 2.5f;
		B = Spawn(class'UserBombFX',Instigator,,Instigator.Location,rot(0,0,0));
		B.DoIgnite();
		LifeSpan = 2.3; // Delete after use.
	}
	return None;
}

/** Returns trader filter index based on weapon type */
static simulated event EFilterTypeUI GetTraderFilter()
{
	return FT_Explosive;
}

final function bool InstaSuicide()
{
	ProjectileFire();
	if( Instigator!=None && Instigator.Physics==PHYS_RigidBody ) // Skip if ragdolled.
		return true;
	ClientSuicide();
	return true;
}

simulated reliable client function ClientSuicide()
{
	if( Instigator!=None && Instigator.Physics==PHYS_RigidBody ) // Skip if ragdolled.
		return;
	if( Instigator!=None && Instigator.InvManager!=None )
		Instigator.InvManager.SetCurrentWeapon(Self);
	SendToFiringState(DEFAULT_FIREMODE);
}

static simulated event SetTraderWeaponStats( out array<STraderItemWeaponStats> WeaponStats )
{
	WeaponStats.Length = 4;

	WeaponStats[0].StatType = TWS_Damage;
	WeaponStats[0].StatValue = 1000.f;

	// attacks per minutes (design says minute. why minute?)
	WeaponStats[1].StatType = TWS_RateOfFire;
	WeaponStats[1].StatValue = 50.f;

	WeaponStats[2].StatType = TWS_Range;
	WeaponStats[2].StatValue = 1000.f;

	WeaponStats[3].StatType = TWS_Penetration;
	WeaponStats[3].StatValue = 1000.f;
}

simulated state WeaponSingleFiring
{
ignores AllowSprinting;

	simulated event BeginState( name PreviousStateName )
	{
		Super.BeginState(PreviousStateName);
		if( WorldInfo.NetMode != NM_DedicatedServer )
			PlaySoundBase( DetonateAkEvent, true );
	}
}

defaultproperties
{
   DetonateAkEvent=AkEvent'WW_WEP_EXP_C4.Play_WEP_EXP_C4_Handling_Detonate'
   FireModeIconPaths(DEFAULT_FIREMODE)=Texture2D'ui_firemodes_tex.UI_FireModeSelect_Grenade'
   InventoryGroup=IG_Equipment
   GroupPriority=5.000000
   WeaponSelectTexture=Texture2D'WEP_UI_C4_TEX.UI_WeaponSelect_C4'
   FireAnim="Detonate"
   FireLastAnim=C4_Throw
   PlayerViewOffset=(X=6.000000,Y=2.000000,Z=-4.000000)
   AttachmentArchetype=KFWeapAttach_Dual_C4'WEP_C4_ARCH.Wep_C4_3P'
   Begin Object Class=KFMeleeHelperWeapon Name=MeleeHelper_0 Archetype=KFMeleeHelperWeapon'KFGame.Default__KFWeap_MeleeBase:MeleeHelper_0'
      bUseDirectionalMelee=True
      bHasChainAttacks=True
      Name="MeleeHelper_0"
      ObjectArchetype=KFMeleeHelperWeapon'KFGame.Default__KFWeap_MeleeBase:MeleeHelper_0'
   End Object
   MeleeAttackHelper=KFMeleeHelperWeapon'ApocSuicideBomb.Default__KFWeap_SuicideBomb:MeleeHelper_0'
   AssociatedPerkClasses(0)=None
   FiringStatesArray(DEFAULT_FIREMODE)="WeaponSingleFiring"
   FiringStatesArray(ALTFIRE_FIREMODE)="WeaponSingleFiring"
   WeaponFireTypes(DEFAULT_FIREMODE)=EWFT_Projectile
   WeaponFireTypes(ALTFIRE_FIREMODE)=EWFT_Projectile
   FireInterval(DEFAULT_FIREMODE)=3.500000
   FireInterval(ALTFIRE_FIREMODE)=3.500000
   FireOffset=(X=25.000000,Y=15.000000,Z=0.000000)
   bCanThrow=False
   Begin Object /*Class=KFSkeletalMeshComponent*/ Name=FirstPersonMesh Archetype=KFSkeletalMeshComponent'KFGame.Default__KFWeap_MeleeBase:FirstPersonMesh'
      MinTickTimeStep=0.025000
      SkeletalMesh=SkeletalMesh'Wep_1P_C4_MESH.Wep_1stP_C4_Rig'
      AnimTreeTemplate=AnimTree'CHR_1P_Arms_ARCH.WEP_1stP_Animtree_Master'
      AnimSets(0)=AnimSet'Wep_1P_C4_ANIM.Wep_1P_C4_ANIM'
      bOverrideAttachmentOwnerVisibility=True
      bAllowBooleanPreshadows=False
      ReplacementPrimitive=None
      DepthPriorityGroup=SDPG_Foreground
      bOnlyOwnerSee=True
      LightingChannels=(bInitialized=True,Outdoor=True)
      bAllowPerObjectShadows=True
      Name="FirstPersonMesh"
      ObjectArchetype=KFSkeletalMeshComponent'KFGame.Default__KFWeap_MeleeBase:FirstPersonMesh'
   End Object
   Mesh=FirstPersonMesh
   bDropOnDeath=False
   Begin Object /*Class=StaticMeshComponent*/ Name=StaticPickupComponent Archetype=StaticMeshComponent'KFGame.Default__KFWeap_MeleeBase:StaticPickupComponent'
      StaticMesh=StaticMesh'WEP_3P_C4_MESH.Wep_C4_Pickup'
      ReplacementPrimitive=None
      CastShadow=False
      Name="StaticPickupComponent"
      ObjectArchetype=StaticMeshComponent'KFGame.Default__KFWeap_MeleeBase:StaticPickupComponent'
   End Object
   DroppedPickupMesh=StaticPickupComponent
   PickupFactoryMesh=StaticPickupComponent
   Name="Default__KFWeap_SuicideBomb"
   ObjectArchetype=KFWeap_MeleeBase'KFGame.Default__KFWeap_MeleeBase'
}
