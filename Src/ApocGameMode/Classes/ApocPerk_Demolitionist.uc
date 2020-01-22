class ApocPerk_Demolitionist extends ClassicPerk_Base;

var 			const	PerkSkill					ExplosiveResistance;        // 10% explosive resistance, additional 2% resistance per level (max 60%)
var 			const	PerkSkill					ExplosiveAmmo;            	// 1 extra explosive ammo for every 5 levels. Weapons only

var						Array<KFPawn_Human>			SuppliedPawnList;

var 	private const   float 						SharedExplosiveResistance;
var 	private const 	class<Damagetype>			ExplosiveResistableDamageTypeSuperClass;
/** the radius in within the shared explosive resistance works */
var 	private const 	float 						ExplosiveResistanceRadius;

/** Template for explosion when you die with the Sacrifice perk skill*/
var 					KFGameExplosion				SacrificeExplosionTemplate;
/** Template for explosion when do an explosion with the Nuke perk skill*/
var 					KFGameExplosion				NukeExplosionTemplate;
/** Template for explosion when a door is opened by zeds that has been welded when you have the Door Trap perk skill*/
var 					KFGameExplosion				DoorTrapExplosionTemplate;
var 					class<KFExplosionActor>		NukeExplosionActorClass;
/** How much to modify a projectile's damage when the nuke skill is active */
var 	private const 	float 						NukeDamageModifier;
/** How much to modify a projectile's damage radius when the nuke skill is active */
var 	private const 	float 						NukeRadiusModifier;
var 					AkEvent 					ConcussiveExplosionSound;
var 	private	const	float 						AoeDamageModifier;
var 	private	const	int 						LingeringNukePoisonDamage;
var 	private const	array<name>					PassiveExtraAmmoIgnoredClassNames;
var 	private const	array<name>					ExtraAmmoIgnoredClassNames;
var		private const   array<name>					TacticalReloadAsReloadRateClassNames;
var 	private const 	array<name>					OnlySecondaryAmmoWeapons;
var 	private const 	array<name>					DamageIgnoredDTs;
var 	private	const	float 						DaZedEMPPower;
var 	private const   float 						ProfessionalAoEModifier;
var 	private			bool 						bUsedSacrifice;
var 	private const 	class<KFDamagetype>			LingeringNukeDamageType;

/** The last time an HX25 projectile spawned by our owner caused a nuke */
var 	private transient float LastHX25NukeTime;

enum EDemoSkills
{
	EDemoDamage,
	EDemoTacticalReload,
	EDemoDirectHit,
	EDemoAmmo,
	EDemoSirenResistance,
	EDemoAoE,
	EDemoCriticalHit,
	EDemoConcussiveForce,
	EDemoNuke,
	EDemoProfessional
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

	if( MyPRI != none )
	{
		MyPRI.bNukeActive = IsNukeActive();
		MyPRI.bConcussiveActive = IsConcussiveForceActive();
	}
	if (KFGRI == none && KFGRI.bTraderIsOpen)
	{
		return;
	}
	//ResetSupplier();
}

/**
 * @brief Resets certain perk values on wave start/end
 */
function OnWaveEnded()
{
	Super.OnWaveEnded();
	bUsedSacrifice = false;
}

/**
* @brief Resets certain perk values on wave start/end
*/
function OnWaveStart()
{
	Super.OnWaveStart();
	ResetSupplier();
}

/*********************************************************************************************
* @name	 Passives
********************************************************************************************* */
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

	if( DamageType != none && IsDamageIgnoredDT( DamageType ) )
	{
		return;
	}

	TempDamage = InDamage;
	`QAlog( "ModifyDamage() Start Damage:" @ InDamage, bLogPerk );

	if( DamageCauser != none )
	{
		KFW = GetWeaponFromDamageCauser( DamageCauser );
	}

	if( (KFW != none && IsWeaponOnPerk( KFW,, self.class )) || (DamageType != none && IsDamageTypeOnPerk( DamageType )) )
	{
		`QALog( "Base Damage Given" @ DamageType @ KFW @ InDamage, bLogPerk );
		//Passive
		TempDamage +=  InDamage * GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank );
		`QALog( "WeaponDamage Given" @ DamageType @ KFW @ InDamage * GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank ), bLogPerk );
		//Damage skill
		if( IsDamageActive() )
		{
			TempDamage +=  InDamage * GetSkillValue( PerkSkills[EDemoDamage] );
			`QALog( "Bombadier Given" @ DamageType @ KFW @ InDamage * GetSkillValue( PerkSkills[EDemoDamage] ), bLogPerk );
		}

		if( IsDirectHitActive() && DamageType != none && IsDamageTypeOnPerk( DamageType ) )
		{
			if( class<KFDT_Ballistic_Shell>(DamageType) != none )
			{
				TempDamage += InDamage * GetSkillValue( PerkSkills[EDemoDirectHit] );
				`QALog( "High Impact Damage Given" @ DamageType @ KFW @ InDamage * GetSkillValue( PerkSkills[EDemoDirectHit] ), bLogPerk );
			}
		}

		if( IsCriticalHitActive() && MyKFPM != none &&
			IsCriticalHitZone( MyKFPM, HitZoneIdx ) )
		{
			TempDamage += InDamage * GetSkillValue( PerkSkills[EDemoCriticalHit] );
			`QALog( "Armor Piercing Rounds Damage Given" @ DamageType @ KFW @ InDamage * GetSkillValue( PerkSkills[EDemoCriticalHit] ), bLogPerk );
		}

		if( IsAoEActive() )
		{
			TempDamage -= InDamage * GetAoEDamageModifier();
		}
	}

	`QALog( "Total Damage Given" @ DamageType @ KFW @ GetPercentage( InDamage, Round( TempDamage ) ), bLogPerk );
	InDamage = Round( TempDamage );
	`QAlog( "ModifyDamage() Total Damage:" @ InDamage, bLogPerk );
}

