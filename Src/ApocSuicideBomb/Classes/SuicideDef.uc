class SuicideDef extends KFWeaponDefinition
	abstract;

static function string GetItemLocalization(string KeyName)
{
	switch( Caps(KeyName) )
	{
	case "ITEMCATEGORY":
		return Class'KFWeapDef_C4'.Static.GetItemLocalization(KeyName);
	case "ITEMDESCRIPTION":
		return "- Any fire mode detonates the explosive.\n- Taking lethal damage will make you auto-detonate the explosive before you die.";
	default:
		return "Suicide Bomb";
	}
}

defaultproperties
{
   WeaponClassPath="ApocSuicideBomb.KFWeap_SuicideBomb"
   ImagePath="WEP_UI_C4_TEX.UI_WeaponSelect_C4"
   BuyPrice=3000
   EffectiveRange=200
   Name="Default__SuicideDef"
   ObjectArchetype=KFWeaponDefinition'KFGame.Default__KFWeaponDefinition'
}
