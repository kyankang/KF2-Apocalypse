class ApocPerk_SWAT extends ClassicPerk_Base;

//`include(KFOnlineStats.uci)

/** Passives */
var private	const PerkSkill					BulletResistance;
var private	const PerkSkill					MagSize;
var private	const PerkSkill					WeaponSwitchSpeed;

var private const float						RapidAssaultFiringRate;    			// Faster firing rate in %  NOTE:This is needed for combinations with the Skill: RapidAssault (Stumble Power and Rate)
var private const float 					SnarePower;
var private const float 					TacticalMovementBobDamp;
var private const class<KFWeaponDefinition>	BackupSecondaryWeaponDef;

/** Percentage of how much armor should be damaged when the heavy armor skill is active */
var private const float 					HeavyArmorAbsorptionPct;

var float                                   CurrentHealthPenalty;

/** Amount of damage Battering Ram bumps deal */
var int BumpDamageAmount;
/** Damage type used for Battering Ram bump damage */
var class<DamageType> BumpDamageType;
/** Amount of momentum when bumping zeds */
var float BumpMomentum;
/** Multiplier for speed during zed time while enforcer is active*/
var float SWATEnforcerZedTimeSpeedScale;
/** The last time a zed was bumped using battering ram */
var float LastBumpTime;
/** The unique list of actors that have been bumped before the last cooldown reset */
var array<Actor> CurrentBumpedActors;
/** The amount of time between when the last actor was bumped and another actor can be bumped again */
var float BumpCooldown;

/** Selectable skills */
enum ESWATPerkSkills
{
	ESWAT_HeavyArmor,
	ESWAT_TacticalMovement,
	ESWAT_Backup,
	ESWAT_TacticalReload,
	ESWAT_SpecialAmmunition,
	ESWAT_AmmoVest,
	ESWAT_BodyArmor,
	ESWAT_Cripple,
	ESWAT_SWATEnforcer,
	ESWAT_RapidAssault
};

replication
{
    if (bNetDirty)
        CurrentHealthPenalty;
}

/*********************************************************************************************
* @name	 Perk init and spawning
******************************************************************************************** */

/** On spawn, modify owning pawn based on perk selection */
function SetPlayerDefaults( Pawn PlayerPawn )
{
	local float NewArmor;

	super.SetPlayerDefaults( PlayerPawn );

	if( OwnerPawn.Role == ROLE_Authority )
	{
		if( IsHeavyArmorActive() )
		{
			NewArmor += OwnerPawn.default.MaxArmor * GetSKillValue( PerkSkills[ESWAT_HeavyArmor] );
		}

		if( IsBodyArmorActive() )
		{
			NewArmor += OwnerPawn.default.MaxArmor * GetSKillValue( PerkSkills[ESWAT_BodyArmor] );
		}

		OwnerPawn.AddArmor( Round( NewArmor ) );
	}
}

/** (Server) Modify Instigator settings based on selected perk */
function ApplySkillsToPawn()
{
	super.ApplySkillsToPawn();

	if( OwnerPawn != none )
	{
		OwnerPawn.bMovesFastInZedTime = IsSWATEnforcerActive();
	}
}

simulated event float GetZedTimeSpeedScale()
{
	return IsSWATEnforcerActive() ? SWATEnforcerZedTimeSpeedScale : 1.f;
}

/* Returns the secondary weapon's class path for this perk */
simulated function string GetSecondaryWeaponClassPath()
{
	return IsBackupActive() ? BackupSecondaryWeaponDef.default.WeaponClassPath : SecondaryWeaponDef.default.WeaponClassPath;
}

/*********************************************************************************************
* @name	 Passives
********************************************************************************************* */
/**
 * @brief Modifies the damage taken
 *
 * @param InDamage damage
 * @param DamageType the damage type used (optional)
 */
