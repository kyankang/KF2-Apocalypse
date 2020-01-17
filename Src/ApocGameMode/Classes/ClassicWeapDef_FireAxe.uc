class ClassicWeapDef_FireAxe extends KFWeapDef_FireAxe;

static function string GetItemLocalization( string KeyName )
{
    return class'KFWeapDef_FireAxe'.Static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_Edged_FireAxe"
    
    BuyPrice=1000
}
