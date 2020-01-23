class ApocPerk_Sharpshooter extends ClassicPerk_Base
	config(ApocPerksStat);

//`include(KFOnlineStats.uci)

var config PerkSkill			HeadshotDamage;
var config PerkSkill			Recoil;
var config PerkSkill			WeaponSwitchSpeed;
var private	const AkEvent		RhythmMethodSoundReset;
var private	const AkEvent		RhythmMethodSoundHit;
var private	const AkEvent		RhythmMethodSoundTop;
var private	const name 			RhytmMethodRTPCName;

enum ESharpshooterPerkSkills
{
	ESharpshooterStationaryAim,
	ESharpshooterTrigger,
	ESharpshooterCrouchAim,
	ESharpshooterStun,
	ESharpshooterRhythmMethod,
	ESharpshooterTacticalReload,
	ESharpshooterScoped,
	ESharpshooterAmmoPouch,
	ESharpshooterZTKnockdown,
	ESharpshooterZTStun
};

var private 	  int			HeadShotComboCount;
var private 	  int			HeadShotComboCountDisplay;
var private const float 		HeadShotCountdownIntervall;
var private const int 			MaxHeadShotComboCount;
var private const float 		CameraViewShakeScale;
var private const float 		TriggerMovementSpeedModifier;
var private const float 		CrouchAimMovementSpeedModifier;
var private const float 		CrouchAimReloadSpeedModifier;
var	private const array<Name>	AdditionalOnPerkWeaponNames;
var	private const array<Name>	AdditionalOnPerkDTNames;

/** The % chance that zed time will be activated when damage is done when the Zed Time perk skills are active */
var float SkillZedTimeChance;

/*********************************************************************************************
* @name	 Stats/XP
********************************************************************************************* */

simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round(GetPassiveValue( default.HeadshotDamage, Level, default.HeadshotDamage.Rank ) * 100) @ "%";
	PassiveValues[1] = Round(GetPassiveValue( default.Recoil, Level, default.Recoil.Rank ) * 100) @ "%";
	PassiveValues[2] = Round(GetPassiveValue( default.WeaponSwitchSpeed, Level, default.WeaponSwitchSpeed.Rank ) * 100) @ "%";
	PassiveValues[3] = "";
	PassiveValues[4] = "";

	Increments[0] = "[" @ Left( string( default.HeadshotDamage.Increment * 100 ), InStr(string(default.HeadshotDamage.Increment * 100), ".") + 2 )@"% / +" $ default.HeadshotDamage.Rank @ default.LevelString @ "]";
	Increments[1] = "[" @ Left( string( default.Recoil.Increment * 100 ), InStr(string(default.Recoil.Increment * 100), ".") + 2 )@ "% / +" $ default.Recoil.Rank @ default.LevelString @ "]";
	Increments[2] = "[" @ Left( string( default.WeaponSwitchSpeed.Increment * 100 ), InStr(string(default.WeaponSwitchSpeed.Increment * 100), ".") + 2 )@ "% / +" $ default.WeaponSwitchSpeed.Rank @ default.LevelString @ "]";
	Increments[3] = "";
	Increments[4] = "";
}

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

/**
 * @brief Weapons and perk skills can affect the jog/sprint speed
 *
 * @param Speed jog/sprint speed
  */
simulated function ModifySpeed( out float Speed )
{
	if( IsTriggerActive() )
	{
		`QALog( "(Trigger) speed" @ Speed @ GetPercentage(Speed, (Speed += Speed * static.GetTriggerMovementSpeedModifier())), bLogPerk );
		Speed += Speed * static.GetTriggerMovementSpeedModifier();
	}

	if( IsCrouchAimActive(GetOwnerWeapon()) )
	{
		`QALog( "(Crouch Aim / Stability) speed" @ Speed @ GetPercentage(Speed, (Speed += Speed * static.GetCrouchAimMovementSpeedModifier())), bLogPerk );
		Speed += Speed * static.GetCrouchAimMovementSpeedModifier();
	}
}

/**
 * @brief The Quick Switch skill modifies the weapon switch speed
 *
 * @param ModifiedSwitchTime Duration of putting down or equipping the weapon
 */
