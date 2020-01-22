class ApocPerk_Firebug extends ClassicPerk_Base;

//`include(KFOnlineStats.uci)

var 	const	PerkSkill			WeaponReload;              			// 1% faster perk weapon reload per level (max 25%)
var 	const	PerkSkill			FireResistance;            			// 30% resistance to fire, additional 2% resistance per level (max 80%)
var 	const	PerkSkill			OwnFireResistance;           		// 25% resistance to personal fire damage (max 100%)
var 	const	PerkSkill			StartingAmmo;   	        		// 5% more starting ammo for every 5 levels (max 25%)

 /** The range that an enemy needs to be within for the "Heat Wave" skill to function */
var 	const 	int 				HeatWaveRadiusSQ;

/** Chance that zeds will explode from the Shrapnel skill */
var		const	float 				ShrapnelChance;
var 			GameExplosion		ExplosionTemplate;

var	private	const float				SnarePower;
var private const float				SnareSpeedModifier;
var private const class<DamageType> SnareCausingDmgTypeClass;
var private const int 				NapalmDamage;
/** Multiplier on CylinderComponent.CollisionRadius to check for infecting other zeds */
var private const float 			NapalmCheckCollisionScale;


enum EFirebugSkills
{
	EFirebugBringTheHeat,
	EFirebugHighCapFuelTank,
	EFirebugFuse,
	EFirebugGroundFire,
	EFirebugNapalm,
	EFirebugZedShrapnel,
	EFirebugSplashDamage,
	EFirebugRange,
	EFirebugScorch,
	EFirebugInferno
};

/*********************************************************************************************
* @name	 Perk init and spawning
******************************************************************************************** */

/** (Server) Modify Instigator settings based on selected perk */
function ApplySkillsToPawn()
{
	super.ApplySkillsToPawn();

	if( MyPRI != none )
	{
		MyPRI.bExtraFireRange = IsRangeActive();
		MyPRI.bSplashActive = IsGroundFireActive();
	}
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
		TempDamage *= GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank );

		if( IsBringTheHeatActive() )
		{
			TempDamage += InDamage * GetSkillValue( PerkSkills[EFirebugBringTheHeat] );
		}

		if( IsInfernoActive() )
		{
			TempDamage += InDamage * GetSkillValue( PerkSkills[EFirebugInferno] );
		}
	}

	if( IsGroundFireActive() && DamageType != none && ClassIsChildOf( DamageType,  SnareCausingDmgTypeClass ) )
	{
		TempDamage += InDamage * GetSkillValue( PerkSkills[EFirebugGroundFire] );
	}

	`QALog( "Total Damage Given" @ DamageType @ KFW @ GetPercentage( InDamage, Round( TempDamage ) ), bLogPerk );
	InDamage = Round( TempDamage );
}

/**
 * @brief Modifies the reload speed for the flamethrower
 *
 * @param ReloadDuration Length of the reload animation
 * @param GiveAmmoTime Time after the weapon actually gets some ammo
 */
simulated function float GetReloadRateScale(KFWeapon KFW)
{
	if( IsWeaponOnPerk( KFW,, self.class ) )
	{
		return 1.f - GetPassiveValue( WeaponReload, CurrentLevel, WeaponReload.Rank );
	}

	return 1.f;
}

/**
 * @brief Modifies the damage taken
 *
 * @param InDamage damage
 * @param DamageType the damage type used (optional)
 * @param InstigatedBy damage instigator (optional)
 */
function ModifyDamageTaken( out int InDamage, optional class<DamageType> DamageType, optional Controller InstigatedBy )
{
	local float TempDamage;
	local PerkSkill UsedResistance;

	if( InDamage <= 0 )
	{
		return;
	}

	TempDamage = InDamage;

	if( ClassIsChildOf( DamageType, class'KFDT_Fire' ) )
	{
		UsedResistance = (InstigatedBy != none && InstigatedBy == OwnerPC) ? OwnFireResistance : FireResistance;
		`QALog( "UsedResistance" @ UsedResistance.Name, bLogPerk );
		TempDamage *= 1 - GetPassiveValue( UsedResistance, CurrentLevel, UsedResistance.Rank );
	}

	`QALog( "Total Damage Resistance" @ DamageType @ GetPercentage( InDamage, Round(TempDamage) ), bLogPerk );
	InDamage = Round( TempDamage );
}

/**
 * @brief Modifies starting spare ammo
 *
 * @param KFW The weapon
 * @param PrimarySpareAmmo ammo amount
 * @param TraderItem the weapon's associated trader item info
 */
simulated function ModifySpareAmmoAmount( KFWeapon KFW, out int PrimarySpareAmmo, optional const out STraderItem TraderItem, optional bool bSecondary )
{
	local float TempSpareAmmoAmount;
	local array< class<KFPerk> > WeaponPerkClass;

	if( KFW == none )
	{
		WeaponPerkClass = TraderItem.AssociatedPerkClasses;
	}
	else
	{
		WeaponPerkClass = KFW.GetAssociatedPerkClasses();
	}

	if( IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) )
	{
			TempSpareAmmoAmount = PrimarySpareAmmo;
			TempSpareAmmoAmount *= 1 + GetStartingAmmoPercent( CurrentLevel );
			`QALog( "Mod Spare Ammo, Primary" @ KFW @ "Original" @ PrimarySpareAmmo @ "Now" @ Round( TempSpareAmmoAmount ), bLogPerk );
			PrimarySpareAmmo = Round( TempSpareAmmoAmount );
	}
}

