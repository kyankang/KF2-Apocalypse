class ClassicWeapDef_ElephantGun extends KFWeapDef_ElephantGun;

static function string GetItemLocalization( string KeyName )
{
    return class'KFWeapDef_ElephantGun'.Static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_Shotgun_ElephantGun"
    BuyPrice=2500
    AmmoPricePerMag=30
    EffectiveRange=25
}