simulated function ModifyWeaponSwitchTime( out float ModifiedSwitchTime )
{
	`QALog( "(Passive Weapon Switch) Increase:" @ GetPercentage( ModifiedSwitchTime,  ModifiedSwitchTime * (1.f - GetPassiveValue(WeaponSwitchSpeed, CurrentLevel, WeaponSwitchSpeed.Rank)) ), bLogPerk );
	ModifiedSwitchTime *= (1.f - GetPassiveValue(WeaponSwitchSpeed, CurrentLevel, WeaponSwitchSpeed.Rank));
}

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

	if( (KFW != none && IsWeaponOnPerk( KFW,, self.class )) || (DamageType != none && IsDamageTypeOnPerk(DamageType)) )
	{
		if( MyKFPM != none && HitZoneIdx == HZI_HEAD )
		{
			`QALog( "(Headshot), damage mod=" $GetPassiveValue( HeadshotDamage, CurrentLevel, HeadshotDamage.Rank ), bLogPerk );
			TempDamage += InDamage * GetPassiveValue( HeadshotDamage, CurrentLevel, HeadshotDamage.Rank );

			if( GetScopedActive(KFW) )
			{
				`QALog( "(Scoped), damage mod=" $GetSkillValue( PerkSkills[ESharpshooterScoped] ), bLogPerk );
				TempDamage += InDamage * GetSkillValue( PerkSkills[ESharpshooterScoped] );
			}

			// cause dramatic event during damage so that perk's zed time modifications to incaps can happen same frame
			if( IsZTKnockdownActive() || IsZTStunActive() )
			{
				if( MyKFGI != none )
				{
					MyKFGI.DramaticEvent( SkillZedTimeChance );
				}
			}

			if( GetZTKnockdownActive() )
			{
				`QALog( "(Assassin), damage mod=" $GetSkillValue( PerkSkills[ESharpshooterZTKnockdown] ), bLogPerk );
				TempDamage += InDamage * GetSkillValue( PerkSkills[ESharpshooterZTKnockdown] );
			}
		}

		if( IsStationaryAimActive() && VSizeSq(OwnerPawn.Velocity) <= 0 )
		{
			`QALog( "(Stationary), damage mod=" $GetSkillValue( PerkSkills[ESharpshooterStationaryAim] ), bLogPerk );
			TempDamage += InDamage * GetSkillValue( PerkSkills[ESharpshooterStationaryAim] );
		}

		if( IsCrouchAimActive(GetOwnerWeapon()) )
		{
			`QALog( "(Crouched), damage mod=" $ GetSkillValue( PerkSkills[ESharpshooterCrouchAim] ), bLogPerk );
			TempDamage += InDamage * GetSkillValue( PerkSkills[ESharpshooterCrouchAim] );
		}

		if( IsRhythmMethodActive() && HeadShotComboCount > 0 )
		{
			`QALog( "(RhythmMethod), HeadShotComboCount=" $HeadShotComboCount$", DamageMod="$(GetSkillValue( PerkSkills[ESharpshooterRhythmMethod] ) * HeadShotComboCount), bLogPerk );
			TempDamage += Indamage * GetSkillValue( PerkSkills[ESharpshooterRhythmMethod] ) * HeadShotComboCount;
		}
	}

	`QALog( "Total Damage Given - DamageType: "$DamageType$"; Weapon: "$KFW$"; In: "$InDamage$"; Out: "$FCeil( TempDamage )$"; Pct: "$GetPercentage( InDamage, Round( TempDamage ) ), bLogPerk );
	InDamage = FCeil( TempDamage );
}

/**
 * @brief The Quick Shot skill allows you to shoot faster
 *
 * @param InRate delay between shots
 * @param KFW Equipped weapon
 *
 */
simulated function ModifyRateOfFire( out float InRate, KFWeapon KFW )
{
	// don't modify the fire rate for grenades
	if( IsTriggerActive() && IsWeaponOnPerk( KFW,, self.class ) && KFW.CurrentFireMode != class'KFWeapon'.const.GRENADE_FIREMODE)
	{
		`QALog( "(Trigger)" @ KFW @ GetPercentage( InRate, ( InRate - InRate * GetSkillValue( PerkSkills[ESharpshooterTrigger] ) ) ), bLogPerk );
		InRate -= InRate * GetSkillValue( PerkSkills[ESharpshooterTrigger] );
	}
}

/**
 * @brief Modifies the reload speed for sharpshooter weapons
 *
 * @param ReloadDuration Length of the reload animation
 * @param GiveAmmoTime Time after the weapon actually gets some ammo
 */
simulated function float GetReloadRateScale( KFWeapon KFW )
{
	if( IsCrouchAimActive(KFW) )
	{
		`QALog( "Crouch Aim/Stabilty reload rate =" @ 1.f - GetCrouchAimReloadSpeedModifier(), bLogPerk  );
		return 1.f - GetCrouchAimReloadSpeedModifier();
	}

	return 1.f;
}

