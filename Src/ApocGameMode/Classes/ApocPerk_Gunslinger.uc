class ApocPerk_Gunslinger extends ClassicPerk_Base;

//`include(KFOnlineStats.uci)

//Passives
var const				PerkSkill				BulletResistance;
var const				PerkSkill				MovementSpeed;
var const				PerkSkill				Recoil;
var	const 				PerkSkill				ZedTimeReload;

var	protected 	const	array<Name>				SpecialZedClassNames;
var	protected 	const	array<Name>				AdditionalOnPerkWeaponNames;
var	protected 	const	array<Name>				AdditionalOnPerkDTNames;
var	protected 	const	AkEvent					RhythmMethodSoundReset;
var	protected 	const	AkEvent					RhythmMethodSoundHit;
var	protected 	const	AkEvent					RhythmMethodSoundTop;
var	protected 	const 	name 					RhytmMethodRTPCName;
var	protected	const	float					QuickSwitchSpeedModifier;
var private 	const	float					QuickSwitchRecoilModifier;

/* The bob damping amount when the Shoot and Move perk skill is active */
var	private 	const	float					ShootnMooveBobDamp;

var	private		const 	array<byte>				BoneBreakerBodyParts;
var	private 	const   float					BoneBreakerDamage;
var	private 	const   float					SnarePower;
var private const float							SnareSpeedModifier;

enum EGunslingerSkills
{
	EGunslingerShootnMove,
	EGunslingerQuickSwitch,
	EGunslingerRhythmMethod,
	EGunslingerBoneBreaker,
	EGunslingerPenetration,
	EGunslingerSpeedReload,
	EGunslingerSkullCracker,
	EGunslingerKnockEmDown,
	EGunslingerUberAmmo,
	EGunslingerFanfare
};

//Selectable skills
var private 			int						HeadShotComboCount;
var private 			int						HeadShotComboCountDisplay;
/** The maximum number of headshots that count toward the Rhythm Method perk skill damage multiplier */
var private const		int 					MaxHeadShotComboCount;
var private const		float 					HeadShotCountdownIntervall;

/*********************************************************************************************
* @name	 Perk init and spawning
******************************************************************************************** */
/**
 * @brief Weapons and perk skills can affect the jog/sprint speed
 *
 * @param Speed jog/sprint speed
  */
