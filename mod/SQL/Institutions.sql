-- v7: preserve Types; Liberty's new prerequisites and transfers approved Oct 30.
UPDATE Policies SET BuildingProductionModifier=0, WorkerSpeedModifier=25,
 IncludesOneShotFreeUnits=1 WHERE Type='POLICY_REPUBLIC';
UPDATE Policy_FreeUnitClasses SET PolicyType='POLICY_REPUBLIC'
WHERE PolicyType='POLICY_CITIZENSHIP' AND UnitClassType='UNITCLASS_WORKER';
UPDATE Policies SET WorkerSpeedModifier=0, IncludesOneShotFreeUnits=0,
 HappinessPerTradeRoute=100, UnhappinessMod=-5 WHERE Type='POLICY_CITIZENSHIP';
UPDATE Policies SET HappinessPerTradeRoute=0, UnhappinessMod=0,
 GridX=3, GridY=3 WHERE Type='POLICY_MERITOCRACY';
UPDATE Policy_PrereqPolicies SET PrereqPolicy='POLICY_REPRESENTATION'
WHERE PolicyType='POLICY_MERITOCRACY' AND PrereqPolicy='POLICY_CITIZENSHIP';
UPDATE Policies SET BuildingProductionModifier=10 WHERE Type='POLICY_LIBERTY_FINISHER';
-- BNW's generic specialist yield excludes DEFAULT_SPECIALIST (unemployed
-- Citizens), unlike building bonuses explicitly targeting SPECIALIST_CITIZEN.
INSERT INTO Policy_SpecialistExtraYields (PolicyType,YieldType,Yield) VALUES
('POLICY_MERITOCRACY','YIELD_SCIENCE',1),
('POLICY_MERITOCRACY','YIELD_PRODUCTION',1);
-- Keep the native AI's content descriptors consistent with transferred effects.
UPDATE Policy_Flavors SET PolicyType='POLICY_REPUBLIC'
WHERE PolicyType='POLICY_CITIZENSHIP' AND FlavorType='FLAVOR_TILE_IMPROVEMENT';
UPDATE Policy_Flavors SET PolicyType='POLICY_CITIZENSHIP'
WHERE PolicyType='POLICY_MERITOCRACY' AND FlavorType='FLAVOR_HAPPINESS';
INSERT INTO Policy_Flavors (PolicyType,FlavorType,Flavor) VALUES
('POLICY_MERITOCRACY','FLAVOR_SCIENCE',15),
('POLICY_MERITOCRACY','FLAVOR_PRODUCTION',10),
('POLICY_LIBERTY_FINISHER','FLAVOR_PRODUCTION',10);

-- Honor: the engine uses max(base Combat, base RangedCombat), integer /100.
-- Subtract the same barbarian component so the opener's barbarian award stays.
UPDATE Policies SET CultureFromKills=25, CultureFromBarbarianKills=-25
WHERE Type='POLICY_HONOR_FINISHER';
UPDATE Policies SET FaithCostModifier=-25 WHERE Type='POLICY_MANDATE_OF_HEAVEN';
UPDATE Policies SET FaithCostModifier=-10 WHERE Type='POLICY_PIETY_FINISHER';
INSERT INTO Policy_GreatWorkYieldChanges (PolicyType,YieldType,Yield)
VALUES ('POLICY_AESTHETICS','YIELD_CULTURE',1);
UPDATE Policy_BuildingClassProductionModifiers SET ProductionModifier=75
WHERE PolicyType='POLICY_CULTURAL_CENTERS';
UPDATE Policies SET CultureWonderMultiplier=0 WHERE Type='POLICY_FLOURISHING_OF_ARTS';
INSERT INTO Policy_BuildingClassYieldChanges (PolicyType,BuildingClassType,YieldType,YieldChange)
VALUES ('POLICY_ARTISTIC_GENIUS','BUILDINGCLASS_MUSEUM','YIELD_CULTURE',2);
UPDATE Policies SET InternalTradeRouteYieldModifier=25 WHERE Type='POLICY_COMMERCE_FINISHER';
UPDATE Policy_BuildingClassYieldChanges SET YieldChange=3
WHERE PolicyType='POLICY_MERCHANT_NAVY' AND BuildingClassType IN ('BUILDINGCLASS_HARBOR','BUILDINGCLASS_SEAPORT') AND YieldType='YIELD_GOLD';
INSERT INTO Policy_BuildingClassYieldChanges (PolicyType,BuildingClassType,YieldType,YieldChange) VALUES
('POLICY_MARITIME_INFRASTRUCTURE','BUILDINGCLASS_SEAPORT','YIELD_PRODUCTION',2),
('POLICY_EXPLORATION_FINISHER','BUILDINGCLASS_MUSEUM','YIELD_CULTURE',1);
UPDATE Policies SET SeaTradeRouteGoldChange=300 WHERE Type='POLICY_TREASURE_FLEETS';