/**
 * @brief Sets spare ammo to maximum (can't use ModifySpareAmmoAmount because we need a weapon or a weapon class and ModifySpareAmmoAmount potentially provides neither)
 *
 * @param WeaponPerkClass the weapon's associated perk class
 * @param PrimarySpareAmmo "out" ammo amount
 * @param MaxPrimarySpareAmmo maximum to set spare ammo to
 */
simulated function MaximizeSpareAmmoAmount( array< Class<KFPerk> >  WeaponPerkClass, out int PrimarySpareAmmo, int MaxPrimarySpareAmmo )
{
	// basically IsWeaponOnPerk
}

/**
 * @brief Calculates the additional starting ammo
 *
 * @param Level Current perk level
 * @return additional ammo in perc
 */
simulated static private final function float GetStartingAmmoPercent( int Level )
{
	return default.StartingAmmo.Increment * FFloor( float( Level ) / 5.f );
}

/*********************************************************************************************
* @name	 Selectable skills
********************************************************************************************* */

/**
 * @brief Modifies the DoT length
 *
 * @param DotScaler The time scaler
 * @param KFDT The damage type used
 */
function float GetDoTScalerAdditions(class<KFDamageType> KFDT)
{
	local float ScalarAdditions;

	if (IsDamageTypeOnPerk(KFDT))
	{
		if (IsFuseActive())
		{
			ScalarAdditions += GetSkillValue(PerkSkills[EFirebugFuse]);
		}

		if (IsNapalmActive())
		{
			ScalarAdditions += GetSkillValue(PerkSkills[EFirebugNapalm]);
		}
	}

	return ScalarAdditions;
}

static function int GetNapalmDamage()
{
	return default.NapalmDamage;
}

/**
 * @brief Checks if we are in point blank range
 *
 * @param KFP the pawn to check the distyance to (squared)
 * @return in range or not
 */
function bool InHeatRange( KFPawn KFP )
{
	return VSizeSQ( OwnerPawn.Location - KFP.Location ) <= HeatWaveRadiusSQ;
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

	if( IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) && IsHighCapFuelTankActive() )
	{
		TempCapacity += MagazineCapacity * GetSkillValue( PerkSkills[EFirebugHighCapFuelTank] );
	}

	MagazineCapacity = Round(TempCapacity);
}

/**
 * @brief Checks if we have the napalm skill selected and able to spread some love
 *
 * @return true if active
 */
function bool CanSpreadNapalm()
{
	return IsNapalmActive();
}

static final function float GetNapalmCheckCollisionScale()
{
	return default.NapalmCheckCollisionScale;
}

/**
 * @brief Checks if a zed could potentially explode later
 *
 * @param KFDT damage type used to deal damage
 * @return if the zed could explode when dying
 */
function bool CouldBeZedShrapnel( class<KFDamageType> KFDT )
{
	return IsZedShrapnelActive() && IsDamageTypeOnPerk( KFDT );
}

/**
 * @brief Modifies the splash damage given to a pawn
 *
 * @return The damage multiplier
 */
