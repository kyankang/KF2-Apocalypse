class ApocPerk_Support extends ClassicPerk_Base
	config(ApocPerksStat);

//`include(KFOnlineStats.uci)

struct native sSuppliedPawnInfo
{
	var KFPawn_Human SuppliedPawn;
	var bool bSuppliedAmmo;
	var bool bSuppliedArmor;
};

/** Passives */
var config 	PerkSkill 							Ammo;       				// Increased ammo
var config 	PerkSkill 							WeldingProficiency;         // Welding speed modifier
var	config 	PerkSkill 							ShotgunDamage;              // Shotgun dmg modifier
var	config 	PerkSkill 							ShotgunPenetration;			// Shotgun extra penetration Use INTs only
var	config 	PerkSkill 							Strength;

var	private		  Array<sSuppliedPawnInfo> 		SuppliedPawnList;
var	private const float 						BarrageFiringRate;
var	private const float 						ResupplyMaxSpareAmmoModifier;
var private const AkEvent						ReceivedAmmoSound;
var private const AkEvent 						ReceivedArmorSound;
var private const AkEvent						ReceivedAmmoAndArmorSound;

var private const array<name> 					HighCapMagExemptList;

var	private	const array<Name>					AdditionalOnPerkDTNames;

var	private const int						    DoorRepairXP[4];            // Door repair XP per-difficulty

enum ESupportPerkSkills
{
	ESupportHighCapMags,
	ESupportTacticalReload,
	ESupportFortitude,
	ESupportSalvo,
	ESupportAPShot,
	ESupportTightChoke,
	ESupportResupply,
	ESupportConcussionRounds,
	ESupportPerforate,
	ESupportBarrage,
};

/*********************************************************************************************
* @name	 Perk init and spawning
******************************************************************************************** */
/**
 * @brief(Server) Modify Instigator settings based on selected perk
 */
function ApplySkillsToPawn()
{
	local KFGameReplicationInfo KFGRI;

	Super.ApplySkillsToPawn();

	KFGRI = KFGameReplicationInfo(WorldInfo.GRI);

	if (KFGRI == none && KFGRI.bTraderIsOpen)
	{
		return;
	}
	//ResetSupplier();
}

/**
 * We need to separate this from ApplySkillsToPawn() to avoid resetting weight limits (and losing weapons)
 * every time a skill or level is changed
 */