simulated function ModifySpeed( out float Speed )
{
	local float TempSpeed;

	TempSpeed = Speed;
	TempSpeed += Speed * GetPassiveValue( MovementSpeed, CurrentVetLevel, MovementSpeed.Rank );

	if( IsQuickSwitchActive() )
	{
		TempSpeed += Speed * GetQuickSwitychSpeedModifier();
	}

	`QALog( "MovementSpeed" @ GetPercentage( Speed, Round( TempSpeed ) ), bLogPerk );
	Speed = Round( TempSpeed );
}

/**
 * @brief Modifies skill related attributes
 */
simulated protected event PostSkillUpdate()
{
	super.PostSkillUpdate();

	SetTickIsDisabled( !IsRhythmMethodActive() );

	if( Role == Role_Authority )
	{
		if( IsRhythmMethodActive() )
		{
			ServerClearHeadShotsCombo();
		}
	}
}

/*********************************************************************************************
* @name	 Stats/XP
********************************************************************************************* */
/**
 * @brief how much XP is earned per head shot depending on the game's difficulty
 *
 * @param Difficulty current game difficulty
 * @return XP earned
 */
simulated static function int GetHeadshotXP( byte Difficulty )
{
	return default.SecondaryXPModifier[Difficulty];
}

/*********************************************************************************************
* @name	 Passives
********************************************************************************************* */
/**
 * @brief Modifes the damage dealt
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

	if( (KFW != none && IsWeaponOnPerk( KFW,, self.class )) || (DamageType != none && IsDamageTypeOnPerk( DamageType )) )
	{
		TempDamage += InDamage * GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank );

		if( IsBoneBreakerActive() )
		{
			TempDamage += InDamage * GetSkillValue( PerkSkills[EGunslingerBoneBreaker] );
		}

		if( IsRhythmMethodActive() && HeadShotComboCount > 0 )
		{
			`QALog( "RhythmMethod, HeadShotComboCount=" $HeadShotComboCount, bLogPerk );
			TempDamage += Indamage * GetSkillValue( PerkSkills[EGunslingerRhythmMethod] ) * HeadShotComboCount;
		}

		if( IsBoneBreakerActive() && MyKFPM != none &&
			HitShouldGiveBodyPartDamage( MyKFPM.HitZones[HitZoneIdx].Limb ) )
		{
			`QALog( "Bone Breaker arms and leg damage =" @ Indamage * static.GetBoneBreakerDamage(), bLogPerk );
			TempDamage += Indamage * static.GetBoneBreakerDamage();
		}
	}

	`QALog( "Total Damage Given" @ DamageType @ KFW @ GetPercentage( InDamage, Round( TempDamage ) ), bLogPerk );
	InDamage = FCeil( TempDamage );
}

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

	if( ClassIsChildOf(DamageType, class'KFDT_Ballistic') && TempDamage > 0 )
	{
		TempDamage -= InDamage * GetPassiveValue( BulletResistance, CurrentLevel, BulletResistance.Rank );
	}

	`QALog( "Total DamageResistance" @ DamageType @ GetPercentage( InDamage, Round( TempDamage ) ) @ "Start/End" @ InDamage @ Round( TempDamage ), bLogPerk );
	InDamage = Round( TempDamage );
}

/**
 * @brief Modifies the weapon's recoil
 *
 * @param CurrentRecoilModifier percent recoil lowered
 */
simulated function ModifyRecoil( out float CurrentRecoilModifier, KFWeapon KFW )
{
	if( IsWeaponOnPerk( KFW,, self.class ) )
	{
		`QALog( "Recoil" @ KFW @ GetPercentage( CurrentRecoilModifier, CurrentRecoilModifier - CurrentRecoilModifier * GetPassiveValue( Recoil,  CurrentVetLevel, Recoil.Rank ) ), bLogPerk );
		CurrentRecoilModifier -= CurrentRecoilModifier * GetPassiveValue( Recoil, CurrentVetLevel, Recoil.Rank );

		if( IsQuickSwitchActive() && !KFW.bUsingSights )
		{
			CurrentRecoilModifier *= static.GetQuickSwitchRecoilModifier();
			`QALog( "Hipped quick switch recoil =" @ CurrentRecoilModifier, bLogPerk );
		}
	}
}

simulated private static function float GetQuickSwitchRecoilModifier()
{
	return default.QuickSwitchRecoilModifier;
}

/**
 * @brief Modifies the reload speed for commando weapons
 *
 * @param ReloadDuration Length of the reload animation
 * @param GiveAmmoTime Time after the weapon actually gets some ammo
 */
simulated function float GetReloadRateScale( KFWeapon KFW )
{
	if( IsWeaponOnPerk( KFW,, self.class ) && WorldInfo.TimeDilation < 1.f && !IsFanFareActive() && IsZedTimeReloadAllowed() )
	{
		return 1.f -  GetPassiveValue( ZedTimeReload, CurrentVetLevel, ZedTimeReload.Rank );
	}

	return 1.f;
}

/**
 * @brief For modes that disable zed time skill tiers, also disable zed time reload
 */
simulated function bool IsZedTimeReloadAllowed()
{
    return MyKFGRI != none ? (MyKFGRI.MaxPerkLevel == MyKFGRI.default.MaxPerkLevel) : false;
}

/*********************************************************************************************
* @name	 Selectable skills functions
********************************************************************************************* */
/**
 * @brief Should the tactical reload skill adjust the reload speed
 *
 * @param KFW weapon in use
 * @return true/false
 */
simulated function bool GetUsingTactialReload( KFWeapon KFW )
{
	return IsSpeedReloadActive() && IsWeaponOnPerk( KFW,, self.class );
}

/**
 * @brief Skills can can chnage the knock down power
 * @return knock down power in %
 */
function float GetKnockdownPowerModifier( optional class<DamageType> DamageType, optional byte BodyPart, optional bool bIsSprinting=false )
{
	if( IsKnockEmDownActive() && HitShouldKnockdown( BodyPart ) && bIsSprinting )
	{
		`QALog( "KnockEmDown knockdown, Hit" @ BodyPart @ GetSkillValue( PerkSkills[EGunslingerKnockEmDown] ), bLogPerk );
		return GetSkillValue( PerkSkills[EGunslingerKnockEmDown] );
	}

	return 0.f;
}