function ModifyDamageTaken( out int InDamage, optional class<DamageType> DamageType, optional Controller InstigatedBy )
{
	local float TempDamage;

	if( InDamage <= 0 )
	{
		return;
	}

	TempDamage = InDamage;

	if( ClassIsChildOf( DamageType, class'KFDT_Ballistic' ) )
	{
		TempDamage -= InDamage * GetPassiveValue( BulletResistance, CurrentLevel, BulletResistance.Rank );
	}

	`QALog( "Total DamageResistance" @ DamageType @ GetPercentage( InDamage, Round( TempDamage ) ) @ "Start/End" @ InDamage @ Round( TempDamage ), bLogPerk );
	InDamage = Round( TempDamage );
}

/**
 * @brief Modifies mag capacity and count
 *
 * @param KFW the weapon
 * @param MagazineCapacity modified mag capacity
 * @param WeaponPerkClass the weapon's associated perk class (optional)
 */
simulated function ModifyMagSizeAndNumber( KFWeapon KFW, out byte MagazineCapacity, optional array< Class<KFPerk> > WeaponPerkClass, optional bool bSecondary=false, optional name WeaponClassname )
{
	local float TempCapacity;

	TempCapacity = MagazineCapacity;

	if( !bSecondary && !Is9mm( KFW ) && IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) && (KFW == none || !KFW.bNoMagazine) )
	{
		TempCapacity += MagazineCapacity * GetPassiveValue( MagSize, CurrentLevel, MagSize.Rank );
	}

	MagazineCapacity = Round(TempCapacity);
}

/**
 * @brief The Quick Switch skill modifies the weapon switch speed
 *
 * @param ModifiedSwitchTime Duration of putting down or equipping the weapon
 */
simulated function ModifyWeaponSwitchTime( out float ModifiedSwitchTime )
{
	`QALog( "(Passive Weapon Switch) Increase:" @ GetPercentage( ModifiedSwitchTime,  ModifiedSwitchTime * (1.f - GetPassiveValue(WeaponSwitchSpeed, CurrentLevel, WeaponSwitchSpeed.Rank)) ), bLogPerk );
	ModifiedSwitchTime *= 1.f - GetPassiveValue( WeaponSwitchSpeed, CurrentLevel, WeaponSwitchSpeed.Rank );
}

/*********************************************************************************************
* @name	 Selectable skills functions
********************************************************************************************* */

/**
 * @brief Checks if the player can be grabbed by clots
 *
 * @return true if we are not grabbable
 */
function bool CanNotBeGrabbed()
{
	return IsHeavyArmorActive();
}

simulated function bool HasHeavyArmor()
{
	return IsHeavyArmorActive();
}

static simulated private function bool Is9mm( KFWeapon KFW )
{
	return KFW != none && KFW.default.bIsBackupWeapon && !KFW.IsMeleeWeapon();
}

/**
 * @brief The Tactical Movement skill lets you move quicker in iron sights
 *
 * @param KFW Weapon equipped
 * @return Speed modifier
 */
simulated event float GetIronSightSpeedModifier( KFWeapon KFW )
{
	if( IsTacticalMovementActive() && (Is9mm( KFW ) || IsWeaponOnPerk( KFW,, self.class )) )
	{
		`QALog( "Tactical Movement Mod:" @ KFW @ GetSkillValue( PerkSkills[ESWAT_TacticalMovement] ),bLogPerk );
		return  GetSkillValue( PerkSkills[ESWAT_TacticalMovement] );
	}

	return 1.f;
}

/**
 * @brief Triggered via KFPawn_Human.UpdateGroundSpeed.  Update any speed-related variables that need to be set when
 *              the pawn's allowed ground speed changes.
 */
function FinalizeSpeedVariables()
{
    super.FinalizeSpeedVariables();
	if(OwnerPawn != none)
	{
		CurrentHealthPenalty = 1 - OwnerPawn.LowHealthSpeedPenalty;
	}
}

/**
 * @brief The Tactical Movement skill lets you move quicker in iron sights
 *
 * @param KFW Weapon equipped
 * @return Speed modifier
 */
simulated event float GetCrouchSpeedModifier( KFWeapon KFW )
{
	if( IsTacticalMovementActive() && (Is9mm( KFW ) || IsWeaponOnPerk( KFW,, self.class )) )
	{
		`QALog( "Tactical Movement Mod:" @ KFW @ GetSkillValue( PerkSkills[ESWAT_TacticalMovement] ),bLogPerk );
		return  GetSkillValue( PerkSkills[ESWAT_TacticalMovement] ) * CurrentHealthPenalty;
	}

	return 1.f;
}

simulated function ModifyWeaponBopDamping( out float BobDamping, KFWeapon PawnWeapon )
{
	If( IsTacticalMovementActive() && (Is9mm( PawnWeapon ) || IsWeaponOnPerk( PawnWeapon,, self.class )) )
	{
		BobDamping *= default.TacticalMovementBobDamp;
	}
}

/**
 * @brief Modifies the damage dealt
  *
 * @param InDamage damage
 * @param DamageCauser weapon or projectile (optional)
 * @param MyKFPM the zed damaged (optional)
 * @param DamageInstigator responsible controller (optional)
 * @param class DamageType the damage type used (optional)
 */