function ApplyWeightLimits()
{
	local KFInventoryManager KFIM;

	KFIM = KFInventoryManager(OwnerPawn.InvManager);
	if( KFIM != none )
	{
		`QALog( "Strength Mod" @ GetPercentage(KFIM.MaxCarryBlocks, KFIM.default.MaxCarryBlocks + GetExtraStrength( CurrentLevel )), bLogPerk );
		KFIM.MaxCarryBlocks = KFIM.default.MaxCarryBlocks + GetExtraStrength( CurrentLevel );
		CheckForOverWeight( KFIM );
	}
}

/**
 * @brief Calculates the additional carry blocks per perk level
 *
 * @param Level Current perk level
 * @return additional blocks
 */
simulated private final static function float GetExtraStrength( int Level )
{
	return default.Strength.Increment * FFloor( float( Level ) / default.Strength.Rank );
}


/**
 * @brief Sets up the supplier skill
 */
simulated final private function ResetSupplier()
{
	if( MyPRI != none && IsSupplierActive() )
	{
		if( SuppliedPawnList.Length > 0 )
		{
			SuppliedPawnList.Remove( 0, SuppliedPawnList.Length );
		}

		MyPRI.PerkSupplyLevel = IsResupplyActive() ? 2 : 1;

		if( InteractionTrigger != none )
		{
			InteractionTrigger.Destroy();
			InteractionTrigger = none;
		}

		if( CheckOwnerPawn() )
		{
			InteractionTrigger = Spawn( class'KFUsablePerkTrigger', OwnerPawn,, OwnerPawn.Location, OwnerPawn.Rotation,, true );
			InteractionTrigger.SetBase( OwnerPawn );
			InteractionTrigger.SetInteractionIndex( IMT_ReceiveAmmo );
			OwnerPC.SetPendingInteractionMessage();
		}
	}
	else if( InteractionTrigger != none )
	{
		InteractionTrigger.Destroy();
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
	`QALog( GetFuncName() @ "BaseDamage =" @ InDamage, bLogPerk );


	TempDamage = InDamage;

	if( DamageCauser != none )
	{
		KFW = GetWeaponFromDamageCauser( DamageCauser );
	}

	if( ((KFW != none && IsWeaponOnPerk( KFW,, self.class )) || (DamageType != none && IsDamageTypeOnPerk( DamageType ))) &&
		!ClassIsChildOf( DamageType, class'KFDT_Explosive' )  )
	{
		TempDamage += InDamage * GetPassiveValue( ShotgunDamage, CurrentLevel, ShotgunDamage.Rank );
		`QALog( GetFuncName() @ "+ Extra Shotgun Damage =" @ TempDamage, bLogPerk );

		if( IsSalvoActive() )
		{
			TempDamage += InDamage * GetSkillValue( PerkSkills[ESupportSalvo] );
			`QALog( GetFuncName() @ "+ Salvo Damage =" @ TempDamage, bLogPerk );
		}
	}

	`QALog( "Total Damage Given" @ Damagetype @ KFW @ GetPercentage( InDamage, Round(TempDamage) ), bLogPerk );
	InDamage = Round( TempDamage );
}

/** Welding Proficiency - faster welding/unwelding */
/**
 * @brief Modifies the welding speed
 *
 * @param FastenRate how much faster do we weld
 * @param UnfastenRate how much faster do we unweld
 *
  */
simulated function ModifyWeldingRate( out float FastenRate, out float UnfastenRate )
{
	local float WeldingModifier;

	WeldingModifier = GetPassiveValue( WeldingProficiency, CurrentLevel, WeldingProficiency.Rank );
	FastenRate *= WeldingModifier;
	UnFastenRate *= WeldingModifier;
	`QALog( "Welding Modifier" @ WeldingModifier, bLogPerk );
}

/**
 * @brief the higher the level the more can we penetrate
 *
 * @param Level current perk level
 * @param DamageType the use weapon's damage type
 * @param bForce
 * @return the additional penetrations
 */