/**
 * @brief Modifies the weapon's recoil
 *
 * @param CurrentRecoilModifier percent recoil lowered
 */
simulated function ModifyRecoil( out float CurrentRecoilModifier, KFWeapon KFW )
{
    if (IsWeaponOnPerk(KFW, , self.class))
    {
        CurrentRecoilModifier -= CurrentRecoilModifier * GetPassiveValue(Recoil, CurrentLevel, Recoil.Rank);

        if (GetScopedActive(KFW))
        {
            `QALog( "(Scoped)" @ KFW @ GetPercentage(CurrentRecoilModifier, CurrentRecoilModifier - CurrentRecoilModifier * GetSkillValue(PerkSkills[ESharpshooterScoped])), bLogPerk );
            CurrentRecoilModifier -= CurrentRecoilModifier * GetSkillValue(PerkSkills[ESharpshooterScoped]);
        }
    }
}

simulated event float GetCameraViewShakeModifier( KFWeapon OwnerWeapon )
{
	if( GetScopedActive( OwnerWeapon ) )
	{
		return static.GetCameraViewShakeScale();
	}

	return 1;
}

simulated final static function float GetCameraViewShakeScale()
{
	return default.CameraViewShakeScale;
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

	if( IsAmmoPouchActive() && IsWeaponOnPerk( KFW, TraderItem.AssociatedPerkClasses, self.class, TraderItem.ClassName ) )
	{
		TempMaxSpareAmmoAmount = MaxSpareAmmo;
		TempMaxSpareAmmoAmount += TempMaxSpareAmmoAmount * GetSkillValue( PerkSkills[ESharpshooterAmmoPouch] );
		MaxSpareAmmo = Round( TempMaxSpareAmmoAmount );
	}
}

/**
 * @brief Applies skill specific changes after new skills were selected
  */
simulated protected event PostSkillUpdate()
{
	if( IsAmmoPouchActive() )
	{
		MaxGrenadeCount = default.MaxGrenadeCount + default.MaxGrenadeCount * GetSkillValue( PerkSkills[ESharpshooterAmmoPouch] );
	}
	else
	{
		MaxGrenadeCount = default.MaxGrenadeCount;
	}

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

event Destroyed()
{
	if( Role == Role_Authority )
	{
		ServerClearHeadShotsCombo();
	}
}

/**
 * @brief Should the tactical reload skill adjust the reload speed
 *
 * @param KFW weapon in use
 * @return true/false
 */
simulated function bool GetUsingTactialReload( KFWeapon KFW )
{
	`QALog( "Tactical Reload Active =" @ (IsTacticalReloadActive() && IsWeaponOnPerk( KFW,, self.class )), bLogPerk );
	return IsTacticalReloadActive() && (IsWeaponOnPerk( KFW, , self.class) || IsBackupWeapon( KFW ));
}

/**
 * @brief skills and weapons can modify the stun power
 * @return stun power modifier
 */
function float GetStunPowerModifier( optional class<DamageType> DamageType, optional byte HitZoneIdx )
{
	if( IsDamageTypeOnPerk(class<KFDamageType>(DamageType)) )
	{
		if( HitZoneIdx == HZI_Head && GetZTStunActive() )
		{
			`QALog( "(ZT Stun)" @ GetSkillValue(PerkSkills[ESharpshooterZTStun]), bLogPerk );
			return GetSkillValue( PerkSkills[ESharpshooterZTStun] );
		}
		else if( IsStunActive() )
		{
			`QALog( "(Stun)" @ GetSkillValue( PerkSkills[ESharpshooterStun] ), bLogPerk );
        	return GetSkillValue( PerkSkills[ESharpshooterStun] );
		}
	}

    return 0.f;
}

/**
 * @brief Checks if the Stationary Aim skill is active
 *
 * @return true/false
 */
function bool IsStationaryAimActive()
{
	return PerkSkills[ESharpshooterStationaryAim].bActive && IsPerkLevelAllowed(ESharpshooterStationaryAim);
}

/**
 * @brief Checks if the Trigger skill is active
 *
 * @return true/false
 */
simulated function bool IsTriggerActive()
{
	return PerkSkills[ESharpshooterTrigger].bActive && IsPerkLevelAllowed(ESharpshooterTrigger);
}

/**
 * @brief Checks if the Crouch Aim skill is active
 *
 * @return true/false
 */
simulated function bool IsCrouchAimActive( KFWeapon W )
{
	return PerkSkills[ESharpshooterCrouchAim].bActive && CheckOwnerPawn() && OwnerPawn.bIsCrouched && IsWeaponOnPerk( W,, self.class ) && IsPerkLevelAllowed(ESharpshooterCrouchAim);
}

/**
 * @brief Checks if the Stun skill is active
 *
 * @return true/false
 */
simulated function bool IsStunActive()
{
	return PerkSkills[ESharpshooterStun].bActive && IsPerkLevelAllowed(ESharpshooterStun);
}

/**
 * @brief Checks if the Rhythm Method skill is active
 *
 * @return true/false
 */
simulated function bool IsRhythmMethodActive()
{
	return PerkSkills[ESharpshooterRhythmMethod].bActive && IsPerkLevelAllowed(ESharpshooterRhythmMethod);
}

/**
 * @brief Checks if the Tactical Reload skill is active
 *
 * @return true/false
 */
simulated function bool IsTacticalReloadActive()
{
	return PerkSkills[ESharpshooterTacticalReload].bActive && IsPerkLevelAllowed(ESharpshooterTacticalReload);
}

/**
 * @brief Checks if the Speed Freak skill is active
 *
 * @return true/false
 */
simulated function bool IsScopedActive()
{
	return PerkSkills[ESharpshooterScoped].bActive && IsPerkLevelAllowed(ESharpshooterScoped);
}

simulated function bool GetScopedActive( KFWeapon KFW )
{
	return IsScopedActive() && KFW != none && KFW.bUsingSights;
}

/**
 * @brief Checks if the Deep Freeze skill is active
 *
 * @return true/false
 */
simulated function bool IsAmmoPouchActive()
{
	return PerkSkills[ESharpshooterAmmoPouch].bActive && IsPerkLevelAllowed(ESharpshooterAmmoPouch);
}

/**
 * @brief Checks if the Knockdown skill is active
 *
 * @return true/false
 */
simulated function bool IsZTKnockdownActive()
{
	return PerkSkills[ESharpshooterZTKnockdown].bActive && IsPerkLevelAllowed(ESharpshooterZTKnockdown);
}

/**
 * @brief Checks if the Speed Freak skill is active and if we are in zed time
 *
 * @return true/false
 */
simulated function bool GetZTKnockdownActive()
{
	return IsZTKnockdownActive() && WorldInfo.TimeDilation < 1.f;
}

/**
 * @brief Checks if the ZTStun skill is active
 *
 * @return true/false
 */
simulated function bool IsZTStunActive()
{
	return PerkSkills[ESharpshooterZTStun].bActive && IsPerkLevelAllowed(ESharpshooterZTStun);
}

/**
 * @brief Checks if the Speed Freak skill is active and if we are in zed time
 *
 * @return true/false
 */
simulated function bool GetZTStunActive()
{
	return IsZTStunActive() && WorldInfo.TimeDilation < 1.f;
}

static function int GetMaxHeadShotComboCount()
{
	return default.MaxHeadShotComboCount;
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
	`QALog( "", bLogPerk );

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

simulated private static function float GetTriggerMovementSpeedModifier()
{
	return default.TriggerMovementSpeedModifier;
}

simulated private static function float GetCrouchAimMovementSpeedModifier()
{
	return default.CrouchAimMovementSpeedModifier;
}

simulated private static function float GetCrouchAimReloadSpeedModifier()
{
	return default.CrouchAimReloadSpeedModifier;
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
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[66]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
	PrimaryWeaponDef=class'KFWeapDef_Winchester1894'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
	KnifeWeaponDef=class'KFWeapDef_Knife_Sharpshooter'
	GrenadeWeaponDef=class'KFWeapDef_Grenade_Sharpshooter'

	ProgressStatID=STATID_Shrp_Progress
   	PerkBuildStatID=STATID_Shrp_Build

   	MaxHeadShotComboCount=5
   	HeadShotCountdownIntervall=2.f
   	RhytmMethodRTPCName="R_Method"
   	RhythmMethodSoundReset=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Reset'
	RhythmMethodSoundHit=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Hit'
	RhythmMethodSoundTop=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Top'
	TriggerMovementSpeedModifier=0.1 //0.15
	CrouchAimMovementSpeedModifier=0.5f //0.1 //0.5
	CrouchAimReloadSpeedModifier=0.2 //0.15 //0.2

	AdditionalOnPerkWeaponNames(0)="KFWeap_Pistol_9mm"
   	AdditionalOnPerkWeaponNames(1)="KFWeap_Pistol_Dual9mm"
   	AdditionalOnPerkWeaponNames(2)="KFWeap_Revolver_Rem1858"
   	AdditionalOnPerkWeaponNames(3)="KFWeap_Revolver_SW500"
	AdditionalOnPerkDTNames(0)="KFDT_Ballistic_9mm"
	AdditionalOnPerkDTNames(1)="KFDT_Ballistic_SW500"
	AdditionalOnPerkDTNames(2)="KFDT_Ballistic_Rem1858"


   	//HeadshotDamage=(Name="Headshot Damage",Increment=0.01f,Rank=1,StartingValue=0.0f,MaxValue=0.25f)
   	//Recoil=(Name="Recoil",Increment=0.01f,Rank=1,StartingValue=0.0f,MaxValue=0.25f)
   	//WeaponSwitchSpeed=(Name="Weapon Switch Speed",Increment=0.02f,Rank=1,StartingValue=0.0f,MaxValue=0.50f)

   	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"

   	PerkSkills(ESharpshooterStationaryAim)=(Name="StationaryAim",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_StationaryAim", Increment=0.f,Rank=0,StartingValue=0.25,MaxValue=0.25)    //0.1
	PerkSkills(ESharpshooterTrigger)=(Name="Trigger",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_Trigger",	Increment=0.f,Rank=0,StartingValue=0.25,MaxValue=0.25)
	PerkSkills(ESharpshooterCrouchAim)=(Name="CrouchAim",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_CrouchAim", Increment=0.f,Rank=0,StartingValue=0.30,MaxValue=0.30)
	PerkSkills(ESharpshooterStun)=(Name="Stun",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_Stun", Increment=0.f,Rank=0,StartingValue=1.0,MaxValue=1.0)
	PerkSkills(ESharpshooterRhythmMethod)=(Name="RhythmMethod",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_RackUmUp", Increment=0.f,Rank=0,StartingValue=0.10f,MaxValue=0.10f)
	PerkSkills(ESharpshooterTacticalReload)=(Name="TacticalReload",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_TacticalReload", Increment=0.f,Rank=0,StartingValue=0.0f,MaxValue=0.0f)
	PerkSkills(ESharpshooterScoped)=(Name="Scoped",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_Scoped", Increment=0.f,Rank=0,StartingValue=0.1f,MaxValue=0.1f)
	PerkSkills(ESharpshooterAmmoPouch)=(Name="AmmoPouch",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_AmmoPouch", Increment=0.f,Rank=0,StartingValue=0.25f,MaxValue=0.25f)
	PerkSkills(ESharpshooterZTKnockdown)=(Name="ZTKnockdown",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_ZED-KnockDown", Increment=0.f,Rank=0,StartingValue=0.35f,MaxValue=0.35f) //0.35
	PerkSkills(ESharpshooterZTStun)=(Name="ZTStun",IconPath="UI_PerkTalent_TEX.Sharpshooter.UI_Talents_Sharpshooter_ZED-Stun", Increment=0.f,Rank=0,StartingValue=4.0,MaxValue=4.0)

	SkillZedTimeChance=0.05  //0.05

    // Skill tracking
	HitAccuracyHandicap=-9.0
	HeadshotAccuracyHandicap=-16.0

	// xp per headshot (all headshots, not just lethal)
	SecondaryXPModifier(0)=1
   	SecondaryXPModifier(1)=1
   	SecondaryXPModifier(2)=1
   	SecondaryXPModifier(3)=1

   	CameraViewShakeScale=0.5
   	AutoBuyLoadOutPath=(class'KFWeapDef_Winchester1894', class'KFWeapDef_Crossbow', class'KFWeapDef_M14EBR', class'KFWeapDef_RailGun', class'KFWeapDef_M99')
   	AssistDoshModifier=1.1f

    // Classic Perk
    BasePerk=class'KFPerk_Sharpshooter'
    EXPActions(0)="Dealing Sharpshooter weapon damage"
    EXPActions(1)="Head shots with Sharpshooter weapons"
    PassiveInfos(0)=(Title="Headshot Damage")
    PassiveInfos(1)=(Title="Fire Speed")
    PassiveInfos(2)=(Title="Reload Speed")
    PassiveInfos(3)=(Title="Recoil")
}
