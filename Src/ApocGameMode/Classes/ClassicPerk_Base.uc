class ClassicPerk_Base extends KFPerk;

struct PassiveInfo
{
    var string Title;
    var string Description;
    var string IconPath;
};
var array<PassiveInfo> PassiveInfos;

struct PerkIconData
{
    var Texture2D PerkIcon;
    var Texture2D StarIcon;
    var Color DrawColor;
};
var array<PerkIconData> OnHUDIcons;

var const PerkSkill WeaponDamage;
var const PerkSkill WeaponDiscount;

var class<KFPerk> BasePerk;
var array<string> EXPActions;
var string CustomLevelInfo, CustomPerkName;
var transient float NextAuthTime;
var ClassicPerkManager PerkManager;
var bool bClientAuthorized, bPerkNetReady;
var SoundCue PerkAchieved;
var string PerkAchievedName;

`if(`notdefined(APOC_REMOVED))
var AkEvent RhythmMethodSoundReset;
var AkEvent RhythmMethodSoundHit;
var AkEvent RhythmMethodSoundTop;
var name RhytmMethodRTPCName;
var bool bEnableRackEmUp;

var int HeadShotComboCount;
var int HeadShotComboCountDisplay;
var float HeadShotCountdownInterval;
var int MaxHeadShotComboCount;
var int HeadShotDamageIncrements;
`endif

var int FirstLevelExp, // How much EXP needed for first level.
        LevelUpExpCost, // How much EXP needed for every level up.
        LevelUpIncCost, // How much EXP increase needed for each level up.
        MinimumLevel,
        MaximumLevel,
        CurrentVetLevel;

var int CurrentEXP, // Current amount of EXP user has.
        NextLevelEXP, // Experience needed for next level.
        LastLevelEXP; // Number of XP was needed for last level.

`if(`isdefined(APOC_PATCH))
struct ApocPassiveLocalize
{
    var array<string> Title;
    var array<string> Description;
};

var const string ApocItemPrefix;
`endif

replication
{
    // Things the server should send to the client.
    if ( true )
        CurrentEXP,NextLevelEXP,LastLevelEXP,MinimumLevel,MaximumLevel,FirstLevelExp,LevelUpExpCost,LevelUpIncCost,CurrentVetLevel;
}

simulated function PostBeginPlay()
{
    Super.PostBeginPlay();

    if( WorldInfo.NetMode==NM_Client )
    {
        SetTimer(0.01,false,'InitPerk');
    }

    `TimerHelper.SetTimer(0.1, true, 'GetRepLink', self);
    PerkAchieved = SoundCue(DynamicLoadObject(PerkAchievedName, class'SoundCue'));
}

simulated function GetRepLink()
{
    local ClassicPerk_Base Perk;
    local ClientPerkRepLink RepLink;

    RepLink = class'ClientPerkRepLink'.static.FindContentRep(WorldInfo);
    if( RepLink != None )
    {
        GetPerkIcons(RepLink.ObjRef);

        Perk = ClassicPerk_Base(FindObject(Class.GetPackageName()$".Default__"$Class.Name,Class));
        Perk.OnHUDIcons = OnHUDIcons;

        `TimerHelper.ClearTimer('GetRepLink', self);
    }
}

simulated function InitPerk()
{
    if( OwnerPC==None )
        OwnerPC = KFPlayerController(GetALocalPlayerController());
}

simulated function byte GetLevel()
{
    return CurrentVetLevel;
}

`if(`isdefined(APOC_PATCH))
simulated function ApocPerkSkillUnlock( byte NewLevel )
{
    local int SkillIndex;

    SkillIndex = NewLevel - 1;

    if( 0<=SkillIndex && SkillIndex<PerkSkills.Length )
        PerkSkills[SkillIndex].bActive = true;
}

