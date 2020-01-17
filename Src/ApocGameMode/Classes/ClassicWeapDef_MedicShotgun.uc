class ClassicWeapDef_MedicShotgun extends KFWeapDef_MedicShotgun;

static function string GetItemLocalization(string KeyName)
{
    return class'KFWeapDef_MedicShotgun'.static.GetItemLocalization(KeyName);
}

DefaultProperties
{
    WeaponClassPath="ApocGameMode.ClassicWeap_Shotgun_Medic"

}
