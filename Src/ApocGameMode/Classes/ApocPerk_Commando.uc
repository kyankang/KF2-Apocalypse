class ApocPerk_Commando extends ClassicPerk_Base;

//Passives
//var private const PerkSkill WeaponDamage;			// weapon dmg modifier
var private const PerkSkill	CloakedEnemyDetection;  // Can see cloaked zeds x UUs far (100UUs = 100cm = 1m)
var private const PerkSkill	ZedTimeExtension;       // How many times a zed time ext can happen
var private const PerkSkill	ReloadSpeed;		    // 2% increase every 5 levels (max 10% increase)
var private const PerkSkill	CallOut;		        // allow teammates to see cloaked units
var private const PerkSkill	NightVision;            // Night vision
var private	const PerkSkill	Recoil;					// Recoil reduction

var private const float	RapidFireFiringRate;    	// Faster firing rate in %  NOTE:This is needed for combinations with the Skill: RapidFire (Damage and Rate)
var private const float BackupWeaponSwitchModifier;
var private const float	HealthArmorModifier;

/** Temp HUD */
var Texture2d WhiteMaterial;

enum ECommandoSkills
{
	ECommandoTacticalReload,
	ECommandoLargeMags,
	ECommandoBackup,
	ECommandoImpact,
	ECommandoHealthIncrease,
	ECommandoAmmoVest,
	ECommandoHollowPoints,
	ECommandoEatLead,
	ECommandoProfessional,
	ECommandoRapidFire
};

/** On spawn, modify owning pawn based on perk selection */
function SetPlayerDefaults( Pawn PlayerPawn )
{
	local float NewArmor;

	super.SetPlayerDefaults( PlayerPawn );

	if( OwnerPawn.Role == ROLE_Authority && IsHealthIncreaseActive() )
	{
		NewArmor = OwnerPawn.default.MaxArmor * static.GetHealthArmorModifier();
		OwnerPawn.AddArmor( Round( NewArmor ) );
	}
}

/*********************************************************************************************
* @name	 Passive skills functions
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

	TempDamage = InDamage;

	if( DamageCauser != none )
	{
		KFW = GetWeaponFromDamageCauser( DamageCauser );
	}

	if( (KFW != none && IsWeaponOnPerk( KFW,, self.class )) || (DamageType != none && IsDamageTypeOnPerk( DamageType )) )
	{
		TempDamage += InDamage * GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank );
		if( IsRapidFireActive() )
		{
			`QALog( "RapidFire Damage" @ KFW @ GetPercentage( InDamage, InDamage * GetSkillValue( PerkSkills[ECommandoRapidFire] )), bLogPerk );
			TempDamage +=  InDamage * GetSkillValue( PerkSkills[ECommandoRapidFire] );
		}
	}

	//Specific exclusion of grenades here so as not to cause issues in other areas of the code that would have required more extensive changes.
	//		Basically, GetWeaponFromDamageCauser should never have been returning the equipped weapon for grenades, but now that we
	//		have the perks so tied into using that, it's easier to just specifically fix commando here.
	if( KFW != none && !DamageCauser.IsA('KFProj_Grenade'))
	{
		if( IsBackupActive() && IsBackupWeapon( KFW ) )
		{
			`QALog( "Backup Damage" @ KFW @ GetPercentage( InDamage, InDamage * GetSkillValue( PerkSkills[ECommandoBackup] )), bLogPerk );
			TempDamage += InDamage * GetSkillValue( PerkSkills[ECommandoBackup] );
		}

		if( IsWeaponOnPerk( KFW,, self.class ) )
		{
			if( IsHollowPointsActive() )
			{
				`QALog( "Hollow points DMG" @ KFW @ GetPercentage(InDamage, InDamage * GetSkillValue( PerkSkills[ECommandoHollowPoints] )), bLogPerk );
	    		TempDamage += InDamage * GetSkillValue( PerkSkills[ECommandoHollowPoints] );
			}
		}
	}

	`QALog( "Total Damage Given" @ DamageType @ KFW @ GetPercentage( InDamage, FCeil(TempDamage) ), bLogPerk );
	InDamage = FCeil(TempDamage);
}

/**
 * @brief how far away we can see stalkers
 *
 * @return range in UUs
 */