simulated function ModifyDamageGiven( out int InDamage, optional Actor DamageCauser, optional KFPawn_Monster MyKFPM, optional KFPlayerController DamageInstigator, optional class<KFDamageType> DamageType, optional int HitZoneIdx )
{
	local KFWeapon KFW;
	local float TempDamage;

	TempDamage = InDamage;

	if( DamageCauser != none )
	{
		KFW = GetWeaponFromDamageCauser( DamageCauser );
	}

	if( KFW != none )
	{
		if( IsBackupActive() && IsBackupWeapon( KFW ) )
		{
			`QALog( "Backup Damage" @ KFW @ GetPercentage( InDamage, InDamage * GetSkillValue(PerkSkills[ESWAT_Backup])), bLogPerk );
			TempDamage += InDamage * GetSkillValue( PerkSkills[ESWAT_Backup] );
		}
		else if( IsWeaponOnPerk( KFW,, self.class ) || (DamageType != none && IsDamageTypeOnPerk(DamageType)) )
		{
			`QALog( "Passive Damage" @KFW @ GetPercentage( InDamage, InDamage * GetPassiveValue(WeaponDamage, CurrentLevel, WeaponDamage.Rank)), bLogPerk );
			TempDamage *= GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank );
		}
	}

	`QALog( "Total Damage Given" @ DamageType @ KFW @ GetPercentage( InDamage, Round(TempDamage) ), bLogPerk );
	InDamage = Round(TempDamage);
}

/**
 * @brief Modifies the max spare ammo
 *
 * @param KFW The weapon
 * @param MaxSpareAmmo ammo amount
 * @param TraderItem the weapon's associated trader item info
 */
simulated function ModifyMaxSpareAmmoAmount( KFWeapon KFW, out int MaxSpareAmmo, optional const out STraderItem TraderItem, optional bool bSecondary=false )
{
	local float TempMaxSpareAmmoAmount;

	if( IsAmmoVestActive() && !Is9mm(KFW) && IsWeaponOnPerk( KFW, TraderItem.AssociatedPerkClasses, self.class ) )
	{
		TempMaxSpareAmmoAmount = MaxSpareAmmo;
		TempMaxSpareAmmoAmount += MaxSpareAmmo * GetSkillValue( PerkSkills[ESWAT_AmmoVest] );
		MaxSpareAmmo = Round( TempMaxSpareAmmoAmount );
	}
}

simulated function float GetSnareSpeedModifier()
{
	return IsCrippleActive() ? default.PerkSkills[ESWAT_Cripple].StartingValue : 1.f;
}

simulated function float GetSnarePowerModifier( optional class<DamageType> DamageType, optional byte HitZoneIdx )
{
	if( IsCrippleActive() && DamageType != none && IsDamageTypeOnPerk( class<KFDamageType>(DamageType) ) )
	{
		return default.SnarePower;
	}

	return 0.f;
}

/**
 * @brief Modifies the pawn's MaxArmor
 *
 * @param MaxArmor the maximum armor value
 */
function ModifyArmor( out byte MaxArmor )
{
	local float TempArmor;

	if( IsBodyArmorActive() )
	{
		TempArmor = MaxArmor;
		TempArmor += TempArmor * GetSkillValue( PerkSkills[ESWAT_BodyArmor] );
		`QALog( "Modify MaxArmor" @ GetPercentage( MaxArmor, FCeil( TempArmor )), bLogPerk );
		MaxArmor = Round( TempArmor );
	}
}

/**
 * @brief Skills can modify the zed time time delation
 *
 * @param StateName used weapon's state
 * @return time dilation modifier
 */