simulated function float GetPenetrationModifier( byte Level, class<KFDamageType> DamageType, optional bool bForce  )
{
    local float PenetrationPower;
    // Only buff damage types that are associated with support
    if( !bForce && (DamageType == none || !IsDamageTypeOnPerk( Damagetype )) )
    {
        return 0;
    }

    PenetrationPower = IsAPShotActive() ? GetSkillValue( PerkSkills[ESupportAPShot] ) : 0.f;
    PenetrationPower = IsPerforateActive() ? GetSkillValue( PerkSkills[ESupportPerforate] ) : PenetrationPower;
    `QALog( "PenetrationPower" @ PenetrationPower + GetPassiveValue( ShotgunPenetration, Level, ShotgunPenetration.Rank ), bLogPerk );

    return PenetrationPower + GetPassiveValue( ShotgunPenetration, Level, ShotgunPenetration.Rank );
}

simulated function bool IgnoresPenetrationDmgReduction()
{
	return IsPerforateActive();
}

/*********************************************************************************************
* @name	 Selectable skills
********************************************************************************************* */
/**
 * @brief Modifies mag capacity and count
 *
 * @param KFW the weapon
 * @param MagazineCapacity modified mag capacity
 * @param WeaponPerkClass the weapon's associated perk class (optional)
 */
simulated function ModifyMagSizeAndNumber( KFWeapon KFW, out byte MagazineCapacity, optional array< Class<KFPerk> > WeaponPerkClass, optional bool bSecondary=false, optional name WeaponClassName)
{
	local float TempCapacity;

	TempCapacity = MagazineCapacity;

	if( !bSecondary && IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) && (KFW == none || !KFW.bNoMagazine) &&
		HighCapMagExemptList.Find(WeaponClassName) == INDEX_NONE )
	{
		if( IsHighCapMagsMagActive() )
		{
			TempCapacity += MagazineCapacity * GetSkillValue( PerkSkills[ESupportHighCapMags] );
		}
	}

	MagazineCapacity = Round(TempCapacity);
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

	if(KFW == none)
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
		TempSpareAmmoAmount += PrimarySpareAmmo * GetPassiveValue( Ammo, CurrentLevel, Ammo.Rank );
		PrimarySpareAmmo = Round( TempSpareAmmoAmount );
	}
}

/**
 * @brief Modifies the max spare ammo
 *
 * @param KFW The weapon
 * @param PrimarySpareAmmo ammo amount
 * @param TraderItem the weapon's associated trader item info
 */
simulated function ModifyMaxSpareAmmoAmount( KFWeapon KFW, out int MaxSpareAmmo, optional const out STraderItem TraderItem, optional bool bSecondary=false )
{
	local float TempMaxSpareAmmoAmount;
	local array< class<KFPerk> > WeaponPerkClass;

	if(KFW == none)
	{
		WeaponPerkClass = TraderItem.AssociatedPerkClasses;
	}
	else
	{
		WeaponPerkClass = KFW.GetAssociatedPerkClasses();
	}

	if( IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) && MaxSpareAmmo > 0 )
	{
		TempMaxSpareAmmoAmount = MaxSpareAmmo;
		TempMaxSpareAmmoAmount += MaxSpareAmmo * GetPassiveValue( Ammo, CurrentLevel, Ammo.Rank );
		 `QALog( "Ammo Passive, MaxSpareAmmo = +" @ (MaxSpareAmmo + MaxSpareAmmo * GetPassiveValue( Ammo, CurrentLevel, Ammo.Rank )) / MaxSpareAmmo $ "%", bLogPerk );

		if( IsResupplyActive() )
		{
			TempMaxSpareAmmoAmount += MaxSpareAmmo * GetResupplyMaxSpareAmmoModifier();
			`QALog( "Resupply skill, MaxSpareAmmo = +" @ (MaxSpareAmmo + MaxSpareAmmo * GetResupplyMaxSpareAmmoModifier()) / MaxSpareAmmo $ "%", bLogPerk );
		}

		MaxSpareAmmo = Round( TempMaxSpareAmmoAmount );
	}
}

simulated private static function float GetResupplyMaxSpareAmmoModifier()
{
	return default.ResupplyMaxSpareAmmoModifier;
}

/**
 * @brief Should the tactical reload skill adjust the reload speed
 *
 * @param KFW weapon in use
 * @return true/false
 */
simulated function bool GetUsingTactialReload( KFWeapon KFW )
{
	return IsTacticalReloadActive() && (IsWeaponOnPerk( KFW,, self.class ) || IsBackupWeapon( KFW ));
}

/**
 * @brief modifies the players health
 *
 * @param InHealth health
  */
function ModifyHealth( out int InHealth )
{
	local float TempHealth;

	if( IsFortitudeActive() )
	{
		TempHealth = InHealth;
		TempHealth += InHealth * GetSkillValue( PerkSkills[ESupportFortitude] );
		InHealth = FCeil( TempHealth );
	}
}

simulated function float GetTightChokeModifier()
{
	if( IsTightChokeActive() )
	{
		return GetSkillValue( PerkSkills[ESupportTightChoke] );
	}

	return super.GetTightChokeModifier();
}

/**
 * @brief skills and weapons can modify the stumbling power
 * @return stumbling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	if( IsWeaponOnPerk( GetOwnerWeapon(),, self.class ) && IsConcussionRoundsActive() )
	{
		return GetSkillValue( PerkSkills[ESupportConcussionRounds] );
	}

	return 0.f;
}

/**
 * @brief General interaction with another pawn, here: give ammo
 *
 * @param KFPH Pawn to interact with
 */
simulated function Interact( KFPawn_Human KFPH )
{
	local KFWeapon KFW;
	local int Idx, MagCount;
	local KFPlayerController KFPC;
	local KFPlayerReplicationInfo UserPRI, OwnerPRI;
	local bool bCanSupplyAmmo, bCanSupplyArmor;
	local bool bReceivedAmmo, bReceivedArmor;
	local sSuppliedPawnInfo SuppliedPawnInfo;

	// Do nothing if supplier isn't active
	if( !IsSupplierActive() )
	{
		return;
	}

	bCanSupplyAmmo = true;
	bCanSupplyArmor = true;
	Idx = SuppliedPawnList.Find( 'SuppliedPawn', KFPH );
	if( Idx != INDEX_NONE )
	{
		bCanSupplyAmmo = !SuppliedPawnList[Idx].bSuppliedAmmo;
		bCanSupplyArmor = !SuppliedPawnList[Idx].bSuppliedArmor;
		if( !bCanSupplyAmmo && !bCanSupplyArmor )
		{
			return;
		}
	}

	if( bCanSupplyAmmo )
	{
		foreach KFPH.InvManager.InventoryActors( class'KFWeapon', KFW )
		{
			if( KFW.static.DenyPerkResupply() )
			{
				continue;
			}

			// resupply 1 mag for every 5 initial mags
			MagCount = Max( KFW.InitialSpareMags[0] / 1.5, 1 ); // 3, 1
			`QALog( "Supply Ammo Primary Weapon " @ KFW @ MagCount * KFW.MagazineCapacity[0], bLogPerk );
			bReceivedAmmo = (KFW.AddAmmo( MagCount * KFW.MagazineCapacity[0] * (IsResupplyActive() ? 1.3f : 1.0f) ) > 0 ) ? true : bReceivedAmmo;

	        if( KFW.CanRefillSecondaryAmmo() )
	        {
	        	// resupply 1 mag for every 5 initial mags
	        	`QALog( "Supply Ammo Secondary Weapon" @ KFW @ Max( KFW.InitialSpareMags[1] / 3, 1 ), bLogPerk );

	        	// If our secondary ammo isn't mag-based (like the Eviscerator), restore a portion of max ammo instead
	        	bReceivedAmmo = (KFW.AddSecondaryAmmo( Max(KFW.AmmoPickupScale[1] * (IsResupplyActive() ? 1.3f : 1.0f) * KFW.MagazineCapacity[1], 1) ) > 0) ? true : bReceivedAmmo;
	        }
		}
	}

	if( bCanSupplyArmor && IsResupplyActive() && KFPH.Armor != KFPH.GetMaxArmor() )
	{
		KFPH.AddArmor( KFPH.MaxArmor * GetSkillValue( PerkSkills[ESupportResupply] ) );
		bReceivedArmor = true;
	}

	// Add to array (if necessary) and flag as supplied as needed
	if( bReceivedArmor || bReceivedAmmo )
	{
		if( Idx == INDEX_NONE )
		{
			SuppliedPawnInfo.SuppliedPawn = KFPH;
			SuppliedPawnInfo.bSuppliedAmmo = bReceivedAmmo;
			SuppliedPawnInfo.bSuppliedArmor = bReceivedArmor;
			Idx = SuppliedPawnList.Length;
			SuppliedPawnList.AddItem( SuppliedPawnInfo );
		}
		else
		{
			SuppliedPawnList[Idx].bSuppliedAmmo = SuppliedPawnList[Idx].bSuppliedAmmo || bReceivedAmmo;
			SuppliedPawnList[Idx].bSuppliedArmor = SuppliedPawnList[Idx].bSuppliedArmor || bReceivedArmor;
		}

		if( Role == ROLE_Authority )
		{
			KFPC = KFPlayerController( KFPH.Controller );
			if( bReceivedAmmo )
			{
				OwnerPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', bReceivedArmor ? GMT_GaveAmmoAndArmorTo : GMT_GaveAmmoTo, KFPC.PlayerReplicationInfo );
				KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', bReceivedArmor ? GMT_ReceivedAmmoAndArmorFrom : GMT_ReceivedAmmoFrom, OwnerPC.PlayerReplicationInfo );
			}
			else if( bReceivedArmor )
			{
				OwnerPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_GaveArmorTo, KFPC.PlayerReplicationInfo );
				KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_ReceivedArmorFrom, OwnerPC.PlayerReplicationInfo );
			}

			UserPRI = KFPlayerReplicationInfo( KFPC.PlayerReplicationInfo );
			OwnerPRI = KFPlayerReplicationInfo( OwnerPC.PlayerReplicationInfo );
			if( UserPRI != none && OwnerPRI != none )
			{
				UserPRI.MarkSupplierOwnerUsed( OwnerPRI, SuppliedPawnList[Idx].bSuppliedAmmo, SuppliedPawnList[Idx].bSuppliedArmor );
			}
		}
	}
	else if( Role == ROLE_Authority )
	{
		KFPC = KFPlayerController( KFPH.Controller );
		if( IsResupplyActive() )
		{
			KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_AmmoAndArmorAreFull, OwnerPC.PlayerReplicationInfo );
		}
		else
		{
			KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_AmmoIsFull, OwnerPC.PlayerReplicationInfo );
		}
	}
}

/**
 * @brief Can other pawns interact with us?
 *
 * @param MyKFPH the other pawn
 * @return true/false
 */
simulated function bool CanInteract( KFPawn_HUman MyKFPH )
{
	local int Idx;

	if( IsSupplierActive() )
	{
		Idx = SuppliedPawnList.Find( 'SuppliedPawn', MyKFPH );

		// Pawn hasn't gotten anything from us yet
		if( Idx == INDEX_NONE )
		{
			return true;
		}

		// Resupply is active and pawn hasn't gotten armor yet
		if( IsResupplyActive() && !SuppliedPawnList[Idx].bSuppliedArmor )
		{
			return true;
		}

		// Pawn hasn't gotten ammo
		return !SuppliedPawnList[Idx].bSuppliedAmmo;
	}
}

simulated static function AKEvent GetReceivedAmmoSound()
{
	return default.ReceivedAmmoSound;
}

simulated static function AKEvent GetReceivedArmorSound()
{
	return default.ReceivedArmorSound;
}

simulated static function AKEvent GetReceivedAmmoAndArmorSound()
{
	return default.ReceivedAmmoAndArmorSound;
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

	if( IsWeaponOnPerk( W,, self.class ) && CouldBarrageActive() &&
		ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE )
	{
		return BarrageFiringRate;
	}

	return 0.f;
}

/**
* @brief Resets certain perk values on wave start/end
*/
function OnWaveStart()
{
	Super.OnWaveStart();
	ResetSupplier();
}

simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( (GetPassiveValue( default.WeldingProficiency, Level, default.WeldingProficiency.Rank ) - 1) * 100) $ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.ShotgunDamage, Level, default.ShotgunDamage.Rank ) * 100) $ "%";
	PassiveValues[2] = Round( GetPassiveValue( default.ShotgunPenetration, Level, default.ShotgunPenetration.Rank ) * 100) $ "%";
	PassiveValues[3] = Round( GetPassiveValue( default.Ammo, Level, default.Ammo.Rank ) * 100) $ "%";
	PassiveValues[4] = "";
	PassiveValues[5] = "";

	Increments[0] = "[" @ Left( string( default.WeldingProficiency.Increment * 100 ), InStr(string(default.WeldingProficiency.Increment * 100), ".") + 2 )	$ "% /" @ default.LevelString @ "]";
	Increments[1] = "[" @ Left( string( default.ShotgunDamage.Increment * 100 ), InStr(string(default.ShotgunDamage.Increment * 100), ".") + 2 )			$ "% /" @ default.LevelString @ "]";
	Increments[2] = "[" @ Left( string( default.ShotgunPenetration.Increment * 100 ), InStr(string(default.ShotgunPenetration.Increment * 100), ".") + 2 )	$ "% /" @ default.LevelString @ "]";
	Increments[3] = "[" @ Left( string( default.Ammo.Increment * 100 ), InStr(string(default.Ammo.Increment * 100), ".") + 2 )								$ "% /" @ default.LevelString @ "]";
	Increments[4] = "";
	Increments[5] = "";
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

/*********************************************************************************************
* @name	 Getters
********************************************************************************************* */
/**
 * @brief Checks if the supplier skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsSupplierActive()
{
	return true;
}

/**
 * @brief Checks if the barrage skill is active and if we are in zed time
 *
 * @return true if we have the skill enabled
 */
private function bool IsBarrageActive()
{
	return PerkSkills[ESupportBarrage].bActive && WorldInfo.TimeDilation < 1.f && IsPerkLevelAllowed(ESupportBarrage);
}

simulated private function bool CouldBarrageActive()
{
	return PerkSkills[ESupportBarrage].bActive && IsPerkLevelAllowed(ESupportBarrage);
}

/**
 * @brief Checks if the ammo skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private function bool IsHighCapMagsMagActive()
{
	return PerkSkills[ESupportHighCapMags].bActive && IsPerkLevelAllowed(ESupportHighCapMags);
}

/**
 * @brief Checks if the fortitude skill is active
 *
 * @return true if we have the skill enabled
 */
private function bool IsFortitudeActive()
{
	return PerkSkills[ESupportFortitude].bActive && IsPerkLevelAllowed(ESupportFortitude);
}

/**
 * @brief Checks if the Salvo skill is active
 *
 * @return true if we have the skill enabled
 */
private function bool IsSalvoActive()
{
	return PerkSkills[ESupportSalvo].bActive && IsPerkLevelAllowed(ESupportSalvo);
}

/**
 * @brief Checks if the Armor Piercing Shot skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private function bool IsAPShotActive()
{
	return PerkSkills[ESupportAPShot].bActive && IsPerkLevelAllowed(ESupportAPShot);
}

/**
 * @brief Checks if the Tight Choke skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private function bool IsTightChokeActive()
{
	return PerkSkills[ESupportTightChoke].bActive && IsPerkLevelAllowed(ESupportTightChoke);
}

/**
 * @brief Checks if the tactical reload skill is active (client and server)
 *
 * @return true/false
 */
simulated private function bool IsTacticalReloadActive()
{
	return PerkSkills[ESupportTacticalReload].bActive && IsPerkLevelAllowed(ESupportTacticalReload);
}

/**
 * @brief Checks if the Concussion Rounds skill is active
 *
 * @return true/false
 */
private function bool IsConcussionRoundsActive()
{
	return PerkSkills[ESupportConcussionRounds].bActive && IsPerkLevelAllowed(ESupportConcussionRounds);
}

/**
 * @brief Checks if the Resupply skill is active
 *
 * @return true/false
 */
simulated private function bool IsResupplyActive()
{
	return PerkSkills[ESupportResupply].bActive && IsPerkLevelAllowed(ESupportResupply);
}

/**
 * @brief Checks if the Perforate skill is active
 *
 * @return true/false
 */
simulated private function bool IsPerforateActive()
{
	return PerkSkills[ESupportPerforate].bActive && WorldInfo.TimeDilation < 1.f && IsPerkLevelAllowed(ESupportPerforate);
}

/**
 * @brief Checks if we can repair doors
 *
 * @return true/false
 */
function bool CanRepairDoors()
{
	return true;
}

/**
 */
static function GetDoorRepairXP(out int XP, byte Difficulty)
{
    XP = default.DoorRepairXP[Difficulty];
}

/*********************************************************************************************
* @name	 Logging / debug
********************************************************************************************* */

/** Log What type of reload the weapon would use given ammo count */
private simulated function name LogTacticalReload()
{
	local KFWeapon KFW;

	KFW = GetOwnerWeapon();
	if( KFW != none )
	{
    	return KFW.GetReloadAnimName( GetUsingTactialReload(KFW) );
    }

    return '';
}
/** QA Logging - Report Perk Info */
simulated function LogPerkSkills()
{
	super.LogPerkSkills();

	if( bLogPerk )
	{
/**		`log( "PASSIVE PERKS" );
		`log( "-Welding Modifier:" @ (GetPassiveValue(WeldingProficiency, CurrentLevel, WeldingProficiency.Rank) - 1) *100 $"%" );
		`log( "-Shotgun Damage Modifier:" @ (GetPassiveValue(ShotgunDamage, CurrentLevel, ShotgunDamage.Rank) - 1) *100 $"%" );
		`log( "-Shotgun Penetration Modifier:" @ GetPassiveValue(default.ShotgunPenetration, CurrentLevel, default.ShotgunPenetration.Rank) );
		`log( "-Grenade Damage Modifier:" @ GetPassiveValue(GrenadeDamage, CurrentLevel, 100.f)*100 $"%" );

	    `log( "Skill Tree" );
	    `log( "-Ammo:" @ PerkSkills[ESupportTacticalReload].bActive );
		`log( "-Supplier:" @ IsSupplierActive()) ;
		`log( "-Fortitude:" @ PerkSkills[ESupportFortitude].bActive );
		`log( "-Regeneration:" @ PerkSkills[ESupportRegeneration].bActive );
		`log( "-Bombard:" @ PerkSkills[ESupportBombard].bActive );
		`log( "-Tactical Reload:" @ PerkSkills[ESupportTacticalReload].bActive @ LogTacticalReload() );
		`log( "-Strength:" @ PerkSkills[ESupportStrength].bActive );
		`log( "-Tenacity:" @ PerkSkills[ESupportTenacity].bActive );
		`log( "-Safeguard:" @ PerkSkills[ESupportSafeguard].bActive );
		`log( "-Barrage:" @ PerkSkills[ESupportBarrage].bActive );*/
	}
}

simulated function PlayerDied()
{
	super.PlayerDied();

	if(InteractionTrigger != none)
	{
		InteractionTrigger.DestroyTrigger();
	}
}

/*********************************************************************************************
* @name	 Classic Perk
******************************************************************************************** */

simulated static function class<KFWeaponDefinition> GetWeaponDef(int Level)
{
    return Super(ClassicPerk_Base).GetWeaponDef(Level);
}

simulated function float GetCostScaling(byte Level, optional STraderItem TraderItem, optional KFWeapon Weapon)
{
    return 1.f;
}

simulated function GetPerkIcons(ObjectReferencer RepInfo)
{
    local int i;

    for (i = 0; i < OnHUDIcons.Length; i++)
    {
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[67]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
	ProgressStatID=STATID_Sup_Progress
	PerkBuildStatID=STATID_Sup_Build

	InteractIcon=Texture2D'UI_World_TEX.Support_Supplier_HUD'

	PrimaryWeaponDef=class'KFWeapDef_MB500'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
	KnifeWeaponDef=class'KFWeapDef_Knife_Support'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Support'

	BarrageFiringRate=0.9f
	ResupplyMaxSpareAmmoModifier=0.20 //0.15

	ReceivedAmmoSound=AkEvent'WW_UI_PlayerCharacter.Play_UI_Pickup_Ammo'
	ReceivedAmmoAndArmorSound=AkEvent'WW_UI_PlayerCharacter.Play_UI_Pickup_Armor'
	ReceivedArmorSound=AkEvent'WW_UI_PlayerCharacter.Play_UI_Pickup_Armor'

	//Ammo=(Name="Ammo",Increment=0.01f,Rank=1,StartingValue=0.0,MaxValue=0.25f) //0.4
	//WeldingProficiency=(Name="Welding Proficiency",Increment=0.03f,Rank=1,StartingValue=1.f,MaxValue=1.75f) //1.5
	//ShotgunDamage=(Name="Shotgun Damage",Increment=0.01f,Rank=1,StartingValue=0.f,MaxValue=0.25f)
	//ShotgunPenetration=(Name="Shotgun Penetration",Increment=0.20,Rank=1,StartingValue=0.0f,MaxValue=5.0f) //6.25
	//Strength=(Name="Strength",Increment=1.f,Rank=5,StartingValue=0.f,MaxValue=5.f)

	PerkSkills(ESupportHighCapMags)=(Name="HighCapMags",IconPath="UI_PerkTalent_TEX.support.UI_Talents_Support_HighCapacityMags",Increment=0.f,Rank=0,StartingValue=0.5,MaxValue=0.5) //0.25
	PerkSkills(ESupportTacticalReload)=(Name="TacticalReload",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_TacticalReload",Increment=0.f,Rank=0,StartingValue=0.8f,MaxValue=0.f)
	PerkSkills(ESupportFortitude)=(Name="Fortitude",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_Fortitude",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(ESupportSalvo)=(Name="Salvo",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_Salvo",Increment=0.f,Rank=0,StartingValue=0.3f,MaxValue=0.3f)
	PerkSkills(ESupportAPShot)=(Name="APShot",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_ArmorPiercing",Increment=0.f,Rank=0,StartingValue=4.f,MaxValue=4.f) //3
	PerkSkills(ESupportTightChoke)=(Name="TightChoke",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_TightChoke",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f) //0.7
	PerkSkills(ESupportResupply)=(Name="Resupply",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_ResupplyPack",Increment=0.f ,Rank=0,StartingValue=0.2f,MaxValue=0.2f)
	PerkSkills(ESupportConcussionRounds)=(Name="ConcussionRounds",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_ConcussionRounds",Increment=0.f,Rank=0,StartingValue=1.5f,MaxValue=1.5f)
	PerkSkills(ESupportPerforate)=(Name="Perforate",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_Penetrator",Increment=0.f,Rank=0,StartingValue=40.f,MaxValue=40.f)
	PerkSkills(ESupportBarrage)=(Name="Barrage",IconPath="UI_PerkTalent_TEX.Support.UI_Talents_Support_Barrage",Increment=0.f,Rank=0,StartingValue=5.f,MaxValue=5.f)

	SecondaryXPModifier[0]=8
	SecondaryXPModifier[1]=8
	SecondaryXPModifier[2]=8
	SecondaryXPModifier[3]=8

    DoorRepairXP[0]=18
    DoorRepairXP[1]=24
    DoorRepairXP[2]=30
    DoorRepairXP[3]=42

    // Skill tracking
	HitAccuracyHandicap=-6.0
	HeadshotAccuracyHandicap=-3.0
	AutoBuyLoadOutPath=(class'KFWeapDef_MB500', class'KFWeapDef_DoubleBarrel', class'KFWeapDef_M4', class'KFWeapDef_AA12')

	// Prestige Rewards
	PrestigeRewardItemIconPaths[0]="WEP_SkinSet_Prestige01_Item_TEX.knives.SupportKnife_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[1]="WEP_SkinSet_Prestige02_Item_TEX.tier01.MB500_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[2]="WEP_skinset_prestige03_itemtex.tier02.Boomstick_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[3]="wep_skinset_prestige04_itemtex.tier03.M4_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[4]="WEP_SkinSet_Prestige05_Item_TEX.tier04.AA12_PrestigePrecious_Mint_large"

	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"
   	ZedTimeModifyingStates(3)="WeaponAltFiring"

	HighCapMagExemptList(0)="KFWeap_Shotgun_DoubleBarrel"
	HighCapMagExemptList(1)="KFWeap_HRG_Revolver_Buckshot"
	HighCapMagExemptList(2)="KFWeap_HRG_Revolver_DualBuckshot"

   	AdditionalOnPerkDTNames(0)="KFDT_Ballistic_Shotgun_Medic"
   	AdditionalOnPerkDTNames(1)="KFDT_Ballistic_DragonsBreath"
   	AdditionalOnPerkDTNames(2)="KFDT_Ballistic_NailShotgun"

    // Classic Perk
    BasePerk=class'KFPerk_Support'
    EXPActions(0)="Dealing Support weapon damage"
    EXPActions(1)="Welding doors"
    PassiveInfos(0)=(Title="Welding Proficiency")
    PassiveInfos(1)=(Title="Shotgun Damage")
    PassiveInfos(2)=(Title="Shotgun Penetration")
    PassiveInfos(3)=(Title="Ammo")
    PassiveInfos(4)=(Title="Increased Weight Capacity")
}