simulated function float GetCloakDetectionRange()
{
	return GetPassiveValue( CloakedEnemyDetection, CurrentLevel, CloakedEnemyDetection.Rank );
}

/**
 * @brief How long can we extend zed time?
 * @details Zed time extended by 1 second starting at level 0
 *			and every milestone level thereafter to a maximum of 5 seconds
 * @param Level the perk's level
 * @return zed time extension in seconds
 */
simulated static function float GetZedTimeExtension( byte Level )
{
	if( Level >= 10 )
	{
		return default.ZedTimeExtension.MaxValue;
	}
	else if( Level >= 8 )
	{
		return default.ZedTimeExtension.StartingValue + 4 * default.ZedTimeExtension.Increment;
	}
	else if( Level >= 6 )
	{
		return default.ZedTimeExtension.StartingValue + 3 * default.ZedTimeExtension.Increment;
	}
	else if( Level >= 4 )
	{
		return default.ZedTimeExtension.StartingValue + 2 * default.ZedTimeExtension.Increment;
	}
	else if( Level >= 2 )
	{
		return default.ZedTimeExtension.StartingValue + default.ZedTimeExtension.Increment;
	}

	return 1.0f;
}

/**
 * @brief Calculates the additional ammo per perk level
 *
 * @param Level Current perk level
 * @return additional ammo
 */
simulated private final static function float GetExtraReloadSpeed( int Level )
{
	return default.ReloadSpeed.Increment * FFloor( float( Level ) / default.ReloadSpeed.Rank );
}

/**
 * @brief Modifies the reload speed for commando weapons
 *
 * @param ReloadDuration Length of the reload animation
 * @param GiveAmmoTime Time after the weapon actually gets some ammo
 */
simulated function float GetReloadRateScale( KFWeapon KFW )
{
	if( IsWeaponOnPerk( KFW,, self.class ) )
	{
		return 1.f - GetExtraReloadSpeed( CurrentLevel );
	}

	return 1.f;
}

/**
 * @brief modifies the players health 1% per level
 *
 * @param InHealth health
 */
