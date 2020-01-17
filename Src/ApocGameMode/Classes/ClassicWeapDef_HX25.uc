class ClassicWeapDef_HX25 extends KFWeapDef_HX25;

static function string GetItemLocalization(string KeyName)
{
    return class'KFWeapDef_HX25'.static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_GrenadeLauncher_HX25"
}