simulated function float GetSplashDamageModifier()
{
	`QALog( "SplashDamage Mod" @ ( IsSplashDamageActive() ? GetSkillValue( PerkSkills[EFirebugSplashDamage] ) : 1.f ), bLogPerk );
	return IsSplashDamageActive() ? GetSkillValue( PerkSkills[EFirebugSplashDamage] ) : 1.f;
}

/**
 * @brief Checks if a Zed should explode
 *
 * @return explode or not
 */
simulated function bool ShouldShrapnel()
{
	return IsZedShrapnelActive() && fRand() <= default.ShrapnelChance;
}

/**
 * @brief The Zed shrapnel skill can spawn an explosion, this function delivers the template
 *
 * @return A game explosion template
 */
function GameExplosion GetExplosionTemplate()
{
	return default.ExplosionTemplate;
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

	if( GetScorchActive() && IsWeaponOnPerk( W,, self.class ) )
	{
		StateName = W.GetStateName();
		if( ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE )
		{
			`QALog( "Scorch Modifier" @ StateName @ GetSkillValue( PerkSkills[EFirebugScorch] ), bLogPerk );
			return GetSkillValue( PerkSkills[EFirebugScorch] );
		}
	}

	return 0.f;
}

/**
 * @brief skills and weapons can modify the stumbling power
 * @return stumpling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	if( IsHeatWaveActive() && IsDamageTypeOnPerk(DamageType) && InHeatRange(KFP) )
	{
		CooldownModifier = GetSkillValue( PerkSkills[EFirebugSplashDamage] );
		return 1000.f;
	}

	CooldownModifier = 1.f;
	return 0.f;
}

simulated function float GetSnareSpeedModifier()
{
	return IsGroundFireActive() ? SnareSpeedModifier : 1.f;
}

simulated function float GetSnarePowerModifier( optional class<DamageType> DamageType, optional byte HitZoneIdx )
{
	if( IsGroundFireActive() &&	DamageType != none &&
		ClassIsChildOf( DamageType,  SnareCausingDmgTypeClass ) )
	{
		return default.SnarePower;
	}

	if( IsInfernoActive() && IsDamageTypeOnPerk( class<KFDamageType>(DamageType) ) )
	{
		return default.SnarePower;
	}

	return 0.f;
}

/**
 * @brief Checks if Rapid Assault is selected and if the weapon is on perk
 *
 * @param KFW Weapon used
 * @return true or false
 */
simulated function bool GetIsUberAmmoActive( KFWeapon KFW )
{
	return IsWeaponOnPerk( KFW,, self.class ) && GetScorchActive();
}

/*********************************************************************************************
* @name	 Getters etc
********************************************************************************************* */

/**
 * @brief Checks if Fully stocked skill is active (client & server)
 *
 * @return true/false
 */
simulated final private function bool IsBringTheHeatActive()
{
	return PerkSkills[EFirebugBringTheHeat].bActive && IsPerkLevelAllowed(EFirebugBringTheHeat);
}

/**
 * @brief Checks if the Flarotov Cocktail skill is active
 *
 * @return true/false
 */
simulated function bool IsHighCapFuelTankActive()
{
	return PerkSkills[EFirebugHighCapFuelTank].bActive && IsPerkLevelAllowed(EFirebugHighCapFuelTank);
}

/**
 * @brief Checks if the Flarotov Cocktail skill is active
 *
 * @return true/false
 */
simulated final private function bool IsFuseActive()
{
	return PerkSkills[EFirebugFuse].bActive && IsPerkLevelAllowed(EFirebugFuse);
}

/**
 * @brief Checks if the Ground Fire skill is active
 *
 * @return true/false
 */
simulated final private function bool IsGroundFireActive()
{
	return PerkSkills[EFirebugGroundFire].bActive && IsPerkLevelAllowed(EFirebugGroundFire);
}

simulated function bool IsFlarotovActive()
{
	return true;
}

/**
 * @brief Checks if the Heat wave skill is active
 *
 * @return true/false
 */
simulated final private function bool IsHeatWaveActive()
{
	return PerkSkills[EFirebugSplashDamage].bActive && IsPerkLevelAllowed(EFirebugSplashDamage);
}

/**
 * @brief Checks if the Zed Shrapnel skill is active
 *
 * @return true/false
 */
simulated final private function bool IsZedShrapnelActive()
{
	return PerkSkills[EFirebugZedShrapnel].bActive && IsPerkLevelAllowed(EFirebugZedShrapnel);
}