function ModifyHealth( out int InHealth )
{
	local float TempHealth;

	if( IsHealthIncreaseActive() )
	{
		TempHealth = InHealth;
		TempHealth += InHealth * GetSkillValue( PerkSkills[ECommandoHealthIncrease] );
		InHealth = Round(TempHealth);
		`QALog( "Health Increase" @ InHealth, bLogPerk );
	}
}

/**
 * @brief Modifies the pawn's MaxArmor
 *
 * @param MaxArmor the maximum armor value
 */
function ModifyArmor( out byte MaxArmor )
{
	local float TempArmor;

	if( IsHealthIncreaseActive() )
	{
		TempArmor = MaxArmor;
		TempArmor += MaxArmor * GetSkillValue( PerkSkills[ECommandoHealthIncrease] );
		MaxArmor = Round( TempArmor );
	}
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
	return ( IsTacticalReloadActive() && (IsWeaponOnPerk( KFW,, self.class ) || IsBackupWeapon( KFW )) );
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

	if( !bSecondary && IsWeaponOnPerk( KFW, WeaponPerkClass, self.class ) && (KFW == none || !KFW.bNoMagazine) )
	{
		if( IsLargeMagActive() )
		{
			TempCapacity += MagazineCapacity * GetSkillValue( PerkSkills[ECommandoLargeMags] );
		}

		if( IsEatLeadActive() )
		{
       		TempCapacity += MagazineCapacity * GetSkillValue( PerkSkills[ECommandoEatLead] );
		}
	}

	MagazineCapacity = Round(TempCapacity);
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

	if( IsAmmoVestActive() && (IsWeaponOnPerk( KFW, TraderItem.AssociatedPerkClasses, self.class ) ||
		IsBackupWeapon( KFW )) )
	{
		TempMaxSpareAmmoAmount = MaxSpareAmmo;
		TempMaxSpareAmmoAmount += MaxSpareAmmo * GetSkillValue( PerkSkills[ECommandoAmmoVest] );
		MaxSpareAmmo = Round( TempMaxSpareAmmoAmount );
	}
}

static simulated private function bool Is9mm( KFWeapon KFW )
{
	return KFW != none && KFW.default.bIsBackupWeapon && !KFW.IsMeleeWeapon();
}

/**
 * @brief Skills can modify the zed time time dilation
 *
 * @param StateName used weapon's state
 * @return time dilation modifier
 */
simulated function float GetZedTimeModifier( KFWeapon W )
{
	local name StateName;
	StateName = W.GetStateName();

	if( IsProfessionalActive() && (IsWeaponOnPerk( W,, self.class ) || IsBackupWeapon( W )) )
	{
		if( StateName == 'Reloading' ||
			StateName == 'AltReloading' )
		{
			return 1.f;
		}
		else if( StateName == 'WeaponPuttingDown' || StateName == 'WeaponEquipping' )
		{
			return 0.3f;
		}
	}

	if( CouldRapidFireActive() && (Is9mm(W) || IsWeaponOnPerk( W,, self.class )) && ZedTimeModifyingStates.Find( StateName ) != INDEX_NONE )
	{
		return RapidFireFiringRate;
	}

	return 0.f;
}

/**
 * @brief skills and weapons can modify the stumbling power
 * @return stumpling power modifier
 */
function float GetStumblePowerModifier( optional KFPawn KFP, optional class<KFDamageType> DamageType, optional out float CooldownModifier, optional byte BodyPart )
{
	local KFWeapon KFW;

	KFW = GetOwnerWeapon();
	if( IsImpactActive() && IsWeaponOnPerk( KFW,, self.class ) )
	{
		return GetSkillValue( PerkSkills[ECommandoImpact] );
	}

	return 0.f;
}

/**
 * @brief The Backup skill modifies the weapon switch speed
 *
 * @param ModifiedSwitchTime Duration of putting down or equipping the weapon
 */
simulated function ModifyWeaponSwitchTime( out float ModifiedSwitchTime )
{
	if( IsBackupActive() )
	{
		`QALog( "Backup switch weapon increase:" @ GetPercentage( ModifiedSwitchTime,  ModifiedSwitchTime * GetBackupWeaponSwitchModifier() ), bLogPerk );
		ModifiedSwitchTime -= ModifiedSwitchTime * static.GetBackupWeaponSwitchModifier();
	}
}

simulated final static function float GetBackupWeaponSwitchModifier()
{
	return default.BackupWeaponSwitchModifier;
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
        CurrentRecoilModifier *= (1.f - GetPassiveValue(Recoil, CurrentLevel, Recoil.Rank));
    }
}

private static function float GetHealthArmorModifier()
{
	return default.HealthArmorModifier;
}

/*********************************************************************************************
* @name	Getters
********************************************************************************************* */
/**
 * @brief Checks if call out skill is active
 *
 * @return true/false
 */
simulated function bool IsCallOutActive()
{
	return true;
}

/**
 * @brief Checks if night vision skill is active
 *
 * @return true/false
 */
simulated function bool HasNightVision()
{
	return true;
}

/**
 * @brief Checks if rapid fire skill is active and if we are in zed time
 *
 * @return true/false
 */
simulated protected function bool IsRapidFireActive()
{
	return PerkSkills[ECommandoRapidFire].bActive && WorldInfo.TimeDilation < 1.f && IsPerkLevelAllowed(ECommandoRapidFire);
}

simulated protected function bool CouldRapidFireActive()
{
	return PerkSkills[ECommandoRapidFire].bActive && IsPerkLevelAllowed(ECommandoRapidFire);
}

/**
 * @brief Checks if large mag skill is active
 *
 * @return true/false
 */