simulated function float GetZedTimeModifier( KFWeapon W )
{
	local name StateName;

	StateName = W.GetStateName();
	if( IsRapidAssaultActive() && (Is9mm(W) || IsWeaponOnPerk( W,, self.class )) )
	{
		if( ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE )
		{
			`QALog( "Rapid Assault Modifier" @ StateName @ RapidAssaultFiringRate, bLogPerk );
			return RapidAssaultFiringRate;
		}
	}

	return 0.f;
}

/**
 * @brief skills and weapons can modify the stumbling power
 * @return stumbling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	local KFWeapon KFW;
	local float StumbleModifier;

	StumbleModifier = 0.f;

	KFW = GetOwnerWeapon();
	if( IsSpecialAmmunitionActive() && (Is9mm(KFW) || IsWeaponOnPerk( KFW,, self.class )) )
	{
		StumbleModifier += GetSkillValue( PerkSkills[ESWAT_SpecialAmmunition] );
		`QALog( "Special Ammunition Modifier" @ GetSkillValue( PerkSkills[ESWAT_SpecialAmmunition] ), bLogPerk );
	}

	if( IsRapidAssaultActive() )
	{
		StumbleModifier += GetSkillValue( PerkSkills[ESWAT_RapidAssault] );
		`QALog( "Rapid Assault Modifier" @ GetSkillValue( PerkSkills[ESWAT_RapidAssault] ), bLogPerk );
	}


	return StumbleModifier;
}

/**
 * @brief Checks if Rapid Assault is selected and if the weapon is on perk
 *
 * @param KFW Weapon used
 * @return true or false
 */
simulated function bool GetIsUberAmmoActive( KFWeapon KFW )
{
	return IsRapidAssaultActive() && (Is9mm(KFW) || IsWeaponOnPerk( KFW,, self.class ));
}

simulated function bool ShouldKnockDownOnBump()
{
	return IsSWATEnforcerActive() && WorldInfo.TimeDilation < 1.f;
}

simulated function OnBump(Actor BumpedActor, KFPawn_Human BumpInstigator, vector BumpedVelocity, rotator BumpedRotation)
{
	local KFPawn_Monster KFPM;
	local bool CanBump;

	if (ShouldKnockDownOnBump() && Normal(BumpedVelocity) dot Vector(BumpedRotation) > 0.7f)
	{
		KFPM = KFPawn_Monster(BumpedActor);
		if (KFPM != none)
		{
			// cooldown so that the same zed can't be bumped multiple frames back to back
			//	especially relevant if they can't be knocked down or stumbled so the player is always bumping them
			if (WorldInfo.TimeSeconds - LastBumpTime > BumpCooldown)
			{
				CurrentBumpedActors.length = 0;
				CurrentBumpedActors.AddItem(BumpedActor);
				CanBump = true;
			}
			// if still within the cooldown time, can still bump the actor as long as it hasn't been bumped yet
			else if (CurrentBumpedActors.Find(BumpedActor) == INDEX_NONE)
			{
				CurrentBumpedActors.AddItem(BumpedActor);
				CanBump = true;
			}

			LastBumpTime = WorldInfo.TimeSeconds;

			if (CanBump)
			{
				if (KFPM.IsHeadless())
				{
					KFPM.TakeDamage(KFPM.HealthMax, BumpInstigator.Controller, BumpInstigator.Location,
						Normal(vector(BumpedRotation)) * BumpMomentum, BumpDamageType);
				}
				else
				{
					KFPM.TakeDamage(BumpDamageAmount, BumpInstigator.Controller, BumpInstigator.Location,
						Normal(vector(BumpedRotation)) * BumpMomentum, BumpDamageType);
					KFPM.Knockdown(BumpedVelocity * 3, vect(1, 1, 1), KFPM.Location, 1000, 100);
				}
			}
		}
	}
}

simulated function int GetArmorDamageAmount( int AbsorbedAmt )
{
	if( HasHeavyArmor() )
	{
		return Max( Round(AbsorbedAmt * HeavyArmorAbsorptionPct), 1 );
	}

	return AbsorbedAmt;
}

/*********************************************************************************************
* @name	 Getters etc
********************************************************************************************* */

/**
 * @brief Checks if the Riot Shield skill is active
 *
 * @return true/false
 */
simulated function bool IsHeavyArmorActive()
{
	return PerkSkills[ESWAT_HeavyArmor].bActive && IsPerkLevelAllowed(ESWAT_HeavyArmor);
}


/**
 * @brief Checks if the Tactical Movement skill is active
 *
 * @return true/false
 */
simulated function bool IsTacticalMovementActive()
{
	return PerkSkills[ESWAT_TacticalMovement].bActive && IsPerkLevelAllowed(ESWAT_TacticalMovement);
}

/**
 * @brief Checks if backup damage skill is active
 *
 * @return true/false
 */
simulated private function bool IsBackupActive()
{
	return PerkSkills[ESWAT_Backup].bActive && IsPerkLevelAllowed(ESWAT_Backup);
}

/**
 * @brief Checks if tactical reload skill is active (client & server)
 *
 * @return true/false
 */
simulated private function bool IsTacticalReloadActive()
{
	return PerkSkills[ESWAT_TacticalReload].bActive && IsPerkLevelAllowed(ESWAT_TacticalReload);
}

/**
 * @brief Should the tactical reload skill adjust the reload speed
 *
 * @param KFW weapon in use
 * @return true/false
 */
simulated function bool GetUsingTactialReload( KFWeapon KFW )
{
	return ( IsTacticalReloadActive() && (Is9mm(KFW) || IsWeaponOnPerk( KFW,, self.class )) );
}

/**
 * @brief Checks if Special Ammunition skill is active
 *
 * @return true/false
 */
simulated function bool IsSpecialAmmunitionActive()
{
	return PerkSkills[ESWAT_SpecialAmmunition].bActive && IsPerkLevelAllowed(ESWAT_SpecialAmmunition);
}

/**
 * @brief Checks if Ammo Vest skill is active
 *
 * @return true/false
 */
final simulated private function bool IsAmmoVestActive()
{
	return PerkSkills[ESWAT_AmmoVest].bActive && IsPerkLevelAllowed(ESWAT_AmmoVest);
}

/**
 * @brief Checks if Body Armor skill is active
 *
 * @return true/false
 */
final private function bool IsBodyArmorActive()
{
	return PerkSkills[ESWAT_BodyArmor].bActive && IsPerkLevelAllowed(ESWAT_BodyArmor);
}

/**
 * @brief Checks if the Cripple skill is active
 *
 * @return true/false
 */
final private function bool IsCrippleActive()
{
	return PerkSkills[ESWAT_Cripple].bActive && IsPerkLevelAllowed(ESWAT_Cripple);
}

/**
 * @brief Menace and Spartan resist zed time. You move at normal speed.
 *
 * @return true if Menace or Spartan are active
 */
function bool IsSWATEnforcerActive()
{
	return PerkSkills[ESWAT_SWATEnforcer].bActive && IsPerkLevelAllowed(ESWAT_SWATEnforcer);
}

/**
 * @brief Rapid Assault resists zed time. You shoot at normal speed.
 *
 * @return true if Menace or Spartan are active
 */
simulated function bool IsRapidAssaultActive()
{
	return PerkSkills[ESWAT_RapidAssault].bActive && WorldInfo.TimeDilation < 1.f && IsPerkLevelAllowed(ESWAT_RapidAssault);
}

/*********************************************************************************************
* @name	 Hud/UI/Stats/Exp
********************************************************************************************* */

/**
 * @brief how much XP is earned by a stalker kill depending on the game's difficulty
 *
 * @param Difficulty current game difficulty
 * @return XP earned
 */
simulated static function int GetClotKillXP( byte Difficulty )
{
	return default.SecondaryXPModifier[Difficulty];
}

simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( GetPassiveValue( default.WeaponDamage, Level, default.WeaponDamage.Rank ) * 100 - 100 ) @ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.BulletResistance, Level, default.BulletResistance.Rank ) * 100 ) @ "%";
	PassiveValues[2] = Round( GetPassiveValue( default.MagSize, Level, default.MagSize.Rank ) * 100 ) @ "%";		// Divide by 100 to convert unreal units to meters
	PassiveValues[3] = Round( GetPassiveValue( default.WeaponSwitchSpeed, Level, default.WeaponSwitchSpeed.Rank ) * 100 ) @ "%";
	PassiveValues[4] = "";

	Increments[0] = "[" @ Left( string( default.WeaponDamage.Increment * 100 ), InStr(string(default.WeaponDamage.Increment * 100), ".") + 2 ) @ "% / +" $ default.WeaponDamage.Rank @ default.LevelString @ "]";
	Increments[1] = "[" @ "5% +" @ Round( default.BulletResistance.Increment * 100 ) @ "% / +" $ default.BulletResistance.Rank @ default.LevelString @"]";
	Increments[2] = "[" @ Round( default.MagSize.Increment * 100 )  @"% / +" $ default.MagSize.Rank @default.LevelString @"]";
	Increments[3] = "[" @ Round( default.WeaponSwitchSpeed.Increment *100 )  @"% / +" $ default.WeaponSwitchSpeed.Rank @ default.LevelString @"]";
	Increments[4] = "";
}

/*********************************************************************************************
* @name	 Classic Perk
******************************************************************************************** */

simulated function float GetCostScaling(byte Level, optional STraderItem TraderItem, optional KFWeapon Weapon)
{
    return 1.f;
}

simulated function GetPerkIcons(ObjectReferencer RepInfo)
{
    local int i;

    for (i = 0; i < OnHUDIcons.Length; i++)
    {
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[164]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
    PrimaryWeaponDef=class'KFWeapDef_MP7'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
   	BackupSecondaryWeaponDef=class'KFWeapDef_9mmDual'
	KnifeWeaponDef=class'KFweapDef_Knife_SWAT'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_SWAT'

	ProgressStatID=STATID_Swat_Progress
   	PerkBuildStatID=STATID_Swat_Build

    // Skill tracking
	HitAccuracyHandicap=0.0
	HeadshotAccuracyHandicap=-3.0

	// Prestige Rewards
	PrestigeRewardItemIconPaths[0]="WEP_SkinSet_Prestige01_Item_TEX.knives.SWATKnife_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[1]="WEP_SkinSet_Prestige02_Item_TEX.tier01.MP7_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[2]="WEP_skinset_prestige03_itemtex.tier02.MP5RAS_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[3]="wep_skinset_prestige04_itemtex.tier03.HecklerKochUMP_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[4]="WEP_SkinSet_Prestige05_Item_TEX.tier04.KrissSMG_PrestigePrecious_Mint_large"

	TacticalMovementBobDamp=1.11
	RapidAssaultFiringRate=0.51f

	SnarePower=15 //20

	WeaponDamage=(Name="Weapon Damage",Increment=0.01f,Rank=1,StartingValue=1.f,MaxValue=1.25) //1.25
	BulletResistance=(Name="Bullet Resistance",Increment=0.01,Rank=1,StartingValue=0.05,MaxValue=0.3f)
	MagSize=(Name="Increased Mag Size",Increment=0.04,Rank=1,StartingValue=0.f,MaxValue=1.f)
	WeaponSwitchSpeed=(Name="Weapon Switch Speed",Increment=0.01,Rank=1,StartingValue=0.f,MaxValue=0.25)
	HeavyArmorAbsorptionPct=0.65f

 	PerkSkills(ESWAT_HeavyArmor)=(Name="HeavyArmor",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_HeavyArmor", Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)    //0.1
	PerkSkills(ESWAT_TacticalMovement)=(Name="TacticalMovement",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_TacticalMovement", Increment=0.f,Rank=0,StartingValue=2.5f,MaxValue=2.5f)
	PerkSkills(ESWAT_Backup)=(Name="Backup",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_Backup", Increment=0.f,Rank=0,StartingValue=0.85f,MaxValue=0.85f) //1.1
	PerkSkills(ESWAT_TacticalReload)=(Name="TacticalReload",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_TacticalReload", Increment=0.f,Rank=0,StartingValue=2.0,MaxValue=2.0)
	PerkSkills(ESWAT_SpecialAmmunition)=(Name="SpecialAmmunition",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_SpecialAmmunition", Increment=0.f,Rank=0,StartingValue=2.0f,MaxValue=2.0f)
	PerkSkills(ESWAT_AmmoVest)=(Name="AmmoVest",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_AmmoVest", Increment=0.f,Rank=0,StartingValue=0.3f,MaxValue=0.3f)
	PerkSkills(ESWAT_BodyArmor)=(Name="BodyArmor",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_BodyArmor", Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(ESWAT_Cripple)=(Name="Cripple",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_Cripple", Increment=0.f,Rank=0,StartingValue=0.7f,MaxValue=0.7f)
	PerkSkills(ESWAT_SWATEnforcer)=(Name="SWATEnforcer",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_SWATEnforcer", Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)
	PerkSkills(ESWAT_RapidAssault)=(Name="RapidAssault",IconPath="UI_PerkTalent_TEX.SWAT.UI_Talents_SWAT_RapidAssault", Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)

	SecondaryXPModifier(0)=2
	SecondaryXPModifier(1)=3
	SecondaryXPModifier(2)=4
	SecondaryXPModifier(3)=7

	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"
	ZedTimeModifyingStates(3)="WeaponAltFiringAuto"
   	AutoBuyLoadOutPath=(class'KFWeapDef_MP7', class'KFWeapDef_MP5RAS', class'KFWeapDef_P90', class'KFWeapDef_Kriss')

	BumpDamageAmount=450
	BumpDamageType=class'KFDT_SWATBatteringRam'
	BumpMomentum=1.f
	SWATEnforcerZedTimeSpeedScale=1.25f

	BumpCooldown = 0.1f

    // Classic Perk
    BasePerk=class'KFPerk_SWAT'
    EXPActions(0)="Dealing SWAT weapon damage"
    EXPActions(1)="Killing Zeds with a SWAT weapon"
}
