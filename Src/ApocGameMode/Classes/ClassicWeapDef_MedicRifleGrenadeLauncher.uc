class ClassicWeapDef_MedicRifleGrenadeLauncher extends KFWeapDef_MedicRifleGrenadeLauncher;

static function string GetItemLocalization( string KeyName )
{
    switch( Caps(KeyName) )
    {
    case "ITEMNAME":
        return "M7A3 Medic Gun";
    }
    
    return class'KFWeapDef_MedicRifleGrenadeLauncher'.Static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_AssaultRifle_M7A3"
    BuyPrice=2050
    AmmoPricePerMag=15
}