simulated function SetLevel( byte NewLevel )
{
    ApocPerkSkillUnlock(NewLevel);

    CurrentVetLevel = NewLevel;
}
`else // `if(`isdefined(APOC_PATCH))
simulated function SetLevel( byte NewLevel )
{
    CurrentVetLevel = NewLevel;
}
`endif // `if(`isdefined(APOC_PATCH))

function bool EarnedEXP( int EXP )
{
    local int Index;
    local KFGameEngine Engine;

    Engine = KFGameEngine(class'Engine'.static.GetEngine());

    bForceNetUpdate = true;
    CurrentEXP+=EXP;

    if( CurrentEXP >= NextLevelEXP && CurrentVetLevel < MaximumLevel )
    {
        LastLevelEXP = NextLevelEXP;
        NextLevelEXP = GetNeededExp(CurrentVetLevel + 1);

        SetLevel(CurrentVetLevel + 1);

        ClassicPlayerReplicationInfo(MyPRI).CurrentPerkLevel = CurrentVetLevel;

        PerkAchieved.VolumeMultiplier = (Engine.SFxVolumeMultiplier/100.f) * (Engine.MasterVolumeMultiplier/100.f);
        OwnerPC.ClientPlaySound(PerkAchieved);

        Index = OwnerPC.GetPerkIndexFromClass(Class);
        ClassicPlayerController(OwnerPC).SetPerkStaticLevel(Index, CurrentVetLevel);
        OwnerPC.PerkList[Index].PerkLevel = CurrentVetLevel;

        WorldInfo.Game.BroadcastLocalizedMessage(class'KFLevelUpNotification', CurrentVetLevel, MyPRI,,Class);

        PostLevelUp();
    }

    return true;
}

simulated final function float GetProgressPercent()
{
    return FClamp(float(CurrentEXP-LastLevelEXP) / FMax(float(NextLevelEXP-LastLevelEXP),1.f),0.f,1.f);
}

final function bool HasAnyProgress()
{
    return CurrentEXP>0;
}

function ApplySkillsToPawn()
{
    local KFInventoryManager KFIM;

    if( CheckOwnerPawn() && OwnerPawn.InvManager != none )
    {
        KFIM = KFInventoryManager(OwnerPawn.InvManager);
        if( KFIM.GrenadeCount > MaxGrenadeCount )
        {
            KFIM.GrenadeCount = MaxGrenadeCount;
        }
    }

    Super.ApplySkillsToPawn();
}

simulated function PostPerkUpdate(Pawn P)
{
    PostSkillUpdate();
    ApplySkillsToPawn();
}

// Data saving.
function SaveData( KFSaveDataBase Data )
{
    // Write current EXP.
    Data.SaveInt(CurrentEXP,2);
}

// Data loading.
function LoadData( KFSaveDataBase Data )
{
    CurrentEXP = Data.ReadInt(2);
}

final function int CalcLevelForExp( int InExp )
{
    local int i,a,b;

    // Fast method to calc level for a player.
`if(`isdefined(APOC_PATCH))
    b = MaximumLevel;
`else
    b = MaximumLevel+1;
`endif
    a = Min(MinimumLevel,b);
    while( true )
    {
        if( a==b || (a+1)==b )
        {
            if( a<MaximumLevel && InExp>=GetNeededExp(a) )
                ++a;
            break;
        }
        i = a+((b-a)>>1);
        if( InExp<GetNeededExp(i) ) // Lower!
            b = i;
        else a = i; // Higher!
    }
    return Clamp(a,MinimumLevel,MaximumLevel);
}

// Initialize perk after stats have been loaded.
function SetInitialLevel()
{
    // Set to initial level player is on after configures has loaded.
    SetLevel(CalcLevelForExp(CurrentEXP));
    NextLevelEXP = GetNeededExp(CurrentVetLevel);
    LastLevelEXP = (CurrentVetLevel>MinimumLevel ? GetNeededExp(CurrentVetLevel-1) : 0);
}

function int GetNeededExp( int LevelNum )
{
    if( LevelNum<MinimumLevel || LevelNum>=MaximumLevel )
        return 0;

    LevelNum -= MinimumLevel;
    LevelNum = ( FirstLevelExp + (LevelNum*LevelUpExpCost) + ((LevelNum^2)*LevelUpIncCost) );

    return LevelNum;
}

simulated function bool HasNightVision()
{
    return false;
}

