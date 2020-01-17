class ClassicWeapDef_MedicSMG extends KFWeapDef_MedicSMG;

static function string GetItemLocalization(string KeyName)
{
    return class'KFWeapDef_MedicSMG'.static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_SMG_Medic"
}