/**
 * @brief Checks if the Napalm skill is active
 *
 * @return true/false
 */
simulated final private function bool IsNapalmActive()
{
	return PerkSkills[EFirebugNapalm].bActive && IsPerkLevelAllowed(EFirebugNapalm);
}

/**
 * @brief Checks if the Range skill is active
 *
 * @return true/false
 */
simulated function bool IsRangeActive()
{
	return PerkSkills[EFirebugRange].bActive && IsPerkLevelAllowed(EFirebugRange);
}

/**
 * @brief Checks if the Splash Damage skill is active
 *
 * @return true/false
 */
simulated final private function bool IsSplashDamageActive()
{
	return false;
}

/**
 * @brief Checks if the Inferno skill is active
 *
 * @return true/false
 */
simulated final private function bool IsInfernoActive()
{
	return PerkSkills[EFirebugInferno].bActive && WorldInfo.TimeDilation < 1.f && IsPerkLevelAllowed(EFirebugInferno);
}

/**
 * @brief Checks if the Heat wave skill is active and if we are in Zed time
 *
 * @return true/false
 */
simulated final private function bool GetScorchActive()
{
	return IsScorchActive() && WorldInfo.TimeDilation < 1.f;
}

/**
 * @brief Checks if the Heat wave skill is active
 *
 * @return true/false
 */
simulated final private function bool IsScorchActive()
{
	return PerkSkills[EFirebugScorch].bActive && IsPerkLevelAllowed(EFirebugScorch);
}


/*********************************************************************************************
* @name	 Stats/XP
********************************************************************************************* */

/**
 * @brief how much XP is earned by a crawler kill depending on the game's difficulty
 *
 * @param Difficulty current game difficulty
 * @return XP earned
 */
simulated static function int GetCrawlerKillXP( byte Difficulty )
{
	return default.SecondaryXPModifier[Difficulty];
}

/**
 * @brief how much XP is earned by a bloat kill depending on the game's difficulty
 *
 * @param Difficulty current game difficulty
 * @return XP earned
 */