simulated final private function bool IsLargeMagActive()
{
	return PerkSkills[ECommandoLargeMags].bActive && IsPerkLevelAllowed(ECommandoLargeMags);
}

/**
 * @brief Checks if backup damage skill is active
 *
 * @return true/false
 */
simulated final private function bool IsBackupActive()
{
	return PerkSkills[ECommandoBackup].bActive && IsPerkLevelAllowed(ECommandoBackup);
}

/**
 * @brief Checks if Hollow Points skill is active
 *
 * @return true/false
 */
simulated private function bool IsHollowPointsActive()
{
	return PerkSkills[ECommandoHollowPoints].bActive && IsPerkLevelAllowed(ECommandoHollowPoints);
}

/**
 * @brief Checks if tactical reload skill is active (client & server)
 *
 * @return true/false
 */
simulated final private function bool IsTacticalReloadActive()
{
	return PerkSkills[ECommandoTacticalReload].bActive && IsPerkLevelAllowed(ECommandoTacticalReload);
}

/**
 * @brief Checks if impact skill is active
 *
 * @return true/false
 */
final private function bool IsImpactActive()
{
	return PerkSkills[ECommandoImpact].bActive && IsPerkLevelAllowed(ECommandoImpact);
}

/**
 * @brief Checks if health increase skill is active
 *
 * @return true/false
 */
final private function bool IsHealthIncreaseActive()
{
	return PerkSkills[ECommandoHealthIncrease].bActive && IsPerkLevelAllowed(ECommandoHealthIncrease);
}

/**
 * @brief Checks if auto fire skill is active
 *
 * @return true/false
 */
final private function bool IsEatLeadActive()
{
	return PerkSkills[ECommandoEatLead].bActive && IsPerkLevelAllowed(ECommandoEatLead);
}

/**
 * @brief Checks if ammo vest skill is active
 *
 * @return true/false
 */
final private function bool IsAmmoVestActive()
{
	return PerkSkills[ECommandoAmmoVest].bActive && IsPerkLevelAllowed(ECommandoAmmoVest);
}

/**
 * @brief Checks if professional skill is active
 *
 * @return true/false
 */
simulated final private function bool IsProfessionalActive()
{
	return PerkSkills[ECommandoProfessional].bActive && IsPerkLevelAllowed(ECommandoProfessional);
}


/*********************************************************************************************
* @name	 Hud/UI
********************************************************************************************* */

simulated static function GetPassiveStrings( out array<string> PassiveValues, out array<string> Increments, byte Level )
{
	PassiveValues[0] = Round( GetPassiveValue( default.WeaponDamage, Level, default.WeaponDamage.Rank) * 100 ) @ "%";
	PassiveValues[1] = Round( GetPassiveValue( default.CloakedEnemyDetection, Level, default.CloakedEnemyDetection.Rank ) / 100 ) @ "m";		// Divide by 100 to convert unreal units to meters
	PassiveValues[2] = string(Round( GetZedTimeExtension( Level )));
	PassiveValues[3] = Round( GetExtraReloadSpeed( Level ) * 100 ) @ "%";
	PassiveValues[4] = Round(GetPassiveValue( default.Recoil, Level, default.Recoil.Rank ) * 100) @ "%";
	PassiveValues[5] = "";

	Increments[0] = "["@Left( string( default.WeaponDamage.Increment * 100 ), InStr(string(default.WeaponDamage.Increment * 100), ".") + 2 ) @"% / +" $ default.WeaponDamage.Rank @default.LevelString @"]";
	Increments[1] = "["@ Int(default.CloakedEnemyDetection.StartingValue / 100 ) @"+" @Int(default.CloakedEnemyDetection.Increment / 100 ) @"m / +" $ default.CloakedEnemyDetection.Rank @default.LevelString @"]";
	Increments[2] = "["@Round(default.ZedTimeExtension.StartingValue) @"+" @Round(default.ZedTimeExtension.Increment) @" / +" $ default.ZedTimeExtension.Rank @default.LevelString @"]";
	Increments[3] = "["@Left( string( default.ReloadSpeed.Increment * 100 ), InStr(string(default.ReloadSpeed.Increment * 100), ".") + 2 ) @ "% / +" $ default.ReloadSpeed.Rank @ default.LevelString @ "]";
	Increments[4] = "[" @ Left( string( default.Recoil.Increment * 100 ), InStr(string(default.Recoil.Increment * 100), ".") + 2 )@ "% / +" $ default.Recoil.Rank @ default.LevelString @ "]";
	Increments[5] = "";
}