simulated function string GetPrimaryWeaponClassPath()
{
    local class<KFWeaponDefinition> Def;

    Def = GetWeaponDef(CurrentVetLevel);
    if( Def != None )
        return Def.default.WeaponClassPath;

    return "";
}

simulated static function class<KFWeaponDefinition> GetWeaponDef(int Level)
{
    return default.PrimaryWeaponDef;
}

simulated static function class<KFWeaponDefinition> GetSecondaryDef(int Level)
{
    return default.SecondaryWeaponDef;
}

simulated static function class<KFWeaponDefinition> GetKnifeDef(int Level)
{
    return default.KnifeWeaponDef;
}

simulated static function class<KFWeaponDefinition> GetGrenadeDef(int Level)
{
    return default.GrenadeWeaponDef;
}

simulated static function array<PassiveInfo> GetPerkInfoStrings(int Level)
{
    return default.PassiveInfos;
}

static simulated function bool IsWeaponOnPerk(KFWeapon W, optional array < class<KFPerk> > WeaponPerkClass, optional class<KFPerk> InstigatorPerkClass, optional name WeaponClassName)
{
    if( default.BasePerk == None )
    {
        return Super.IsWeaponOnPerk(W, WeaponPerkClass, InstigatorPerkClass, WeaponClassName);
    }

    if( W != None )
    {
        return W.static.AllowedForAllPerks() || W.static.GetWeaponPerkClass( InstigatorPerkClass ) == default.BasePerk;
    }
    else if( WeaponPerkClass.length > 0 )
    {
        return WeaponPerkClass.Find(default.BasePerk) != INDEX_NONE;
    }

    return false;
}

static function bool IsDamageTypeOnPerk(class<KFDamageType> KFDT)
{
    if( default.BasePerk == none )
    {
        return Super.IsDamageTypeOnPerk(KFDT);
    }

    if( KFDT != none )
    {
        return KFDT.default.ModifierPerkList.Find(default.BasePerk) > INDEX_NONE;
    }

    return false;
}

static function bool IsBackupDamageTypeOnPerk(class<DamageType> DT)
{
    if( default.BasePerk == none )
    {
        return Super.IsBackupDamageTypeOnPerk(DT);
    }

    if( DT != none )
    {
        return default.BasePerk.default.BackupWeaponDamageTypeNames.Find(DT.Name) > INDEX_NONE;
    }

    return false;
}