simulated static function int GetBloatKillXP( byte Difficulty )
{
	// Currently the same XP as a crawler
	return default.SecondaryXPModifier[Difficulty];
}
/*********************************************************************************************
* @name	 UI
********************************************************************************************* */
simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( GetPassiveValue( default.WeaponDamage, Level, default.WeaponDamage.Rank ) * 100  - 100 ) @ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.WeaponReload, Level, default.WeaponReload.Rank ) * 100 ) @ "%";
	PassiveValues[2] = Round( GetPassiveValue( default.FireResistance, Level, default.FireResistance.Rank ) * 100 ) @ "%";
	PassiveValues[3] = Round( GetPassiveValue( default.OwnFireResistance, Level, default.OwnFireResistance.Rank ) * 100 ) @ "%";
	PassiveValues[4] = Round( GetStartingAmmoPercent( Level ) * 100 ) @ "%";

	Increments[0] = "[" @ Left( string( default.WeaponDamage.Increment * 100 ), InStr(string(default.WeaponDamage.Increment * 100), ".") + 2 ) @ "% / +" $ default.WeaponDamage.Rank @ default.LevelString @ "]";
	Increments[1] = "[" @ Left( string( default.WeaponReload.Increment * 100 ), InStr(string(default.WeaponReload.Increment * 100), ".") + 2 ) @ "% / +" $ default.WeaponReload.Rank @ default.LevelString @ "]";
	Increments[2] = "[" @ Left( string( default.FireResistance.StartingValue * 100 ), InStr(string(default.FireResistance.StartingValue * 100), ".") + 2 ) @ "%" @ "+"
						@Left( string( default.FireResistance.Increment * 100 ), InStr(string(default.FireResistance.Increment * 100), ".") + 2 ) @ "% / +" $ default.FireResistance.Rank @ default.LevelString @ "]";
	Increments[3] = "[" @ Left( string( default.OwnFireResistance.StartingValue * 100 ), InStr(string(default.OwnFireResistance.StartingValue * 100), ".") + 2 ) @ "%" @ "+"
						@Left( string( default.OwnFireResistance.Increment * 100 ), InStr(string(default.OwnFireResistance.Increment * 100), ".") + 2 )  @ "% / +" $ default.OwnFireResistance.Rank @ default.LevelString @ "]";
	Increments[4] = "[" @ Left( string( default.StartingAmmo.Increment * 100 ), InStr(string(default.StartingAmmo.Increment * 100), ".") + 2 )@ "% / +" $ default.StartingAmmo.Rank @ default.LevelString @ "]";
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
		`log( "-WeaponDamage:" @ GetPassiveValue( default.WeaponDamage, CurrentVetLevel, default.WeaponDamage.Rank ) - 1 $ "%" );
		`log( "-WeaponReload:" @ GetPassiveValue( default.WeaponReload, CurrentVetLevel, default.WeaponReload.Rank ) $ "%" );
		`log( "-FireResistance:" @ GetPassiveValue( default.FireResistance, CurrentVetLevel, default.FireResistance.Rank ) $ "%" );
		`log( "-OwnFireResistance:" @ GetPassiveValue( default.OwnFireResistance, CurrentVetLevel, default.OwnFireResistance.Rank ) $ "%" );
		`log( "-Ammo:" @ GetStartingAmmoPercent( CurrentVetLevel ) $ "%" );

	    `log( "Skill Tree" );
	   // `log( "-FullyStoked:" @ PerkSkills[EFirebugFullyStocked].bActive );
	    //`log( "-FlarotovCoctail:" @ PerkSkills[EFirebugFlarotovCoctail].bActive );
	    `log( "-Fuse:" @ PerkSkills[EFirebugFuse].bActive );
	    //`log( "-HeatWave:" @ PerkSkills[EFirebugHeatWave].bActive );
	    `log( "-ZedShrapnel:" @ PerkSkills[EFirebugZedShrapnel].bActive );
	    `log( "-Napalm:" @ PerkSkills[EFirebugNapalm].bActive );
	    `log( "-Range:" @ PerkSkills[EFirebugRange].bActive );
	    `log( "-SplashDamage:" @ PerkSkills[EFirebugSplashDamage].bActive @ GetSplashDamageModifier() );
	    //`log( "-Combustion:" @ PerkSkills[EFirebugCombustion].bActive );
	    `log( "-Scorch:" @ PerkSkills[EFirebugScorch].bActive );
	}
}

/*********************************************************************************************
* @name	 Classic Perk
******************************************************************************************** */

function AddDefaultInventory( KFPawn P )
{
    Super(ClassicPerk_Base).AddDefaultInventory(P);
}

simulated static function class<KFWeaponDefinition> GetWeaponDef(int Level)
{
    return Super(ClassicPerk_Base).GetWeaponDef(Level);
}

simulated function float GetCostScaling(byte Level, optional STraderItem TraderItem, optional KFWeapon Weapon)
{
    return 1.f;
}

simulated static function array<PassiveInfo> GetPerkInfoStrings(int Level)
{
    return default.PassiveInfos;
}

simulated function GetPerkIcons(ObjectReferencer RepInfo)
{
    local int i;

    for (i = 0; i < OnHUDIcons.Length; i++)
    {
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[64]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
	PrimaryWeaponDef=class'KFWeapDef_CaulkBurn'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
	KnifeWeaponDef=class'KFWeapDef_Knife_Firebug'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Firebug'

	ProgressStatID=STATID_Fire_Progress
   	PerkBuildStatID=STATID_Fire_Build

   	HeatWaveRadiusSQ=90000

    NapalmDamage=7 //50
	NapalmCheckCollisionScale=2.0f //6.0

   	ShrapnelChance=0.3f   //0.2

   	SnarePower=100
	SnareSpeedModifier=0.7
   	SnareCausingDmgTypeClass="KFDT_Fire_Ground"

	WeaponDamage=(Name="Weapon Damage",Increment=0.008f,Rank=1,StartingValue=1.f,MaxValue=1.20) //1.25
	WeaponReload=(Name="Weapon Reload Speed",Increment=0.008f,Rank=1,StartingValue=0.f,MaxValue=0.20)
	FireResistance=(Name="Fire Resistance",Increment=0.02,Rank=2,StartingValue=0.3f,MaxValue=0.8f)
	OwnFireResistance=(Name="Own fire Resistance",Increment=0.03,Rank=1,StartingValue=0.25f,MaxValue=1.f)
	StartingAmmo=(Name="Starting Ammo",Increment=0.1,Rank=5,StartingValue=0.f,MaxValue=0.50)

	PerkSkills(EFirebugBringTheHeat)=(Name="BringTheHeat",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_BringtheHeat",Increment=0.f,Rank=0,StartingValue=0.35f,MaxValue=0.35f) //0.1 //0.25
	PerkSkills(EFirebugHighCapFuelTank)=(Name="HighCapFuelTank",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_HighCapacityFuel",Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)
	PerkSkills(EFirebugFuse)=(Name="Fuse",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_Fuse",Increment=0.f,Rank=0,StartingValue=1.5f,MaxValue=1.5f) //1.7
	PerkSkills(EFirebugGroundFire)=(Name="GroundFire",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_HeatWave",Increment=0.f,Rank=0,StartingValue=2.0f,MaxValue=2.0f) //0.1 //1.0
	PerkSkills(EFirebugZedShrapnel)=(Name="ZedShrapnel",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_ZedShrapnel",Increment=0.f,Rank=0,StartingValue=1.2f,MaxValue=1.2f)
	PerkSkills(EFirebugNapalm)=(Name="Napalm",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_Napalm",Increment=0.f,Rank=0,StartingValue=1.5f,MaxValue=1.5f) //2.5
	PerkSkills(EFirebugRange)=(Name="Range",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_Range",Increment=0.f,Rank=0,StartingValue=0.3f,MaxValue=0.f)
	PerkSkills(EFirebugSplashDamage)=(Name="SplashDamage",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_GroundFire",Increment=0.f,Rank=0,StartingValue=1.f,MaxValue=1.f)
	PerkSkills(EFirebugScorch)=(Name="Scorch",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_Scorch",Increment=0.f,Rank=0,StartingValue=0.9f,MaxValue=0.9f)
	PerkSkills(EFirebugInferno)=(Name="Inferno",IconPath="UI_PerkTalent_TEX.Firebug.UI_Talents_Firebug_Inferno",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)

	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"
   	ZedTimeModifyingStates(3)="SprayingFire"
	ZedTimeModifyingStates(4)="HuskCannonCharge"
	ZedTimeModifyingStates(5)="MeleeChainAttacking"
	ZedTimeModifyingStates(6)="MeleeAttackBasic"
	ZedTimeModifyingStates(7)="MeleeHeavyAttacking"
	ZedTimeModifyingStates(8)="MeleeSustained"

   	SecondaryXPModifier(0)=2
	SecondaryXPModifier(1)=3
	SecondaryXPModifier(2)=3
	SecondaryXPModifier(3)=5

	Begin Object Class=KFGameExplosion Name=ExploTemplate0
		Damage=50  //231  //120
		DamageRadius=250   //840  //600
		DamageFalloffExponent=1
		DamageDelay=0.f
		MyDamageType=class'KFDT_Explosive_Shrapnel'

		// Damage Effects
		//KnockDownStrength=0
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'FX_Explosions_ARCH.FX_Combustion_Explosion'
		ExplosionSound=AkEvent'WW_WEP_EXP_Grenade_Frag.Play_WEP_EXP_Grenade_Frag_Explosion'

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Misc_Explosions.Light_Explosion_Rumble'
		CamShakeInnerRadius=450
		CamShakeOuterRadius=900
		CamShakeFalloff=1.f
		bOrientCameraShakeTowardsEpicenter=true
	End Object
	ExplosionTemplate=ExploTemplate0

    // Skill tracking
	HitAccuracyHandicap=-2.0
	HeadshotAccuracyHandicap=5.0
	AutoBuyLoadOutPath=(class'KFWeapDef_CaulkBurn', class'KFWeapDef_DragonsBreath', class'KFWeapDef_FlameThrower', class'KFWeapDef_MicrowaveGun', class'KFWeapDef_MicrowaveRifle')

    // Classic Perk
    BasePerk=class'KFPerk_Firebug'
    EXPActions(0)="Dealing Firebug weapon damage"
    EXPActions(1)="Killing Crawlers with Firebug weapons"
    PassiveInfos(0)=(Title="Fire Damage")
    PassiveInfos(1)=(Title="Reload Speed")
    PassiveInfos(2)=(Title="Fire Resistance")
    PassiveInfos(3)=(Title="Spare Ammo")
    PassiveInfos(4)=(Title="Magazine Capacity")
}