static protected function bool IsDamageIgnoredDT( class<KFDamageType> KFDT )
{
	return default.DamageIgnoredDTs.Find( KFDT.name ) != INDEX_NONE;
}

protected function bool IsCriticalHitZone( KFPawn TestPawn, int HitZoneIndex )
{
	if( TestPawn != none && HitzoneIndex >= 0 && HitzoneIndex < TestPawn.HitZones.length )
	{
		return TestPawn.HitZones[HitZoneIndex].DmgScale > 1.f;
	}

	return false;
}

/**
 * @brief DamageType on perk?
 *
 * @param KFDT The damage type
 * @return true/false
 */
static function bool IsDamageTypeOnPerk( class<KFDamageType> KFDT )
{
	if( KFDT != none && IsDamageIgnoredDT( KFDT ) )
	{
		return false;
	}

	return super.IsDamageTypeOnPerk( KFDT );
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

	if( InDamage <= 0 )
	{
		return;
	}

	TempDamage = InDamage;

	if( ClassIsChildOf( DamageType, class'KFDT_Explosive' ) )
	{
		TempDamage *= 1 - GetPassiveValue( ExplosiveResistance, CurrentLevel, ExplosiveResistance.Rank );

        if (InstigatedBy == OwnerPC && (IsNukeActive() || IsProfessionalActive()) && ShouldNeverDud())
        {
            TempDamage = 0;
        }
	}

	`QALog( "Total Damage Resistance" @ DamageType @ GetPercentage(InDamage, Round(TempDamage)), bLogPerk );
	InDamage = Round( TempDamage );
}

/**
 * @brief Modifies starting spare ammo
 *
 * @param KFW The weapon
 * @param PrimarySpareAmmo ammo amount
 * @param TraderItem the weapon's associated trader item info
 */
simulated function ModifySpareAmmoAmount( KFWeapon KFW, out int PrimarySpareAmmo, optional const out STraderItem TraderItem, optional bool bSecondary=false )
{
	local array< class<KFPerk> > WeaponPerkClass;
	local bool bUsesAmmo;
	local name WeaponClassName;

	if( KFW == none )
	{
		WeaponPerkClass = TraderItem.AssociatedPerkClasses;
		bUsesAmmo = TraderItem.WeaponDef.static.UsesAmmo();
		WeaponClassName = TraderItem.ClassName;
	}
	else
	{
		WeaponPerkClass = KFW.GetAssociatedPerkClasses();
		bUsesAmmo = KFW.UsesAmmo();
		WeaponClassName = KFW.class.Name;
	}

	if( bUsesAmmo )
	{
		GivePassiveExtraAmmo( PrimarySpareAmmo, KFW, WeaponPerkClass, WeaponClassName, bSecondary );
		GiveAmmoExtraAmmo( PrimarySpareAmmo, KFW, WeaponPerkClass, WeaponClassName, bSecondary );
	}
}

simulated private function GivePassiveExtraAmmo( out int PrimarySpareAmmo, KFWeapon KFW, array< class<KFPerk> > WeaponPerkClass, name WeaponClassName, optional bool bSecondary=false )
{
	if( ShouldGiveOnlySecondaryAmmo( WeaponClassName ) && !bSecondary )
	{
		return;
	}

	if( IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) &&
		PassiveExtraAmmoIgnoredClassNames.Find( WeaponClassName ) == INDEX_NONE )
	{
		PrimarySpareAmmo += GetExtraAmmo( CurrentLevel );
	}
}

simulated private function GiveAmmoExtraAmmo( out int PrimarySpareAmmo, KFWeapon KFW, array< class<KFPerk> > WeaponPerkClass, name WeaponClassName, optional bool bSecondary=false  )
{
	if( ShouldGiveOnlySecondaryAmmo( WeaponClassName ) && !bSecondary )
	{
		return;
	}

	if( IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) &&
		ExtraAmmoIgnoredClassNames.Find( WeaponClassName ) == INDEX_NONE )
	{
		PrimarySpareAmmo += GetAmmoExtraAmmo();
	}
}

simulated function bool ShouldGiveOnlySecondaryAmmo( name WeaponClassName )
{
	return OnlySecondaryAmmoWeapons.Find( WeaponClassName ) != INDEX_NONE;
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
	local array< class<KFPerk> > WeaponPerkClass;
	local bool bUsesAmmo;
	local name WeaponClassName;

	if( KFW == none )
	{
		WeaponPerkClass = TraderItem.AssociatedPerkClasses;
		bUsesAmmo = TraderItem.WeaponDef.static.UsesAmmo();
		WeaponClassName = TraderItem.ClassName;
	}
	else
	{
		WeaponPerkClass = KFW.GetAssociatedPerkClasses();
		bUsesAmmo = KFW.UsesAmmo();
		WeaponClassName = KFW.class.Name;
	}

	if( bUsesAmmo )
	{
		GivePassiveExtraAmmo( MaxSpareAmmo, KFW, WeaponPerkClass, WeaponClassName, bSecondary );
		GiveAmmoExtraAmmo( MaxSpareAmmo, KFW, WeaponPerkClass, WeaponClassName, bSecondary );
	}
}

/**
 * @brief Calculates the additional ammo per perk level
 *
 * @param Level Current perk level
 * @return additional ammo
 */
simulated private final static function int GetExtraAmmo( int Level )
{
	return default.ExplosiveAmmo.Increment * FFloor( float( Level ) / default.ExplosiveAmmo.Rank );
}

/*********************************************************************************************
* @name	 Selectable skills
********************************************************************************************* */

static function PrepareExplosive( Pawn ProjOwner, KFProjectile Proj, optional float AuxRadiusMod = 1.0f, optional float AuxDmgMod = 1.0f )
{
    local KFPlayerReplicationInfo InstigatorPRI;
    local KFPlayerController KFPC;
    local KFPerk InstigatorPerk;

    if( ProjOwner != none )
    {
	    if( Proj.bWasTimeDilated )
	    {
	        InstigatorPRI = KFPlayerReplicationInfo( ProjOwner.PlayerReplicationInfo );
	        if( InstigatorPRI != none )
	        {
	            if( InstigatorPRI.bNukeActive && class'KFPerk_Demolitionist'.static.ProjectileShouldNuke(Proj) )
	            {
	                Proj.ExplosionTemplate = class'KFPerk_Demolitionist'.static.GetNukeExplosionTemplate();
	                Proj.ExplosionTemplate.Damage = Proj.default.ExplosionTemplate.Damage * class'KFPerk_Demolitionist'.static.GetNukeDamageModifier() * AuxDmgMod;
	                Proj.ExplosionTemplate.DamageRadius = Proj.default.ExplosionTemplate.DamageRadius * class'KFPerk_Demolitionist'.static.GetNukeRadiusModifier() * AuxRadiusMod;
	                Proj.ExplosionTemplate.DamageFalloffExponent = Proj.default.ExplosionTemplate.DamageFalloffExponent;
	            }
	            else if( InstigatorPRI.bConcussiveActive && Proj.AltExploEffects != none )
	            {
	                Proj.ExplosionTemplate.ExplosionEffects = Proj.AltExploEffects;
	                Proj.ExplosionTemplate.ExplosionSound = class'KFPerk_Demolitionist'.static.GetConcussiveExplosionSound();
	            }
	        }
	    }

	    // Change the radius and damage based on the perk
	    if( ProjOwner.Role == ROLE_Authority )
	    {
	    	KFPC = KFPlayerController( ProjOwner.Controller );
	    	if( KFPC != none )
	    	{
		        InstigatorPerk = KFPC.GetPerk();
		        Proj.ExplosionTemplate.DamageRadius *= InstigatorPerk.GetAoERadiusModifier() * AuxRadiusMod;
		    }
	    }
	}
}

simulated function SetLastHX25NukeTime( float NewTime )
{
	LastHX25NukeTime = NewTime;
}
simulated function float GetLastHX25NukeTime()
{
	return LastHX25NukeTime;
}

simulated function float GetAoERadiusModifier()
{
	local float RadiusModifier;

	RadiusModifier = IsAoEActive() ? GetSkillValue( PerkSkills[EDemoAoE] ) : 1.f;
	RadiusModifier = (IsProfessionalActive() && WorldInfo.TimeDilation < 1.f) ?
		(RadiusModifier + default.ProfessionalAoEModifier) :
		RadiusModifier;

	return RadiusModifier;
}

simulated function float GetAoEDamageModifier()
{
	return default.AoeDamageModifier;
}

simulated protected function int GetAmmoExtraAmmo()
{
	return IsAmmoActive() ? GetSkillValue( PerkSkills[EDemoAmmo] ) : 0.f;
}

/**
 * @brief Should the tactical reload skill adjust the reload speed
 *
 * @param KFW weapon in use
 * @return true/false
 */
simulated function bool GetUsingTactialReload(KFWeapon KFW)
{
	return (IsTacticalReloadActive() && (IsWeaponOnPerk(KFW, , self.class) || IsBackupWeapon(KFW)) && TacticalReloadAsReloadRateClassNames.Find(KFW.class.Name) == INDEX_NONE);
}

/**
*  @brief Modifies the reload speed for Demolitionist weapons
*/
simulated function float GetReloadRateScale(KFWeapon KFW)
{
	if (IsWeaponOnPerk(KFW, , self.class) && IsTacticalReloadActive() && TacticalReloadAsReloadRateClassNames.Find(KFW.class.Name) != INDEX_NONE)
	{
		return 0.8f;
	}

	return 1.f;
}

/**
 * @brief Sets up the supllier skill
 */
simulated final private function ResetSupplier()
{
	if( MyPRI != none )
	{
		if( SuppliedPawnList.Length > 0 )
		{
			SuppliedPawnList.Remove( 0, SuppliedPawnList.Length );
		}

		MyPRI.PerkSupplyLevel = 1;

		if( InteractionTrigger != none )
		{
			InteractionTrigger.Destroy();
			InteractionTrigger = none;
		}

		if( CheckOwnerPawn() )
		{
			InteractionTrigger = Spawn( class'KFUsablePerkTrigger', OwnerPawn,, OwnerPawn.Location, OwnerPawn.Rotation,, true );
			InteractionTrigger.SetBase( OwnerPawn );
			InteractionTrigger.SetInteractionIndex( IMT_ReceiveGrenades );
			OwnerPC.SetPendingInteractionMessage();
		}
	}
	else if( InteractionTrigger != none )
	{
		InteractionTrigger.Destroy();
	}
}

/**
 * @brief General interaction with another pawn, here: give grenades
 *
 * @param KFPH Pawn to interact with
 */
simulated function Interact( KFPawn_Human KFPH )
{
	local KFInventoryManager KFIM;
	local KFPlayerController KFPC;
	local KFPlayerReplicationInfo OwnerPRI, UserPRI;
	local bool bReceivedGrenades;

	if( SuppliedPawnList.Find( KFPH ) != INDEX_NONE )
	{
		return;
	}

	KFIM = KFInventoryManager(KFPH.InvManager);
	if( KFIM != None )
	{
		bReceivedGrenades = KFIM.AddGrenades( 1 );
	}

	if( bReceivedGrenades )
	{
		SuppliedPawnList.AddItem( KFPH );

		if( Role == ROLE_Authority )
		{
			KFPC = KFPlayerController(KFPH.Controller);
			if( KFPC != none )
			{
				OwnerPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_GaveGrenadesTo, KFPC.PlayerReplicationInfo );
				KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_ReceivedGrenadesFrom, OwnerPC.PlayerReplicationInfo );

				UserPRI = KFPlayerReplicationInfo(KFPC.PlayerReplicationInfo);
				OwnerPRI = KFPlayerReplicationInfo(OwnerPC.PlayerReplicationInfo);
				if( UserPRI != none && OwnerPRI != none )
				{
					UserPRI.MarkSupplierOwnerUsed( OwnerPRI );
				}

				`QALog( "Grenade Supplier" @ KFPC.PlayerReplicationInfo.PlayerName, bLogPerk );
			}
		}
	}
	else
	{
		if( Role == ROLE_Authority )
		{
			KFPC = KFPlayerController(KFPH.Controller);
			if( KFPC != none )
			{
				KFPC.ReceiveLocalizedMessage( class'KFLocalMessage_Game', GMT_AmmoIsFull, OwnerPC.PlayerReplicationInfo );
			}
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
	return SuppliedPawnList.Find( MyKFPH ) == INDEX_NONE;
}

/**
 * @brief Checks if we should blow up close to death
 *
 * @return kaboom or not.
 */
simulated function bool ShouldSacrifice()
{
	return IsSacrificeActive() && !bUsedSacrifice;
}

function NotifyPerkSacrificeExploded()
{
	bUsedSacrifice = true;
}

/**
 * @brief Modifies the damage if the shared explosive resistance skill is selected
 *
 * @param InDamage the damage to modify
 */
simulated static function ModifyWeaponDamage( out float InDamage )
{
	InDamage -= Indamage * GetSharedExplosiveResistance();
}

simulated function bool CanExplosiveWeld()
{
	return IsDoorTrapsActive();
}

/**
 * @brief Checks if the projectile should be immune to the pesky siren effects
 *
 * @return Immune or not
 */
simulated function bool ShouldRandSirenResist()
{
	return IsSirenResistanceActive();
}

/**
 * @brief skills and weapons can modify the knockdown power chance
 * @return knockdown power multiplier
 */
function float GetKnockdownPowerModifier( optional class<DamageType> DamageType, optional byte BodyPart, optional bool bIsSprinting=false )
{
	local float KnockDownMultiplier;

	KnockDownMultiplier = 0.f;

	if( IsDamageTypeOnPerk( class<KFDamageType>(DamageType) ) )
	{
		if( IsConcussiveForceActive() )
		{
			KnockDownMultiplier += GetSkillValue( PerkSkills[EDemoConcussiveForce] );
		}

		if( IsTacticalReloadActive() )
		{
			KnockDownMultiplier += GetSkillValue( PerkSkills[EDemoTacticalReload] );
		}
	}

	`QALog( "KnockDownMultiplier" @ KnockDownMultiplier, bLogPerk );
	return KnockDownMultiplier;
}

/**
 * @brief skills and weapons can modify the stumbling power chance
 * @return stumbling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	local float StumbleMultiplier;

	StumbleMultiplier = 0.f;

	if( IsConcussiveForceActive() && IsDamageTypeOnPerk( DamageType ) )
	{
		StumbleMultiplier += GetSkillValue( PerkSkills[EDemoConcussiveForce] );
	}

	`QALog( "StumbleMultiplier" @ StumbleMultiplier, bLogPerk );
	return StumbleMultiplier;
}

/**
 * @brief skills and weapons can modify the stun power chance
 *
 * @return stun power modifier
 */
function float GetStunPowerModifier( optional class<DamageType> DamageType, optional byte HitZoneIdx )
{
	local float StunMultiplier;

	StunMultiplier = 0.f;

	if( IsConcussiveForceActive() && IsDamageTypeOnPerk( class<KFDamageType>(DamageType) ) )
	{
		StunMultiplier += GetSkillValue( PerkSkills[EDemoConcussiveForce] );
	}

	`QALog( "StunMultiplier" @ StunMultiplier, bLogPerk );
	return StunMultiplier;
}

function float GetReactionModifier( optional class<KFDamageType> DamageType )
{
	local float ReactionMultiplier;

	ReactionMultiplier = 1.f;

	if( IsConcussiveForceActive() && IsDamageTypeOnPerk( DamageType ) )
	{
		ReactionMultiplier += GetSkillValue( PerkSkills[EDemoConcussiveForce] );
	}

	`QALog( "ReactionMultiplier" @ ReactionMultiplier, bLogPerk );
	return ReactionMultiplier;
}

simulated static function bool ProjectileShouldNuke( KFProjectile Proj )
{
	return Proj.AllowNuke();
}

simulated function bool DoorShouldNuke()
{
	return IsNukeActive() && WorldInfo.TimeDilation < 1.f;
}

simulated function bool ShouldNeverDud()
{
	return (IsNukeActive() || IsProfessionalActive()) && WorldInfo.TimeDilation < 1.f;
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
	if( IsProfessionalActive() && IsWeaponOnPerk( W,, self.class ) )
	{
		if( ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE || W.HasAlwaysOnZedTimeResist() )
		{
			`QALog( "Professional Modifier" @ StateName @ GetSkillValue( PerkSkills[EDemoProfessional] ), bLogPerk );
			return GetSkillValue( PerkSkills[EDemoProfessional] );
		}
	}

	return 0.f;
}

/*********************************************************************************************
* @name	 Getters etc
********************************************************************************************* */

/**
 * @brief Checks if the Damage skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsDamageActive()
{
	return PerkSkills[EDemoDamage].bActive && IsPerkLevelAllowed(EDemoDamage);
}

/**
 * @brief Checks if the Damage skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsTacticalReloadActive()
{
	return PerkSkills[EDemoTacticalReload].bActive && IsPerkLevelAllowed(EDemoTacticalReload);
}

/**
 * @brief Checks if the Direct hit skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsDirectHitActive()
{
	return PerkSkills[EDemoDirectHit].bActive && IsPerkLevelAllowed(EDemoDirectHit);
}

/**
 * @brief Checks if the Ammo skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsAmmoActive()
{
	return PerkSkills[EDemoAmmo].bActive && IsPerkLevelAllowed(EDemoAmmo);
}

/**
 * @brief Checks if the Area of Effect skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsAoEActive()
{
	return PerkSkills[EDemoAoE].bActive && IsPerkLevelAllowed(EDemoAoE);
}

/**
 * @brief Checks if the Critical hit skill is active
 *
 * @return true if we have the skill enabled
 */
simulated function bool IsCriticalHitActive()
{
	return PerkSkills[EDemoCriticalHit].bActive && IsPerkLevelAllowed(EDemoCriticalHit);
}

/**
 * @brief Checks if the Heat wave skill is active and if we are in Zed time
 *
 * @return true/false
 */
simulated final private function bool IsProfessionalActive()
{
	return PerkSkills[EDemoProfessional].bActive && IsPerkLevelAllowed(EDemoProfessional);
}

/**
 * @brief Returns the shared explosive resistance
 * @return Percent in float (.3f default)
 */
simulated static private final function float GetSharedExplosiveResistance()
{
	return default.SharedExplosiveResistance;
}

/**
 * @brief Gets the radius in within the shared explosive restince works
 * @return radius in UU float
 */
simulated static function float GetExplosiveResistanceRadius()
{
	return default.ExplosiveResistanceRadius;
}

/**
 * @brief Shared explosive resistance obviously opnly works with explosives
 *
 * @param DmgType Damage type to test
 *
 * @return true if resistable
 */
static function bool IsDmgTypeExplosiveResistable( class<DamageType> DmgType )
{
	return ClassIsChildOf( DmgType, default.ExplosiveResistableDamageTypeSuperClass );
}

/**
 * @brief The Sacrifice skill can spawn an explosion, this function delivers the template
 *
 * @return A game explosion template
 */
static function GameExplosion GetSacrificeExplosionTemplate()
{
	return default.SacrificeExplosionTemplate;
}

 /**
 * @brief Checks if the Door Traps skill is active
 *
 * @return true if we have the skill enabled
 */
 simulated private final function bool IsDoorTrapsActive()
 {
 	return true;
 }

 /**
 * @brief Checks if the Sacrifice skill is active
 *
 * @return true if we have the skill enabled
 */
 simulated private final function bool IsSacrificeActive()
 {
 	return true;
 }

/**
 * @brief The Door Traps skill can spawn an explosion, this function delivers the template
 *
 * @return A game explosion template
 */
static function GameExplosion GetDoorTrapsExplosionTemplate()
{
	return default.DoorTrapExplosionTemplate;
}

/**
 * @brief Checks if the Siren Resistance skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private final function bool IsSirenResistanceActive()
{
	return PerkSkills[EDemoSirenResistance].bActive && IsPerkLevelAllowed(EDemoSirenResistance);
}

/**
 * @brief Checks if the Nuke skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private final function bool IsNukeActive()
{
	return PerkSkills[EDemoNuke].bActive && IsPerkLevelAllowed(EDemoNuke);
}

/**
 * @brief The nuke skill spawns a radioactive cloud, this function delivers the template
 *
 * @return Nuke explosion template
 */
static simulated function KFGameExplosion GetNukeExplosionTemplate()
{
	return default.NukeExplosionTemplate;
}

static simulated function class<KFExplosionActor> GetNukeExplosionActorClass()
{
	return default.NukeExplosionActorClass;
}

/**
 * @brief Modifies a projectile's damage when the nuke skill is active
 * @return damage modifier
 */
static function float GetNukeDamageModifier()
{
	return default.NukeDamageModifier;
}

/**
 * @brief Modifies a projectile's damage radius when the nuke skill is avtive
 * @return damage radius modifier
 */
static function float GetNukeRadiusModifier()
{
	return default.NukeRadiusModifier;
}

static function int GetLingeringPoisonDamage()
{
	return default.LingeringNukePoisonDamage;
}

static function class<KFDamageType> GetLingeringDamageType()
{
	return default.LingeringNukeDamageType;
}

/**
 * @brief Checks if the Concussive Force skill is active
 *
 * @return true if we have the skill enabled
 */
simulated private final function bool IsConcussiveForceActive()
{
	return PerkSkills[EDemoConcussiveForce].bActive && IsPerkLevelAllowed(EDemoConcussiveForce);
}

simulated final static function AkEvent GetConcussiveExplosionSound()
{
	return default.ConcussiveExplosionSound;
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
simulated static function int GetFleshpoundKillXP( byte Difficulty )
{
	return default.SecondaryXPModifier[Difficulty];
}

/*********************************************************************************************
* @name	 UI
********************************************************************************************* */
simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( GetPassiveValue( default.WeaponDamage, Level, default.WeaponDamage.Rank ) * 100 ) @ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.ExplosiveResistance, Level, default.ExplosiveResistance.Rank ) * 100 ) @ "%";
	PassiveValues[2] = string(GetExtraAmmo( Level ));
	PassiveValues[3] = "";
	PassiveValues[4] = "";
	PassiveValues[5] = "";

	Increments[0] = "[" @ Round(default.WeaponDamage.Increment * 100)  @ "% / +" $ default.WeaponDamage.Rank @ default.LevelString @ "]";
	Increments[1] = "[" @ Round(default.ExplosiveResistance.StartingValue * 100)  @ "% +" $ int(default.ExplosiveResistance.Increment * 100) @ "%" @ "/ +" $ default.ExplosiveResistance.Rank @ default.LevelString @ "]";
	Increments[2] = "[" @ Round(default.ExplosiveAmmo.Increment) @ "/ +" $ default.ExplosiveAmmo.Rank @ default.LevelString @ "]";
	Increments[3] = "";
	Increments[4] = "";
	Increments[5] = "";
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
		`log( "-WeaponDamage:" @ GetPassiveValue( WeaponDamage, CurrentVetLevel, WeaponDamage.Rank ) $ "%" );
		`log( "-ExplosiveResistance:" @ GetPassiveValue( ExplosiveResistance, CurrentVetLevel, ExplosiveResistance.Rank ) $ "%" );
		`log( "-ExplosiveAmmo:" @ GetExtraAmmo( CurrentVetLevel ) $ "%" );

/**	    `log( "Skill Tree" );
	    `log( "-GrenadeSupplier:" @ PerkSkills[EDemoGrenadeSupplier].bActive );
	    `log( "-OnContact:" @ PerkSkills[EDemoOnContact].bActive );
	    `log( "-ExplosiveResistance:" @ PerkSkills[EDemoExplosiveResistance].bActive );
	    `log( "-Sacrifice:" @ PerkSkills[EDemoSacrifice].bActive );
	    `log( "-DoorTraps:" @ PerkSkills[EDemoDoorTraps].bActive );
	    `log( "-SirenResistance:" @ PerkSkills[EDemoSirenResistance].bActive );
	    `log( "-OffPerk:" @ PerkSkills[EDemoOffPerk].bActive );
	    `log( "-OnPerk:" @ PerkSkills[EDemoOnPerk].bActive );
	    `log( "-Nuke:" @ PerkSkills[EDemoNuke].bActive );
	    `log( "-ConcussiveForce:" @ PerkSkills[EDemoConcussiveForce].bActive );*/
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

simulated function GetPerkIcons(ObjectReferencer RepInfo)
{
    local int i;

    for (i = 0; i < OnHUDIcons.Length; i++)
    {
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[63]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
	SharedExplosiveResistance=0.3f

	InteractIcon=Texture2D'UI_World_TEX.Demolitionist_Supplier_HUD'

	PrimaryWeaponDef=class'KFWeapDef_HX25'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
	KnifeWeaponDef=class'KFWeapDef_Knife_Demo'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Demo'

	ProgressStatID=STATID_Demo_Progress
   	PerkBuildStatID=STATID_Demo_Build

   	SecondaryXPModifier(0)=10
	SecondaryXPModifier(1)=17
	SecondaryXPModifier(2)=21
	SecondaryXPModifier(3)=30

	ExplosiveResistableDamageTypeSuperClass=class'KFDT_Explosive'
	ExplosiveResistanceRadius=500.f

	AoeDamageModifier=0 //0.3f
	DaZedEMPPower=0 //100

	ProfessionalAoEModifier=0.25

  	WeaponDamage=(Name="Explosive Damage",Increment=0.01f,Rank=1,StartingValue=0.f,MaxValue=0.25)
	ExplosiveResistance=(Name="Explosive Resistance",Increment=0.02f,Rank=1,StartingValue=0.1f,MaxValue=0.6f)
	ExplosiveAmmo=(Name="Explosive Ammo",Increment=1.f,Rank=5,StartingValue=0.0f,MaxValue=5.f)
    //AOERadius=(Name="AOE Radius",Increment=0.05f,Rank=0,StartingValue=0.f,MaxValue=0.5f)

	PerkSkills(EDemoDamage)=(Name="Damage",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_GrenadeSupplier",Increment=0.f,Rank=0,StartingValue=0.25f,MaxValue=0.25f)
	PerkSkills(EDemoTacticalReload)=(Name="Speed",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_Speed",Increment=0.f,Rank=0,StartingValue=0.10f,MaxValue=0.10f)
	PerkSkills(EDemoDirectHit)=(Name="DirectHit",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_ExplosiveResistance",Increment=0.f,Rank=0,StartingValue=0.25,MaxValue=0.25)
	PerkSkills(EDemoAmmo)=(Name="Ammo",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_Ammo",Increment=0.f,Rank=0,StartingValue=5.f,MaxValue=5.f,)
	PerkSkills(EDemoSirenResistance)=(Name="SirenResistance",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_SirenResistance",Increment=0.f,Rank=0,StartingValue=0.5,MaxValue=0.5)
	PerkSkills(EDemoAoE)=(Name="AreaOfEffect",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_AoE",Increment=0.f,Rank=0,StartingValue=1.50,MaxValue=1.50)
	PerkSkills(EDemoCriticalHit)=(Name="CriticalHit",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_Crit",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(EDemoConcussiveForce)=(Name="ConcussiveForce",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_ConcussiveForce",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(EDemoNuke)=(Name="Nuke",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_Nuke",Increment=0.f,Rank=0,StartingValue=1.03,MaxValue=1.03)
	PerkSkills(EDemoProfessional)=(Name="Professional",IconPath="UI_PerkTalent_TEX.demolition.UI_Talents_Demolition_Professional",Increment=0.f,Rank=0,StartingValue=0.9f,MaxValue=0.9f)

	// explosion
	Begin Object Class=KFGameExplosion Name=ExploTemplate0
		Damage=200
		DamageRadius=500
		DamageFalloffExponent=1.f
		DamageDelay=0.f

		// Damage Effects
		KnockDownStrength=10
		KnockDownRadius=100
		FractureMeshRadius=500.0
		FracturePartVel=500.0
		MyDamageType=class'KFDT_Explosive_Sacrifice'
		ExplosionEffects=KFImpactEffectInfo'WEP_Dynamite_ARCH.Dynamite_Explosion'
		ExplosionSound=AkEvent'WW_WEP_EXP_Grenade_Frag.Play_WEP_EXP_Grenade_Frag_Explosion'

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=450
		CamShakeOuterRadius=900
		CamShakeFalloff=0.5f
		bOrientCameraShakeTowardsEpicenter=true
		bUseOverlapCheck=false
	End Object
	SacrificeExplosionTemplate=ExploTemplate0

	Begin Object Class=KFGameExplosion Name=ExploTemplate1
		Damage=45 //15
		DamageRadius=450
		DamageFalloffExponent=1.f
		DamageDelay=0.f
		MyDamageType=class'KFDT_Toxic_DemoNuke'
		//bIgnoreInstigator is set to true in PrepareExplosionTemplate

		// Damage Effects
		KnockDownStrength=0
		KnockDownRadius=0
		FractureMeshRadius=200.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'FX_Impacts_ARCH.Explosions.Nuke_Explosion'
		ExplosionSound=AkEvent'WW_GLO_Runtime.Play_WEP_Nuke_Explo'
		MomentumTransferScale=1.f

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=200
		CamShakeOuterRadius=900
		CamShakeFalloff=1.5f
		bOrientCameraShakeTowardsEpicenter=true
	End Object
	NukeExplosionTemplate=ExploTemplate1

	Begin Object Class=KFGameExplosion Name=ExploTemplate2
		Damage=200
		DamageRadius=1000
		DamageFalloffExponent=1.f
		DamageDelay=0.f
		MyDamageType=class'KFDT_Explosive_DoorTrap'

		// Damage Effects
		KnockDownStrength=10
		KnockDownRadius=100
		FractureMeshRadius=500.0
		FracturePartVel=500.0
		ExplosionEffects=KFImpactEffectInfo'WEP_Dynamite_ARCH.Dynamite_Explosion'
		ExplosionSound=AkEvent'WW_WEP_EXP_Grenade_Frag.Play_WEP_EXP_Grenade_Frag_Explosion'

		// Camera Shake
		CamShake=CameraShake'FX_CameraShake_Arch.Grenades.Default_Grenade'
		CamShakeInnerRadius=450
		CamShakeOuterRadius=900
		CamShakeFalloff=0.5f
		bOrientCameraShakeTowardsEpicenter=true
		bUseOverlapCheck=false
	End Object
	DoorTrapExplosionTemplate=ExploTemplate2

	NukeExplosionActorClass=class'KFExplosion_Nuke'
	NukeDamageModifier=1.5   //1.25
	NukeRadiusModifier=1.35  //1.25
	LingeringNukePoisonDamage=20
	LingeringNukeDamageType=class'KFDT_DemoNuke_Toxic_Lingering'

	ConcussiveExplosionSound=AkEvent'WW_WEP_SA_RPG7.Play_WEP_SA_RPG7_Explosion'

    // Skill tracking
	HitAccuracyHandicap=2.0
	HeadshotAccuracyHandicap=0.0

	// Prestige Rewards
	PrestigeRewardItemIconPaths[0]="WEP_SkinSet_Prestige01_Item_TEX.knives.DemoKnife_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[1]="WEP_SkinSet_Prestige02_Item_TEX.tier01.HX25_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[2]="WEP_skinset_prestige03_itemtex.tier02.M79_PrestigePrecious_Mint_large"
	PrestigeRewardItemIconPaths[3]="wep_skinset_prestige04_itemtex.tier03.M16M203_PrestigePrecious_Mint_Large"
	PrestigeRewardItemIconPaths[4]="WEP_SkinSet_Prestige05_Item_TEX.tier04.RPG-7_PrestigePrecious_Mint_large"

   	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"
   	ZedTimeModifyingStates(3)="Reloading"
   	ZedTimeModifyingStates(4)="WeaponSingleFireAndReload"
   	ZedTimeModifyingStates(5)="FiringSecondaryState"
   	ZedTimeModifyingStates(6)="AltReloading"
    ZedTimeModifyingStates(7)="WeaponThrowing"
	ZedTimeModifyingStates(8)="HuskCannonCharge"

   	PassiveExtraAmmoIgnoredClassNames(0)="KFProj_DynamiteGrenade"

   	ExtraAmmoIgnoredClassNames(0)="KFProj_DynamiteGrenade"
   	ExtraAmmoIgnoredClassNames(1)="KFWeap_Thrown_C4"

	TacticalReloadAsReloadRateClassNames(0)="KFWeap_GrenadeLauncher_M32"

   	OnlySecondaryAmmoWeapons(0)="KFWeap_AssaultRifle_M16M203"

   	DamageIgnoredDTs(0)="KFDT_Ballistic_M16M203"
   	DamageIgnoredDTs(1)="KFDT_Bludgeon_M16M203"

   	AutoBuyLoadOutPath=(class'KFWeapDef_HX25', class'KFWeapDef_M79', class'KFWeapDef_M16M203', class'KFWeapDef_RPG7', class'KFWeapDef_M32')

    // Classic Perk
    BasePerk=class'KFPerk_Demolitionist'
    EXPActions(0)="Dealing Demolitionist weapon damage"
    EXPActions(1)="Killing Fleshpounds with Demolitionist weapons"
    PassiveInfos[0]=(Title="Perk Weapon Damage")
    PassiveInfos[1]=(Title="Explosive Resistance")
    PassiveInfos[2]=(Title="Extra Explosive Ammo")
    PassiveInfos[3]=(Title="Explosive AOE Radius")
}
