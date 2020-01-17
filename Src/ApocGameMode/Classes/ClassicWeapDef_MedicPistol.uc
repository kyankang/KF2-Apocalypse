class ClassicWeapDef_MedicPistol extends KFWeapDef_MedicPistol;

static function string GetItemLocalization(string KeyName)
{
    return class'KFWeapDef_MedicPistol'.static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_Pistol_Medic"
}