-- Trade missions already grant influence in BNW. This promotion increases it,
-- rather than claiming to introduce the existing mechanic. Lua follows policy
-- ownership, including existing Merchants and the Venetian replacement.
INSERT INTO UnitPromotions
(Type,Description,Help,CannotBeChosen,LostWithUpgrade,PortraitIndex,IconAtlas,TradeMissionInfluenceModifier)
VALUES ('PROMOTION_REFINED_MERCHANT','TXT_KEY_REFINED_MERCHANT','TXT_KEY_REFINED_MERCHANT_HELP',1,1,0,'PROMOTION_ATLAS',50);

-- New mercenaries use stock art. Keep the Freedom Volunteer Army legion intact.
INSERT INTO UnitClasses (Type,Description,DefaultUnit) VALUES
('UNITCLASS_REFINED_SWISS_GUARD','TXT_KEY_REFINED_SWISS','UNIT_REFINED_SWISS_GUARD'),
('UNITCLASS_REFINED_MERCENARY_LEGION','TXT_KEY_REFINED_LEGION','UNIT_REFINED_MERCENARY_LEGION');
CREATE TABLE Refined_Mercenaries (Type TEXT PRIMARY KEY, Template TEXT, Class TEXT, TextKey TEXT, Tech TEXT, Obsolete TEXT, Cost INTEGER, Strength INTEGER);
INSERT INTO Refined_Mercenaries VALUES
('UNIT_REFINED_SWISS_GUARD','UNIT_MUSKETMAN','UNITCLASS_REFINED_SWISS_GUARD','TXT_KEY_REFINED_SWISS','TECH_GUNPOWDER','TECH_REPLACEABLE_PARTS',100,26),
('UNIT_REFINED_MERCENARY_LEGION','UNIT_FRENCH_FOREIGNLEGION','UNITCLASS_REFINED_MERCENARY_LEGION','TXT_KEY_REFINED_LEGION','TECH_REPLACEABLE_PARTS',NULL,180,42);
INSERT INTO Units
(Type,Class,Description,Civilopedia,Strategy,Help,Combat,Cost,FaithCost,PurchaseOnly,MoveAfterPurchase,
 Moves,BaseSightRange,CombatClass,Domain,DefaultUnitAI,MilitarySupport,MilitaryProduction,Pillage,
 IgnoreBuildingDefense,PrereqTech,ObsoleteTech,PolicyType,HurryCostModifier,AdvancedStartCost,
 MinAreaSize,XPValueAttack,XPValueDefense,Conscription,UnitArtInfo,UnitArtInfoCulturalVariation,
 UnitArtInfoEraVariation,MoveRate,UnitFlagIconOffset,PortraitIndex,IconAtlas,UnitFlagAtlas)
SELECT m.Type,m.Class,m.TextKey,m.TextKey || '_PEDIA',m.TextKey || '_HELP',m.TextKey || '_HELP',
 m.Strength,m.Cost,0,1,1,u.Moves,u.BaseSightRange,u.CombatClass,u.Domain,u.DefaultUnitAI,
 u.MilitarySupport,u.MilitaryProduction,u.Pillage,u.IgnoreBuildingDefense,m.Tech,m.Obsolete,
 'POLICY_TRADE_UNIONS',0,u.AdvancedStartCost,u.MinAreaSize,u.XPValueAttack,u.XPValueDefense,
 u.Conscription,u.UnitArtInfo,u.UnitArtInfoCulturalVariation,u.UnitArtInfoEraVariation,u.MoveRate,
 u.UnitFlagIconOffset,u.PortraitIndex,u.IconAtlas,u.UnitFlagAtlas
FROM Refined_Mercenaries m JOIN Units u ON u.Type=m.Template;
INSERT INTO Unit_FreePromotions (UnitType,PromotionType)
SELECT m.Type,p.PromotionType FROM Refined_Mercenaries m JOIN Unit_FreePromotions p ON p.UnitType=m.Template;
INSERT INTO Unit_AITypes (UnitType,UnitAIType)
SELECT m.Type,a.UnitAIType FROM Refined_Mercenaries m JOIN Unit_AITypes a ON a.UnitType=m.Template;
INSERT INTO Unit_Flavors (UnitType,FlavorType,Flavor)
SELECT m.Type,f.FlavorType,f.Flavor FROM Refined_Mercenaries m JOIN Unit_Flavors f ON f.UnitType=m.Template;
UPDATE Units SET ObsoleteTech='TECH_GUNPOWDER' WHERE Type='UNIT_GERMAN_LANDSKNECHT';
DELETE FROM Unit_ClassUpgrades WHERE UnitType='UNIT_GERMAN_LANDSKNECHT';
INSERT INTO Unit_ClassUpgrades (UnitType,UnitClassType) VALUES
('UNIT_GERMAN_LANDSKNECHT','UNITCLASS_REFINED_SWISS_GUARD'),
('UNIT_REFINED_SWISS_GUARD','UNITCLASS_REFINED_MERCENARY_LEGION'),
('UNIT_REFINED_MERCENARY_LEGION','UNITCLASS_INFANTRY');