/*********************************************************************************************
* @name	 Stats/XP
********************************************************************************************* */

/**
 * @brief how much XP is earned by a stalker kill depending on the game's difficulty
 *
 * @param Difficulty current game difficulty
 * @return XP earned
 */
simulated static function int GetStalkerKillXP( byte Difficulty )
{
	return default.SecondaryXPModifier[Difficulty];
}

/*********************************************************************************************
* @name	 Temp Hud things
********************************************************************************************* */
simulated function DrawSpecialPerkHUD(Canvas C)
{
	local KFPawn_Monster KFPM;
	local vector ViewLocation, ViewDir;
	local float DetectionRangeSq, ThisDot;
	local float HealthBarLength, HealthbarHeight;

	if( CheckOwnerPawn() )
	{
		DetectionRangeSq = Square( GetPassiveValue(CloakedEnemyDetection, CurrentVetLevel, CloakedEnemyDetection.Rank) );

		HealthbarLength = FMin( 50.f * (float(C.SizeX) / 1024.f), 50.f );
		HealthbarHeight = FMin( 6.f * (float(C.SizeX) / 1024.f), 6.f );

		ViewLocation = OwnerPawn.GetPawnViewLocation();
		ViewDir = vector( OwnerPawn.GetViewRotation() );

		foreach WorldInfo.AllPawns( class'KFPawn_Monster', KFPM )
		{
			if( !KFPM.CanShowHealth()
				|| !KFPM.IsAliveAndWell()
				|| `TimeSince(KFPM.Mesh.LastRenderTime) > 0.1f
				|| VSizeSQ(KFPM.Location - ViewLocation) > DetectionRangeSq )
			{
				continue;
			}

			ThisDot = ViewDir dot Normal(KFPM.Location - ViewLocation);

			if( ThisDot > 0.f )
			{
				DrawZedHealthbar( C, KFPM, ViewLocation, HealthbarHeight, HealthbarLength );
			}
		}
	}
}

simulated function DrawZedHealthbar(Canvas C, KFPawn_Monster KFPM, vector CameraLocation, float HealthbarHeight, float HealthbarLength )
{
	local vector ScreenPos, TargetLocation;
	local float HealthScale;

	if( KFPM.bCrawler && KFPM.Floor.Z <=  -0.7f && KFPM.Physics == PHYS_Spider )
	{
		TargetLocation = KFPM.Location + vect(0,0,-1) * KFPM.GetCollisionHeight() * 1.2 * KFPM.CurrentBodyScale;
	}
	else
	{
		TargetLocation = KFPM.Location + vect(0,0,1) * KFPM.GetCollisionHeight() * 1.2 * KFPM.CurrentBodyScale;
	}

	ScreenPos = C.Project( TargetLocation );
	if( ScreenPos.X < 0 || ScreenPos.X > C.SizeX || ScreenPos.Y < 0 || ScreenPos.Y > C.SizeY )
	{
		return;
	}

	if( `FastTracePhysX(TargetLocation,  CameraLocation) )
	{
		HealthScale = FClamp( float(KFPM.Health) / float(KFPM.HealthMax), 0.f, 1.f );

		C.EnableStencilTest( true );
		C.SetDrawColor(0, 0, 0, 255);
		C.SetPos( ScreenPos.X - HealthBarLength * 0.5, ScreenPos.Y );
		C.DrawTile( WhiteMaterial, HealthbarLength, HealthbarHeight, 0, 0, 32, 32 );

		C.SetDrawColor( 237, 8, 0, 255 );
		C.SetPos( ScreenPos.X - HealthBarLength * 0.5 + 1.0, ScreenPos.Y + 1.0 );
		C.DrawTile( WhiteMaterial, (HealthBarLength - 2.0) * HealthScale, HealthbarHeight - 2.0, 0, 0, 32, 32 );
		C.EnableStencilTest( false );
	}
}

/*********************************************************************************************
* @name	 Logging / debug
********************************************************************************************* */

/** Log What type of reload the weapon would use given ammo count */
private simulated function name LogTacticalReload()
{
	local KFWeapon KFW;

	KFW = GetOwnerWeapon();

    return KFW.GetReloadAnimName( GetUsingTactialReload(KFW) );
}
/** QA Logging - Report Perk Info */
simulated function LogPerkSkills()
{
	super.LogPerkSkills();

	if( bLogPerk )
	{
/**		`log( "PASSIVE PERKS" );
		`log( "-Weapon Damage Modifier:" @ GetPassiveValue( WeaponDamage, CurrentLevel, WeaponDamage.Rank ) * 100 $"%" );
		`log( "-Cloak Detection Range:" @ GetPassiveValue(CloakedEnemyDetection, CurrentLevel, CloakedEnemyDetection.Rank)/100 @"Meters" );
		`log( "-Health Bar Detection Range:" @ GetPassiveValue(HealthBarDetection, CurrentLevel, HealthBarDetection.Rank) /100 @"Meters" );
		`log( "-ZED Time Extension:" @ GetZedTimeExtension( CurrentLevel ) @"Seconds" );
		`log( "-Health Increase:" @ GetPassiveValue(ExtraHealth, CurrentLevel, ExtraHealth.Rank) $"%" );

	    `log( "Skill Tree" );
	    `log( "-Nightvision Active:" @ HasNightVision() );
	    `log( "-Call Active:" @ IsCallOutActive() );
	    `log( "-Large Mags:" @ PerkSkills[ECommandoLargeMags].bActive );
	    `log( "-Backup:" @ PerkSkills[DECommandoBackup.bActive );
	    `log( "-Single Fire:" @ PerkSkills[ECommandoSingleFire].bActive );
	    `log( "-Tactical Reload:" @ PerkSkills[ECommandoTacticalReload].bActive @ LogTacticalReload() );
	    `log( "-Impact:" @ PerkSkills[ECommandoImpact].bActive );
	    `log( "-Autofire:" @ PerkSkills[ECommandoAutoFireDamage].bActive );
	    `log( "-Rapid Fire:" @ PerkSkills[ECommandoRapidFireDamage].bActive );
	    `log( "-Professional:" @ PerkSkills[ECommandoProfessional].bActive );*/
	}
}

/*********************************************************************************************
* @name	 Classic Perk
******************************************************************************************** */

function AddDefaultInventory( KFPawn P )
{
    Super.AddDefaultInventory(P);
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
        OnHUDIcons[i].PerkIcon = Texture2D(RepInfo.ReferencedObjects[62]);
        OnHUDIcons[i].StarIcon = Texture2D(RepInfo.ReferencedObjects[28]);
    }
}

DefaultProperties
{
    bCanSeeCloakedZeds=true

    PrimaryWeaponDef=class'KFWeapDef_AR15'
    SecondaryWeaponDef=class'KFWeapDef_9mm'
    KnifeWeaponDef=class'KFweapDef_Knife_Commando'
    GrenadeWeaponDef=class'KFWeapDef_Grenade_Commando'

    RapidFireFiringRate=0.5f
   	BackupWeaponSwitchModifier=0.5
   	HealthArmorModifier=0.25

   	ZedTimeModifyingStates(0)="WeaponFiring"
   	ZedTimeModifyingStates(1)="WeaponBurstFiring"
   	ZedTimeModifyingStates(2)="WeaponSingleFiring"

	SecondaryXPModifier(0)=3
	SecondaryXPModifier(1)=5
	SecondaryXPModifier(2)=6
	SecondaryXPModifier(3)=9

	WhiteMaterial=Texture2D'EngineResources.WhiteSquareTexture'

	WeaponDamage=(Name="Weapon Damage",Increment=0.01,Rank=1,StartingValue=0.0f,MaxValue=0.25)
	CloakedEnemyDetection=(Name="Cloaked Enemy Detection Range",Increment=200.f,Rank=1,StartingValue=1000.f,MaxValue=6000.f)
	ZedTimeExtension=(Name="Zed Time Extension",Increment=1.f,Rank=2,StartingValue=1.f,MaxValue=6.f)
	ReloadSpeed=(Name="Reload Speed",Increment=0.02,Rank=5,StartingValue=0.0f,MaxValue=0.10)
	CallOut=(Name="Call Out",Increment=2.f,Rank=0,StartingValue=1.f,MaxValue=50.f)
	NightVision=(Name="Night Vision",Increment=0.f,Rank=0,StartingValue=0.f,MaxValue=0.f)
	Recoil=(Name="Recoil",Increment=0.02f,Rank=1,StartingValue=0.0f,MaxValue=0.5f)

	PerkSkills(ECommandoTacticalReload)=(Name="TacticalReload",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_TacticalReload",Increment=0.f,Rank=0,StartingValue=0.f,MaxValue=0.f)
	PerkSkills(ECommandoLargeMags)=(Name="LargeMags",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_LargeMag",Increment=0.f,Rank=0,StartingValue=0.5f,MaxValue=0.5f)
	PerkSkills(ECommandoBackup)=(Name="Backup",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_Backup",Increment=0.f,Rank=0,StartingValue=0.85f,MaxValue=0.85f)  //1.1
	PerkSkills(ECommandoImpact)=(Name="Impact",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_Impact",Increment=0.f,Rank=0,StartingValue=1.5,MaxValue=1.5)
	PerkSkills(ECommandoHealthIncrease)=(Name="HealthIncrease",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_HP",Increment=0.f,Rank=0,StartingValue=0.25,MaxValue=0.25)
	PerkSkills(ECommandoAmmoVest)=(Name="AmmoVest",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_AmmoVest",Increment=0.f,Rank=0,StartingValue=0.2f,MaxValue=0.2f)
	PerkSkills(ECommandoHollowPoints)=(Name="HollowPoints",IconPath="UI_PerkTalent_TEX.Commando.UI_Talents_Commando_SingleFire",Increment=0.f,Rank=0,StartingValue=0.3f,MaxValue=0.3f)
	PerkSkills(ECommandoEatLead)=(Name="EatLead",IconPath="UI_PerkTalent_TEX.Commando.UI_Talents_Commando_AutoFire",Increment=0.f,Rank=0,StartingValue=1.0f,MaxValue=1.0f) //0.5
	PerkSkills(ECommandoProfessional)=(Name="Professional",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_Professional")
	PerkSkills(ECommandoRapidFire)=(Name="RapidFire",IconPath="UI_PerkTalent_TEX.commando.UI_Talents_Commando_RapidFire",Increment=0.f,Rank=0,StartingValue=0.03,MaxValue=0.03)

    // Skill tracking
	HitAccuracyHandicap=0.0
	HeadshotAccuracyHandicap=-3.0
	AutoBuyLoadOutPath=(class'KFWeapDef_AR15', class'KFWeapDef_Bullpup', class'KFWeapDef_AK12', class'KFWeapDef_SCAR', class'KFWeapDef_MedicRifleGrenadeLauncher')

	// Classic Perk
	BasePerk=class'KFPerk_Commando'
	EXPActions(0)="Dealing Commando weapon damage"
    EXPActions(1)="Killing Stalkers with Commando weapons"
    PassiveInfos(0)=(Title="Cloaked Enemy Detection Range")
    PassiveInfos(1)=(Title="Weapon Damage")
    PassiveInfos(2)=(Title="Reload Speed")
    PassiveInfos(3)=(Title="Weapon Recoil")
    PassiveInfos(4)=(Title="Mag Capacity")
    PassiveInfos(5)=(Title="Spare Ammo")
}