`if(`notdefined(APOC_REMOVED))
simulated function ModifyDamageGiven( out int InDamage, optional Actor DamageCauser, optional KFPawn_Monster MyKFPM, optional KFPlayerController DamageInstigator, optional class<KFDamageType> DamageType, optional int HitZoneIdx )
{
    local KFWeapon MyKFWeapon;
    local float TempDamage;

    TempDamage = InDamage;

    if( DamageCauser != None )
    {
        if( DamageCauser.IsA('Weapon') )
        {
            MyKFWeapon = KFWeapon(DamageCauser);
        }
        else if( DamageCauser.IsA('Projectile') )
        {
            MyKFWeapon = KFWeapon(DamageCauser.Owner);
        }

        if( (MyKFWeapon != none && IsWeaponOnPerk(MyKFWeapon,, self.Class)) || IsDamageTypeOnPerk(DamageType) )
        {
            TempDamage += InDamage * GetPassiveValue(WeaponDamage, CurrentVetLevel);
        }
    }

    if( GetIsHeadShotComboActive() && HeadShotComboCount > 0 )
    {
        TempDamage += Indamage * HeadShotDamageIncrements * HeadShotComboCount;
    }

    InDamage = Round(TempDamage);
}
`endif // `if(`notdefined(APOC_REMOVED))

simulated function float GetCostScaling(byte Level, optional STraderItem TraderItem, optional KFWeapon Weapon)
{
    if( IsWeaponOnPerk( Weapon, TraderItem.AssociatedPerkClasses, self.Class ) )
    {
        return 1.f - GetPassiveValue( WeaponDiscount, Level );
    }

    return 1.f;
}

simulated function string GetGrenadeImagePath()
{
    return GetGrenadeDef(CurrentVetLevel).Static.GetImagePath();
}

simulated function class<KFWeaponDefinition> GetGrenadeWeaponDef()
{
    return GetGrenadeDef(CurrentVetLevel);
}

simulated static function string GetPerkName()
{
    if( default.BasePerk != None && default.BasePerk.default.PerkName != "" )
        return default.BasePerk.default.PerkName;

    if( default.CustomPerkName != "" )
        return default.CustomPerkName;

    return default.PerkName;
}

simulated static function byte GetPerkIconIndex( out byte Level )
{
    local byte MaxStars, Index;

    MaxStars = class'KFHUDInterface'.default.MaxPerkStars;
    Index = Min((Level-1)/MaxStars, default.OnHUDIcons.Length - 1);
    Level -= Index*MaxStars;

    return Index;
}

simulated static function Texture2D GetCurrentPerkIcon( byte Level )
{
    local Texture2D Icon;

    Icon = default.OnHUDIcons[GetPerkIconIndex(Level)].PerkIcon;
    if( Icon == None )
        return class'KFHUDBase'.default.GenericHumanIconTexture;

    return Icon;
}

simulated static function Texture2D GetCurrentPerkStarIcon( byte Level )
{
    local Texture2D Icon;

    Icon = default.OnHUDIcons[GetPerkIconIndex(Level)].StarIcon;
    if( Icon == None )
        return class'KFHUDBase'.default.GenericHumanIconTexture;

    return Icon;
}

`if(`isdefined(APOC_PATCH))
static function int ColorAdjust(float ColorValue, float Factor)
{
    local float Gamma, IntensityMax;
    local int Result;

    Gamma = 0.80f;
    IntensityMax = 255.f;

    if (ColorValue == 0.f)
        Result = 0; // Don't want 0^x = 1 for x < > 0
    else
        Result = Round(IntensityMax  * (ColorValue * Factor)^Gamma);

    return Result;
}

// WaveLength[700~380]
static function Color WavelengthToColor(int Wavelength)
{
    local float Red, Green, Blue, Factor;
    local Color ResultColor;

    if (380 <= Wavelength && Wavelength <= 439)
    {
        Red = -float(Wavelength - 440) / float(440 - 380);
        Green = 0.0f;
        Blue = 1.0f;
    }
    else if (440 <= Wavelength && Wavelength <= 489)
    {
        Red = 0.0f;
        Green = float(Wavelength - 440) / float(490 - 440);
        Blue = 1.0f;
    }
    else if (490 <= Wavelength && Wavelength <= 509)
    {
        Red = 0.0f;
        Green = 1.0f;
        Blue = -float(Wavelength - 510) / float(510 - 490);
    }
    else if (510 <= Wavelength && Wavelength <= 579)
    {
        Red = float(Wavelength - 510) / float(580 - 510);
        Green = 1.0;
        Blue = 0.0;
    }
    else if (580 <= Wavelength && Wavelength <= 644)
    {
        Red = 1.0f;
        Green = -float(Wavelength - 645) / float(645 - 580);
        Blue = 0.0f;
    }
    else if (645 <= Wavelength && Wavelength <= 780)
    {
        Red = 1.0f;
        Green = 0.0f;
        Blue = 0.0f;
    }
    else
    {
        Red = 0.0;
        Green = 0.0;
        Blue = 0.0;
    }

    // Let the intensity fall off near the vision limits
    if (380 <= Wavelength && Wavelength <= 419)
    {
        Factor = 0.3f + 0.7f * float(Wavelength - 380) / float(420 - 380);
    }
    else if (420 <= Wavelength && Wavelength <= 700)
    {
        Factor = 1.0f;
    }
    else if (701 <= Wavelength && Wavelength <= 780)
    {
        Factor = 0.3f + 0.7f * float(780 - Wavelength) / float(780 - 700);
    }
    else
    {
        Factor = 0.0f;
    }

    ResultColor.R = ColorAdjust(Red, Factor);
    ResultColor.G = ColorAdjust(Green, Factor);
    ResultColor.B = ColorAdjust(Blue, Factor);
    ResultColor.A = 255;

    return ResultColor;
}

simulated static function Color GetPerkColor( byte Level )
{
    local float LevelPct;
    local float Wavelength;

    LevelPct = Level / `APOC_MAX_PERK_LEVEL;
    Wavelength = Lerp(650, 460, LevelPct);
    return WavelengthToColor(Wavelength);
}

simulated static function byte PreDrawPerk( Canvas C, byte Level, out Texture2D Icon, out Texture2D StarIcon )
{
    local byte Index;

    Index = GetPerkIconIndex(Level);

    Icon = default.OnHUDIcons[Index].PerkIcon;
    if( Icon == None )
        Icon = class'KFHUDBase'.default.GenericHumanIconTexture;

    StarIcon = default.OnHUDIcons[Index].StarIcon;
    if( StarIcon == None )
        StarIcon = class'KFHUDBase'.default.GenericHumanIconTexture;

    C.DrawColor = GetPerkColor(Level);

    return Level;
}

simulated function string GetCustomLevelInfo( byte Level )
{
    local string S;
	local bool bCurrentVetLevel;

	bCurrentVetLevel = (CurrentVetLevel == Level);

	if (bCurrentVetLevel)
	{
		S = ApocGetCurrentRankString();
		S = S $ ApocGetBasicLoadoutString(BasePerk, Level);
		S = S $ ApocGetPassiveSkillSummary(BasePerk, Level);
		S = S $ ApocGetActiveSkillSummary(BasePerk, Level);
	}
	else
	{
		S = ApocGetNextRankString();
		S = S $ ApocGetNextPassiveSkillSummary(BasePerk, Level);
		S = S $ ApocGetNextUnlockActiveSkill(BasePerk, Level);
	}

    return S;
}

`else // `if(`isdefined(APOC_PATCH))

simulated static function Color GetPerkColor( byte Level )
{
    return default.OnHUDIcons[GetPerkIconIndex(Level)].DrawColor;
}

simulated static function byte PreDrawPerk( Canvas C, byte Level, out Texture2D Icon, out Texture2D StarIcon )
{
    local byte Index;

    Index = GetPerkIconIndex(Level);

    Icon = default.OnHUDIcons[Index].PerkIcon;
    if( Icon == None )
        Icon = class'KFHUDBase'.default.GenericHumanIconTexture;

    StarIcon = default.OnHUDIcons[Index].StarIcon;
    if( StarIcon == None )
        StarIcon = class'KFHUDBase'.default.GenericHumanIconTexture;

    C.DrawColor = default.OnHUDIcons[Index].DrawColor;

    return Level;
}

simulated function string GetCustomLevelInfo( byte Level )
{
    return default.CustomLevelInfo;
}
`endif // `if(`isdefined(APOC_PATCH))

static function string GetPercentStr( PerkSkill Skill, byte Level  )
{
    return Round(GetPassiveValue( Skill, Level ) * 100) $ "%";
}

`if(`notdefined(APOC_REMOVED))
simulated event bool GetIsHeadShotComboActive()
{
    return bEnableRackEmUp;
}

function AddToHeadShotCombo( class<KFDamageType> KFDT, KFPawn_Monster KFPM )
{
    if( GetIsHeadShotComboActive() && IsDamageTypeOnPerk(KFDT) )
    {
        ++HeadShotComboCount;
        HeadShotComboCountDisplay++;
        HeadShotComboCount = Min(HeadShotComboCount, MaxHeadShotComboCount);
        HeadShotMessage(HeadShotComboCount, HeadShotComboCountDisplay,, KFPM);
        `TimerHelper.SetTimer(HeadShotCountdownInterval, true, 'SubstractHeadShotCombo', self);
    }
}

function UpdatePerkHeadShots( ImpactInfo Impact, class<DamageType> DamageType, int NumHit )
{
       local int HitZoneIdx;
       local KFPawn_Monster KFPM;

    if( !GetIsHeadShotComboActive() )
        return;

       KFPM = KFPawn_Monster(Impact.HitActor);
       if( KFPM != none && !KFPM.bIsHeadless )
       {
           HitZoneIdx = KFPM.HitZones.Find('ZoneName', Impact.HitInfo.BoneName);
           if( HitZoneIdx == HZI_Head && KFPM != none && KFPM.IsAliveAndWell() )
        {
            AddToHeadShotCombo(class<KFDamageType>(DamageType), KFPM);
        }
    }
}

reliable client function HeadShotMessage( byte HeadShotNum, byte DisplayValue, optional bool bMissed=false, optional KFPawn_Monster KFPM )
{
    local int i;
    local AkEvent TempAkEvent;

    if( OwnerPC == None || OwnerPC.MyGFxHUD == None )
    {
        return;
    }

    i = HeadshotNum;
    OwnerPC.UpdateRhythmCounterWidget(DisplayValue, MaxHeadShotComboCount);

    switch( i )
    {
        case 0:
            TempAkEvent = RhythmMethodSoundReset;
            break;
        case 1:    case 2:    case 3:
        case 4:
            if( !bMissed )
            {
                TempAkEvent = RhythmMethodSoundHit;
            }
            break;
        case 5:
            if( !bMissed )
            {
                TempAkEvent = RhythmMethodSoundTop;
                i = 6;
            }
            break;
    }

    if( TempAkEvent != none )
    {
        OwnerPC.PlayRMEffect(TempAkEvent, RhytmMethodRTPCName, i);
    }
}

function SubstractHeadShotCombo()
{
    if( HeadShotComboCount > 0 )
    {
        --HeadShotComboCount;
        HeadShotComboCountDisplay = HeadShotComboCount;
        HeadShotMessage(HeadShotComboCount, HeadShotComboCountDisplay, true);
    }
    else if( HeadShotComboCount <= 0 )
    {
        `TimerHelper.ClearTimer('SubstractHeadShotCombo', self);
    }
}

reliable server function ServerClearHeadShotsCombo()
{
    HeadShotComboCountDisplay = 0;
    HeadShotComboCount = 0;
    HeadShotMessage(HeadShotComboCount, HeadShotComboCountDisplay);
    `TimerHelper.ClearTimer('SubstractHeadShotCombo', self);
}

function Destroyed()
{
    Super.Destroyed();

    if( Role == Role_Authority )
    {
        ServerClearHeadShotsCombo();
    }
}
`endif // `if(`notdefined(APOC_REMOVED))

simulated function GetPerkIcons(ObjectReferencer RepInfo);

simulated event UpdatePerkBuild( const out byte InSelectedSkills[`MAX_PERK_SKILLS], class<KFPerk> PerkClass);
simulated event PackPerkBuild( out int NewPerkBuild, const out byte SelectedSkillsHolder[`MAX_PERK_SKILLS] );
simulated event PackSkill( out int NewPerkBuild, byte SkillIndex, int SkillFlag1, int SkillFlag2 );
simulated event SetPerkBuild( int NewPerkBuild );
simulated event GetUnpackedSkillsArray( Class<KFPerk> PerkClass, int NewPerkBuild,  out byte SelectedSkillsHolder[`MAX_PERK_SKILLS] );
simulated function UnpackSkill( byte PerkLevel, int NewPerkBuild, byte SkillTier, int SkillFlag1, int SkillFlag2, out byte SelectedSkillsHolder[`MAX_PERK_SKILLS] );

`if(`isdefined(APOC_PATCH))
function string ApocGetCompletedLevelInfo()
{
    local string S;

    S = ApocGetNextRankString();
    S = S $ "|" $ ApocItemPrefix;
    S = S @ Localize("KFGFxWidget_LevelUpNotification", "ObjectiveCompleteString", "KFGame");

    return S;
}

function string ApocGetCurrentRankString()
{
    return Localize("KFGFxPerksContainer_Prestige", "CurrentRankString", "KFGame");
}

function string ApocGetNextRankString()
{
    return "||" $ Localize("KFGFxPerksContainer_Prestige", "NextRankString", "KFGame");
}

function string ApocGetBasicLoadoutString(class<KFPerk> Perk, byte Level)
{
    local string S;
    local class<KFWeaponDefinition> SpawnDef;

    if( Perk!=none )
    {
        SpawnDef = GetWeaponDef(Level);
        if( SpawnDef != None )
        {
            S = "|" $ ApocItemPrefix;
            S = S @ Localize("KFGFxPerksContainer_Details", "BasicLoadoutString", "KFGame") @ ":";
            S = S @ SpawnDef.static.GetItemName();
        }
    }

    return S;
}

function ApocPassiveLocalize ApocGetPassiveSkillLocalize(class<KFPerk> Perk, int Index)
{
    local string S;
    local array<string> SArr;
    local ApocPassiveLocalize Result;

    if( Perk!=none )
    {
        S = Localize(String(Perk.Name), "Passives["$Index$"]", "KFGame");
        if( 0<Len(S) )
        {
            S = Repl( S, "(", "" );
            S = Repl( S, ");", "" );
            S = Repl( S, "\"", "" );
            SArr = SplitString( S, ",");
            Result.Title = SplitString( SArr[0], "=");
            Result.Description = SplitString( SArr[1], "=");
        }
    }

    return Result;
}

function string ApocGetPassiveSkillSummary(class<KFPerk> Perk, byte Level)
{
	local int i;
    local string S;
    local ApocPassiveLocalize PassiveLocalize;
	local array<string> PassiveValues, Increments;

    if( Perk!=none )
    {
        GetPassiveStrings( PassiveValues, Increments, Level);

        for( i=0; i<PassiveValues.length; i++ )
        {
            if( 0<Len(Increments[i]) && 0<Len(PassiveValues[i]) )
            {
                PassiveLocalize = ApocGetPassiveSkillLocalize(Perk, i);
                S = S $ "|" $ ApocItemPrefix;
                S = S @ PassiveLocalize.Title[1];
                S = S @ ":" @ PassiveValues[i];
                S = S @ " " @ Increments[i];
            }
        }
    }

    return S;
}

function string ApocGetNextPassiveSkillSummary(class<KFPerk> Perk, byte Level)
{
	local int i;
    local string S;
    local ApocPassiveLocalize PassiveLocalize;
	local array<string> PassiveValues, Increments;

    if( Perk!=none )
    {
        GetPassiveStrings( PassiveValues, Increments, Level);

        for( i=0; i<PassiveValues.length; i++ )
        {
            if( 0<Len(Increments[i]) && 0<Len(PassiveValues[i]) )
            {
                PassiveLocalize = ApocGetPassiveSkillLocalize(Perk, i);
                S = S $ "|" $ ApocItemPrefix;
                S = S @ PassiveLocalize.Title[1];
                S = S @ ":" @ PassiveValues[i];
                S = S @ " " @ Increments[i];
            }
        }
    }

    return S;
}

function string ApocGetSkillCategory(class<KFPerk> Perk, byte SkillIndex)
{
    local string S;
    local int SkillCategoryIndex;

    if( Perk!=none )
    {
        SkillCategoryIndex = FCeil(SkillIndex / 2);

        if( 0<=SkillCategoryIndex && SkillCategoryIndex<`MAX_PERK_SKILLS )
        {
            S = "[" $ Perk.default.SkillCatagories[SkillCategoryIndex] $ "]";
        }
    }

    return S;
}

function string ApocGetSkillName(class<KFPerk> Perk, byte SkillIndex)
{
    local string S;
	local array<PerkSkill> PerkSkillArr;

    if( Perk!=none )
    {
        if( 0<=SkillIndex && SkillIndex<Perk.default.PerkSkills.Length )
        {
            PerkSkillArr = Perk.default.PerkSkills;
            S = Localize(String(Perk.Name), PerkSkillArr[SkillIndex].Name, "KFGame");
        }
    }

    return S;
}

function string ApocGetSkillDescription(class<KFPerk> Perk, byte SkillIndex)
{
    local string S;
	local array<PerkSkill> PerkSkillArr;

    if( Perk!=none )
    {
        if( 0<=SkillIndex && SkillIndex<Perk.default.PerkSkills.Length )
        {
            PerkSkillArr = Perk.default.PerkSkills;
            S = Localize(String(Perk.Name), PerkSkillArr[SkillIndex].Name$"Description", "KFGame");
        }
    }

    return S;
}

function string ApocGetActiveSkillSummary(class<KFPerk> Perk, byte Level)
{
    local int i;
    local string S;

    if( Perk!=none )
    {
        if( 0<Level && Level<=Perk.default.PerkSkills.Length )
        {
            for( i=0; i<Level; i++ )
            {
                S = S $ "|" $ ApocItemPrefix;
                S = S @ ApocGetSkillCategory(BasePerk, i);
                S = S @ ApocGetSkillName(BasePerk, i) @ ":";
                S = S @ ApocGetSkillDescription(BasePerk, i);
            }
        }
    }

    return S;
}

function string ApocGetNextUnlockActiveSkill(class<KFPerk> Perk, byte Level)
{
    local string S;
    local int SkillIndex;

    if( Perk!=none )
    {
        SkillIndex = Level - 1;
        if( 0<=SkillIndex && SkillIndex<Perk.default.PerkSkills.Length )
        {
            S = "|" $ ApocItemPrefix;
            S = S @ ApocGetSkillCategory(BasePerk, SkillIndex);
            S = S @ ApocGetSkillName(BasePerk, SkillIndex) @ ":";
            S = S @ ApocGetSkillDescription(BasePerk, SkillIndex);
        }
    }

    return S;
}

function string ApocGetExpActionString()
{
    local string S;

    if( BasePerk!=none )
    {
        S = Localize(String(BasePerk.Name), "EXPAction1", "KFGame");
        S = S $ "|" $ Localize(String(BasePerk.Name), "EXPAction2", "KFGame");
    }

    return S;
}
`endif

defaultproperties
{
`if(`isdefined(APOC_PATCH))
    ApocItemPrefix="  *"
`endif

`if(`notdefined(APOC_REMOVED))
    HeadShotDamageIncrements=0.10f
    MaxHeadShotComboCount=5
    HeadShotCountdownInterval=2.f
    RhytmMethodRTPCName="R_Method"
    RhythmMethodSoundReset=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Reset'
    RhythmMethodSoundHit=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Hit'
    RhythmMethodSoundTop=AkEvent'WW_UI_PlayerCharacter.Play_R_Method_Top'
`endif

    FirstLevelExp=7500
    LevelUpExpCost=9375
    LevelUpIncCost=1218

    MinimumLevel=-1
    MaximumLevel=-1

    ProgressStatID=1
    PerkBuildStatID=2

    bInitialized=true

    OnHUDIcons.Add((DrawColor=(R=255,G=15,B=15,A=255)))
    OnHUDIcons.Add((DrawColor=(R=255,G=255,B=0,A=255)))
    OnHUDIcons.Add((DrawColor=(R=0,G=255,B=0,A=255)))
    OnHUDIcons.Add((DrawColor=(R=0,G=125,B=255,A=255)))
    OnHUDIcons.Add((DrawColor=(R=178,G=0,B=255,A=255)))
    OnHUDIcons.Add((DrawColor=(R=255,G=0,B=128,A=255)))
    OnHUDIcons.Add((DrawColor=(R=95,G=0,B=0,A=255)))
    OnHUDIcons.Add((DrawColor=(R=217,G=124,B=32,A=255)))
    OnHUDIcons.Add((DrawColor=(R=4,G=171,B=33,A=255)))
    OnHUDIcons.Add((DrawColor=(R=94,G=22,B=145,A=255)))
    OnHUDIcons.Add((DrawColor=(R=119,G=229,B=231,A=255)))
    OnHUDIcons.Add((DrawColor=(R=239,G=58,B=124,A=255)))
    OnHUDIcons.Add((DrawColor=(R=255,G=140,B=0,A=255)))
    OnHUDIcons.Add((DrawColor=(R=148,G=0,B=211,A=255)))
    OnHUDIcons.Add((DrawColor=(R=240,G=255,B=255,A=255)))

    WeaponDiscount=(Name="Weapon Discount",Increment=0.1f,Rank=0,StartingValue=0.1f,MaxValue=0.9f)

    PerkAchievedName="ApocGameMode_Assets.Perks.PerkAchievedCue"

    SecondaryWeaponDef=class'ClassicWeapDef_9mm'
    GrenadeWeaponDef=class'ClassicWeapDef_Grenade_Support'
}