/**
 * @brief skills and weapons can modify the stumbling power
 * @return stumpling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	if( IsKnockEmDownActive() && ( HitShouldStumble( BodyPart ) || CheckSpecialZedBodyPart( KFP.class, BodyPart )) )
	{
		`QALog( "CenterMass Stumble, Hit" @ BodyPart @ GetSkillValue( PerkSkills[EGunslingerSkullCracker] ), bLogPerk );
        return GetSkillValue( PerkSkills[EGunslingerKnockEmDown] );
	}

	return 0.f;
}

/**
 * @brief Some zeds have special body parts that cover the torso (FP for example)
 *
 * @param PawnClass The zed hit
 * @param BodyPart The body part
 *
 * @return valid body part or not
 */
function bool CheckSpecialZedBodyPart( class<KFPawn> PawnClass, byte BodyPart )
{
	if( BodyPart == BP_Special && SpecialZedClassNames.Find( PawnClass.name ) != INDEX_NONE )
	{
		return true;
	}

	return false;
}

/**
 * @brief Skills can modify the zed time time delation
 *
 * @param W used weapon
 * @return time dilation modifier
 */
simulated function float GetZedTimeModifier( KFWeapon W )
{
	local name StateName;

	if( GetFanfareActive() && IsWeaponOnPerk( W,, self.class ) )
	{
		StateName = W.GetStateName();
		if( ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE )
		{
			`QALog( "Fanfare Mod:" @ W @ GetSkillValue( PerkSkills[EGunslingerFanfare] ) @ StateName, bLogPerk );
			return GetSkillValue( PerkSkills[EGunslingerFanfare] );
		}

		if( StateName == 'Reloading' )
		{
			return 1.f;
		}
	}

	return 0.f;
}

/**
 * @brief Checks if Uber Ammo is selected, the weapon is on perk and if we are in zed time
 *
 * @param KFW Weapon used
 * @return true or false
 */
simulated function bool GetIsUberAmmoActive( KFWeapon KFW )
{
	return IsWeaponOnPerk( KFW,, self.class ) && IsUberAmmoActive() && WorldInfo.TimeDilation < 1.f;
}

/**
 * @brief A head shot happened - count it if the damage type is on perk
 *
 * @param KFDT Damage type of the weapon used
 */
function AddToHeadShotCombo( class<KFDamageType> KFDT, KFPawn_Monster KFPM )
{
	if( IsDamageTypeOnPerk( KFDT ) )
	{
		++HeadShotComboCount;
		HeadShotComboCountDisplay++;
		HeadShotComboCount = Min( HeadShotComboCount, MaxHeadShotComboCount );
		HeadShotMessage( HeadShotComboCount, HeadShotComboCountDisplay,, KFPM );
		SetTimer( HeadShotCountdownIntervall, true, nameOf( SubstractHeadShotCombo ) );
	}
}

function UpdatePerkHeadShots( ImpactInfo Impact, class<DamageType> DamageType, int NumHit )
{
   	local int HitZoneIdx;
   	local KFPawn_Monster KFPM;

   	if( !IsRhythmMethodActive() )
	{
		return;
	}

   	KFPM = KFPawn_Monster(Impact.HitActor);
   	if( KFPM != none && !KFPM.bIsHeadless )
   	{
	   	HitZoneIdx = KFPM.HitZones.Find('ZoneName', Impact.HitInfo.BoneName);
	   	if( HitZoneIdx == HZI_Head && KFPM != none && KFPM.IsAliveAndWell() )
		{
			AddToHeadShotCombo( class<KFDamageType>(DamageType), KFPM  );
		}
	}
}

/**
 * @brief Give the use some feedback when a headshot or miss happens
 *
 * @param HeadShotNum Number of successfull headshots in a row
 * @param bMissed If the last shot was a miss
 *
 */
reliable client function HeadShotMessage( byte HeadShotNum, byte DisplayValue, optional bool bMissed=false, optional KFPawn_Monster KFPM )
{
	local int i;
	local AkEvent TempAkEvent;

	if( OwnerPC == none || OwnerPC.MyGFxHUD == none || !IsRhythmMethodActive() )
	{
		return;
	}

	i = HeadshotNum;
	OwnerPC.UpdateRhythmCounterWidget( DisplayValue, MaxHeadShotComboCount );

	switch( i )
	{
		case 0:
			TempAkEvent = RhythmMethodSoundReset;
			break;
		case 1:	case 2:	case 3:
		case 4:
			if( !bMissed )
			{
				//OwnerPC.ClientSpawnCameraLensEffect(class'KFCameraLensEmit_RackemHeadShot');
				TempAkEvent = RhythmMethodSoundHit;
			}
			break;
		case 5:
			if( !bMissed )
			{
				//OwnerPC.ClientSpawnCameraLensEffect(class'KFCameraLensEmit_RackemHeadShotPing');
				TempAkEvent = RhythmMethodSoundTop;
				i = 6;
			}
			break;
	}

	if( TempAkEvent != none )
	{
		OwnerPC.PlayRMEffect( TempAkEvent, RhytmMethodRTPCName, i );
	}
}

/**
 * @brief Ccccccombo breaker ( Rhytm method )
 */
function SubstractHeadShotCombo()
{
	if( IsRhythmMethodActive() && HeadShotComboCount > 0 )
	{
		--HeadShotComboCount;
		HeadShotComboCountDisplay = HeadShotComboCount;
		HeadShotMessage( HeadShotComboCount, HeadShotComboCountDisplay, true );
	}
	else if( HeadShotComboCount <= 0 )
	{
		ClearTimer( nameOf( SubstractHeadShotCombo ) );
	}
}

reliable private final server function ServerClearHeadShotsCombo()
{
	HeadShotComboCountDisplay = 0;
	HeadShotComboCount = 0;
	HeadShotMessage( HeadShotComboCount, HeadShotComboCountDisplay );
	ClearTimer( nameOf( SubstractHeadShotCombo ) );
}

simulated event bool GetIsHeadShotComboActive()
{
	return IsRhythmMethodActive();
}

/**
 * @brief The Quick Shot skill allows you to shoot faster
 *
 * @param InRate delay between shots
 * @param KFW Equipped weapon
 *
 */
/**simulated function ModifyRateOfFire( out float InRate, KFWeapon KFW )
{
	if( IsQuickShootActive() && IsWeaponOnPerk( KFW ) )
	{
		`QALog( "QuickShoot" @ KFW @ GetPercentage( InRate, ( InRate - InRate *  GetSkillValue( PerkSkills[EGunslingerQuickShoot] ) ) ), bLogPerk );
		InRate -= InRate *  GetSkillValue( PerkSkills[EGunslingerQuickShoot] );
	}
}*/

/**
 * @brief Adds some extra penetration
 *
 * @param Level current perk level
 * @param DamageType the used weapon's damage type
 * @param bForce
 * @return the additional penetrations
 */
simulated function float GetPenetrationModifier( byte Level, class<KFDamageType> DamageType, optional bool bForce  )
{
    // Only buff damage types that are associated with support
    if( (!IsPenetrationActive() && !bForce) || (DamageType == none || !IsDamageTypeOnPerk( Damagetype )) )
    {
        return 0;
    }

    return GetSkillValue( PerkSkills[EGunslingerPenetration] );
}

/**
 * @brief The Shoot'n'move skill lets you move quicker in iron sights
 *
 * @param KFW Weapon equipped
 * @return Speed modifier
 */
simulated event float GetIronSightSpeedModifier( KFWeapon KFW )
{
	if( IsShootnMoveActive() && IsWeaponOnPerk( KFW,, self.class ) )
	{
		return  GetSkillValue( PerkSkills[EGunslingerShootnMove] );
	}

	return 1.f;
}

simulated function ModifyWeaponBopDamping( out float BobDamping, KFWeapon PawnWeapon )
{
	If( IsShootnMoveActive() && IsWeaponOnPerk( PawnWeapon,, self.class ) )
	{
		BobDamping *= default.ShootnMooveBobDamp;
	}
}

/**
 * @brief The Quick Switch skill modifies the weapon switch speed
 *
 * @param ModifiedSwitchTime Duration of putting down or equipping the weapon
 */
simulated function ModifyWeaponSwitchTime( out float ModifiedSwitchTime )
{
	if( IsQuickSwitchActive() )
	{
		`QALog( "QuickSwitch Increase:" @ GetPercentage( ModifiedSwitchTime,  ModifiedSwitchTime * GetSkillValue( PerkSkills[EGunslingerQuickSwitch] ) ), bLogPerk );
		ModifiedSwitchTime *= GetSkillValue( PerkSkills[EGunslingerQuickSwitch] );
	}
}

private function bool HitShouldGiveBodyPartDamage( byte BodyPart )
{
	return BoneBreakerBodyParts.Find( BodyPart ) != INDEX_NONE;
}

private static function float GetBoneBreakerDamage()
{
	return default.BoneBreakerDamage;
}

simulated function bool IgnoresPenetrationDmgReduction()
{
	return IsPenetrationActive();
}

simulated function float GetSnareSpeedModifier()
{
	return IsSkullCrackerActive() ? SnareSpeedModifier : 1.f;
}

simulated function float GetSnarePowerModifier( optional class<DamageType> DamageType, optional byte HitZoneIdx )
{
	if( IsSkullCrackerActive() &&
		DamageType != none &&
		IsDamageTypeOnPerk( class<KFDamageType>(DamageType) ) &&
		HitZoneIdx == HZI_Head )
	{
		return default.SnarePower;
	}

	return 0.f;
}

/*********************************************************************************************
* @name	The ususal getters
********************************************************************************************* */
/**
 * @brief Checks if the Shoot'n'move skill is active
 *
 * @return true/false
 */
simulated function bool IsShootnMoveActive()
{
	return PerkSkills[EGunslingerShootnMove].bActive && IsPerkLevelAllowed(EGunslingerShootnMove);
}

/**
 * @brief Checks if the Quick Switch skill is active
 *
 * @return true/false
 */
simulated function bool IsQuickSwitchActive()
{
	return PerkSkills[EGunslingerQuickSwitch].bActive && IsPerkLevelAllowed(EGunslingerQuickSwitch);
}

/**
 * @brief Checks if the Rhythm Method skill is active
 *
 * @return true/false
 */
simulated function bool IsRhythmMethodActive()
{
	return PerkSkills[EGunslingerRhythmMethod].bActive && IsPerkLevelAllowed(EGunslingerRhythmMethod);
}

/**
 * @brief Checks if the Bone Breaker skill is active
 *
 * @return true/false
 */
function bool IsBoneBreakerActive()
{
	return PerkSkills[EGunslingerBoneBreaker].bActive && IsPerkLevelAllowed(EGunslingerBoneBreaker);
}

/**
 * @brief Checks if the Speed Reload skill is active
 *
 * @return true/false
 */
simulated function bool IsSpeedReloadActive()
{
	return PerkSkills[EGunslingerSpeedReload].bActive && IsPerkLevelAllowed(EGunslingerSpeedReload);
}

/**
 * @brief Checks if the Quick Shoot skill is active
 *
 * @return true/false
 */
simulated function bool IsPenetrationActive()
{
	return PerkSkills[EGunslingerPenetration].bActive && IsPerkLevelAllowed(EGunslingerPenetration);
}

/**
 * @brief Checks if the Knock'em Down skill is active
 *
 * @return true/false
 */
simulated function bool IsKnockEmDownActive()
{
	return PerkSkills[EGunslingerKnockEmDown].bActive && IsPerkLevelAllowed(EGunslingerKnockEmDown);
}

/**
 * @brief Checks if the Fanfare skill is active
 *
 * @return true/false
 */
simulated function bool IsFanfareActive()
{
	return PerkSkills[EGunslingerFanfare].bActive && IsPerkLevelAllowed(EGunslingerFanfare);
}

/**
 * @brief Checks if the Fanfare skill is active and if we are in zed time
 *
 * @return true/false
 */
simulated function bool GetFanfareActive()
{
	return IsFanfareActive();
}

/**
 * @brief Checks if the Uber Ammo skill is active
 *
 * @return true/false
 */
simulated function bool IsUberAmmoActive()
{
	return PerkSkills[EGunslingerUberAmmo].bActive && IsPerkLevelAllowed(EGunslingerUberAmmo);
}

simulated function bool IsSkullCrackerActive()
{
	return PerkSkills[EGunslingerSkullCracker].bActive && IsPerkLevelAllowed(EGunslingerSkullCracker);
}

/**
 * @brief Returns true if the weapon is associated with this perk
 * @details Uses WeaponPerkClass if we do not have a spawned weapon (such as in the trader menu)
 *
 * @param W the weapon
 * @param WeaponPerkClass weapon's perk class (optional)
 *
 * @return true/false
 */
static simulated function bool IsWeaponOnPerk( KFWeapon W, optional array < class<KFPerk> > WeaponPerkClass, optional class<KFPerk> InstigatorPerkClass, optional name WeaponClassName )
{
	if( W != none && default.AdditionalOnPerkWeaponNames.Find( W.class.name ) != INDEX_NONE )
	{
		return true;
	}
    else if (WeaponClassName != '' && default.AdditionalOnPerkWeaponNames.Find(WeaponClassName) != INDEX_NONE)
    {
        return true;
    }

	return super.IsWeaponOnPerk( W, WeaponPerkClass, InstigatorPerkClass, WeaponClassName );
}

/**
 * @brief DamageType on perk?
 *
 * @param KFDT The damage type
 * @return true/false
 */
static function bool IsDamageTypeOnPerk( class<KFDamageType> KFDT )
{
	if( KFDT != none && default.AdditionalOnPerkDTNames.Find( KFDT.name ) != INDEX_NONE )
	{
		return true;
	}

	return super.IsDamageTypeOnPerk( KFDT );
}


simulated static private function float GetQuickSwitychSpeedModifier()
{
	return default.QuickSwitchSpeedModifier;
}


event Destroyed()
{
	if( Role == Role_Authority )
	{
		ServerClearHeadShotsCombo();
	}
}

simulated function PlayerDied()
{
	if( Role == Role_Authority )
	{
		ServerClearHeadShotsCombo();
	}
}

/*********************************************************************************************
* @name	 UI
********************************************************************************************* */

static function int GetMaxHeadShotsValue()
{
	return default.MaxHeadShotComboCount;
}

simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( GetPassiveValue( default.WeaponDamage, Level, default.WeaponDamage.Rank ) * 100 ) @ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.BulletResistance, Level, default.BulletResistance.Rank ) * 100 ) @ "%";
	PassiveValues[2] = Round( GetPassiveValue( default.MovementSpeed, Level, default.MovementSpeed.Rank ) * 100 ) @ "%";
	PassiveValues[3] = Round( GetPassiveValue( default.Recoil, Level, default.Recoil.Rank ) * 100 ) @ "%";
	PassiveValues[4] = Round( GetPassiveValue( default.ZedTimeReload, Level, default.ZedTimeReload.Rank ) * 100 ) @ "%";

	Increments[0] = "[" @ Left( string( default.WeaponDamage.Increment * 100 ), InStr(string(default.WeaponDamage.Increment * 100), ".") + 2 )  @ "% / +" $ default.WeaponDamage.Rank @ default.LevelString @ "]";
	Increments[1] = "[" @ "5% +" @ Left( string( default.BulletResistance.Increment * 100 ), InStr(string(default.BulletResistance.Increment * 100), ".") + 2 )  @ "% / +" $ default.BulletResistance.Rank @ default.LevelString @ "]";
	Increments[2] = "[" @ Left( string( default.MovementSpeed.Increment * 100 ), InStr(string(default.MovementSpeed.Increment * 100), ".") + 2 )  @ "% / +" $ default.MovementSpeed.Rank @ default.LevelString @ "]";
	Increments[3] = "[" @ Left( string( default.Recoil.Increment * 100 ), InStr(string(default.Recoil.Increment * 100), ".") + 2 )  @ "% / +" $ default.Recoil.Rank @ default.LevelString @ "]";
	Increments[4] = "[" @ Left( string( default.ZedTimeReload.Increment * 100 ), InStr(string(default.ZedTimeReload.Increment * 100), ".") + 2 )  @ "% / +" $ default.ZedTimeReload.Rank @ default.LevelString @ "]";
}

/*********************************************************************************************
* @name	 debug
********************************************************************************************* */
/** QA Logging - Report Perk Info */
simulated function LogPerkSkills()
{
	super.LogPerkSkills();

	if( bLogPerk )
	{
		`log( "PASSIVE PERKS" );
		`log( "-WeaponDamage:" @ GetPassiveValue( WeaponDamage, CurrentVetLevel, WeaponDamage.Rank ) * 100 $ "%" );
		`log( "-BulletResistance:" @ GetPassiveValue( BulletResistance, CurrentVetLevel, BulletResistance.Rank ) * 100 $ "%" );
		`log( "-MovementSpeed:" @ GetPassiveValue( MovementSpeed, CurrentVetLevel, MovementSpeed.Rank ) * 100 $ "%" );
		`log( "-Recoil:" @ GetPassiveValue( Recoil, CurrentVetLevel, Recoil.Rank ) * 100 $ "%" );

	    `log( "Skill Tree" );
	    `log( "-Shot n Move:" @ PerkSkills[EGunslingerShootnMove].bActive );
	    `log( "-QuickSwitch:" @ PerkSkills[EGunslingerQuickSwitch].bActive );
	    `log( "-RhythmMethod:" @ PerkSkills[EGunslingerRhythmMethod].bActive );
	    `log( "-BoneBreaker:" @ PerkSkills[EGunslingerBoneBreaker].bActive );
	    `log( "-SpeedReload:" @ PerkSkills[EGunslingerSpeedReload].bActive );
	    `log( "-Penetration:" @ PerkSkills[EGunslingerPenetration].bActive );
	    //`log( "-CenterMass:" @ PerkSkills[EGunslingerCenterMass].bActive );
	    //`log( "-LimbShots:" @ PerkSkills[EGunslingerLimbShots].bActive );
	    `log( "-Fanfare:" @ PerkSkills[EGunslingerFanfare].bActive );
	    `log( "-UberAmmo:" @ PerkSkills[EGunslingerUberAmmo].bActive );
	}
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
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[163]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
	PrimaryWeaponDef=class'KFWeapDef_Remington1858Dual'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
	KnifeWeaponDef=class'KFWeapDef_Knife_Gunslinger'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Gunslinger'

	ProgressStatID=STATID_Guns_Progress
   	PerkBuildStatID=STATID_Guns_Build

   	ShootnMooveBobDamp=1.11f

   	MaxHeadShotComboCount=5
   	RhytmMethodRTPCName="R_Method"
   	RhythmMethodSoundReset=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Reset'
	RhythmMethodSoundHit=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Hit'
	RhythmMethodSoundTop=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Top'
	QuickSwitchSpeedModifier=0.05
	QuickSwitchRecoilModifier=0.5f
	HeadShotCountdownIntervall=2.f
	BoneBreakerDamage=0.3f //this is for arms and legs
	SnarePower=100 //this is for the head hit. need to test out if 100 is to powerful or not.
	SnareSpeedModifier=0.7f

   	WeaponDamage=(Name="Weapon Damage",Increment=0.01f,Rank=1,StartingValue=0.0f,MaxValue=0.25f)
   	BulletResistance=(Name="Bullet Resistance",Increment=0.01f,Rank=1,StartingValue=0.05f,MaxValue=0.3f)
   	MovementSpeed=(Name="Movement Speed",Increment=0.008f,Rank=1,StartingValue=0.0f,MaxValue=0.20f)
   	Recoil=(Name="Recoil",Increment=0.01f,Rank=1,StartingValue=0.0f,MaxValue=0.25f)
   	ZedTimeReload=(Name="Zed Time Reload",Increment=0.03f,Rank=1,StartingValue=0.f,MaxValue=0.75f) //0.5

   	// xp per headshot (all headshots, not just lethal)
   	SecondaryXPModifier(0)=1
   	SecondaryXPModifier(1)=1
   	SecondaryXPModifier(2)=1
   	SecondaryXPModifier(3)=1

   	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"
   	ZedTimeModifyingStates(3)="WeaponSingleFireAndReload"
    ZedTimeModifyingStates(4)="Reloading"
    ZedTimeModifyingStates(5)="AltReloading"

   	SpecialZedClassNames(0)="KFPawn_ZedFleshpound";

   	AdditionalOnPerkWeaponNames(0)="KFWeap_Pistol_9mm"
   	AdditionalOnPerkWeaponNames(1)="KFWeap_Pistol_Dual9mm"
   	AdditionalOnPerkWeaponNames(2)="KFWeap_GrenadeLauncher_HX25"
   	AdditionalOnPerkDTNames(0)="KFDT_Ballistic_9mm"
   	AdditionalOnPerkDTNames(1)="KFDT_Ballistic_Pistol_Medic"
   	AdditionalOnPerkDTNames(2)="KFDT_Ballistic_Winchester"
   	AdditionalOnPerkDTNames(3)="KFDT_Ballistic_HX25Impact"
   	AdditionalOnPerkDTNames(4)="KFDT_Ballistic_HX25SubmunitionImpact"

   	PerkSkills(EGunslingerShootnMove)=(Name="ShootnMove",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_Steady",Increment=0.f,Rank=0,StartingValue=2.f,MaxValue=2.f)
	PerkSkills(EGunslingerQuickSwitch)=(Name="QuickSwitch",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_QuickSwitch",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(EGunslingerRhythmMethod)=(Name="RhythmMethod",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_RackEmUp",Increment=0.f,Rank=0,StartingValue=0.1f,MaxValue=0.1f)
	PerkSkills(EGunslingerBoneBreaker)=(Name="BoneBreaker",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_BoneBreaker",Increment=0.f,Rank=0,StartingValue=0.2f,MaxValue=0.2f)
	PerkSkills(EGunslingerSpeedReload)=(Name="SpeedReload",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_SpeedReload",Increment=0.f,Rank=0,StartingValue=0.0f,MaxValue=0.0f)
	PerkSkills(EGunslingerPenetration)=(Name="Penetration",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_LineEmUp",Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)
	PerkSkills(EGunslingerSkullcracker)=(Name="Skullcracker",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_Skullcracker",Increment=0.f,Rank=0,StartingValue=2.0,MaxValue=2.0)
	PerkSkills(EGunslingerKnockEmDown)=(Name="KnockEmDown",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_KnockEmDown",Increment=0.f,Rank=0,StartingValue=4.1f,MaxValue=4.1f) //5.1 //10.1
	PerkSkills(EGunslingerFanfare)=(Name="Fanfare",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_ZEDSpeed",Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)
	PerkSkills(EGunslingerUberAmmo)=(Name="UberAmmo",IconPath="UI_PerkTalent_TEX.Gunslinger.UI_Talents_Gunslinger_ZEDAmmo",Increment=0.f,Rank=0,StartingValue=0.0f,MaxValue=0.0f)

    // Skill tracking
	HitAccuracyHandicap=-5.0
	HeadshotAccuracyHandicap=-8.0

	// Prestige Rewards
	PrestigeRewardItemIconPaths[0]="WEP_SkinSet_Prestige01_Item_TEX.knives.GunslingerKnife_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[1]="WEP_SkinSet_Prestige02_Item_TEX.tier01.Remington1858_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[2]="WEP_skinset_prestige03_itemtex.tier02.M1911_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[3]="wep_skinset_prestige04_itemtex.tier03.DesertEagle_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[4]="WEP_SkinSet_Prestige05_Item_TEX.tier04.500MagnumRevolver_PrestigePrecious_Mint_large"

	BodyPartsCanStumble(0)=0
	BodyPartsCanStumble(1)=2
	BodyPartsCanStumble(3)=3

	BodyPartsCanKnockdown(0)=4
	BodyPartsCanKnockdown(1)=5

	BoneBreakerBodyParts(0)=2
	BoneBreakerBodyParts(1)=3
	BoneBreakerBodyParts(2)=4
	BoneBreakerBodyParts(3)=5

/**	BP_Torso                =0,
    BP_Head                 =1,
    BP_LeftArm              =2,
    BP_RightArm             =3,
    BP_LeftLeg              =4,
    BP_RightLeg             =5,
    BP_Special              =6,
    BP_MAX                  =7,*/
    AutoBuyLoadOutPath=(class'KFWeapDef_Remington1858', class'KFWeapDef_Remington1858Dual', class'KFWeapDef_Colt1911', class'KFWeapDef_Colt1911Dual',class'KFWeapDef_Deagle', class'KFWeapDef_DeagleDual', class'KFWeapDef_SW500', class'KFWeapDef_SW500Dual')

    // Classic Perk
    BasePerk=class'KFPerk_Gunslinger'
    EXPActions(0)="Dealing Gunslinger weapon damage"
    EXPActions(1)="Killing Zeds with a Gunslinger weapon"
}
