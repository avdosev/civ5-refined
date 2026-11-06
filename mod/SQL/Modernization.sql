-- Late culture and military projects use the ordinary project production queue.
CREATE TABLE Refined_ModernizationTechs
 (Type TEXT PRIMARY KEY, Template TEXT, Era TEXT, Cost INTEGER, GridX INTEGER, GridY INTEGER, Ability INTEGER);
INSERT INTO Refined_ModernizationTechs VALUES
 ('TECH_REFINED_ENTERTAINMENT','TECH_RADIO','ERA_MODERN',4100,13,3,0),
 ('TECH_REFINED_DRONES','TECH_RADAR','ERA_FUTURE',7700,17,2,3),
 ('TECH_REFINED_TACTICAL_AI','TECH_REFINED_GENERAL_AI','ERA_FUTURE',10000,21,5,0);
INSERT INTO Technologies
 (Type,Description,Help,Civilopedia,Quote,Era,Cost,GridX,GridY,PortraitIndex,IconAtlas,Trade,ScenarioTechButton)
SELECT n.Type,'TXT_KEY_'||n.Type,'TXT_KEY_'||n.Type||'_HELP','TXT_KEY_'||n.Type||'_PEDIA',
 'TXT_KEY_'||n.Type||'_QUOTE',n.Era,n.Cost,n.GridX,n.GridY,t.PortraitIndex,t.IconAtlas,1,n.Ability
FROM Refined_ModernizationTechs n JOIN Technologies t ON t.Type=n.Template;
INSERT INTO Technology_PrereqTechs (TechType,PrereqTech)
 SELECT Type,Template FROM Refined_ModernizationTechs;
INSERT INTO Technology_PrereqTechs (TechType,PrereqTech)
 VALUES ('TECH_REFINED_DRONES','TECH_REFINED_MICROELECTRONICS');
INSERT INTO Technology_Flavors (TechType,FlavorType,Flavor) VALUES
 ('TECH_REFINED_ENTERTAINMENT','FLAVOR_CULTURE',25),
 ('TECH_REFINED_ENTERTAINMENT','FLAVOR_GREAT_PEOPLE',15),
 ('TECH_REFINED_DRONES','FLAVOR_OFFENSE',25),
 ('TECH_REFINED_DRONES','FLAVOR_DEFENSE',20),
 ('TECH_REFINED_TACTICAL_AI','FLAVOR_OFFENSE',30),
 ('TECH_REFINED_TACTICAL_AI','FLAVOR_DEFENSE',25);
DROP TABLE Refined_ModernizationTechs;

-- Keep both direct drone prerequisites within the native connector geometry.
-- No prerequisite of an existing technology is changed here.
UPDATE Technologies SET GridY=CASE Type
 WHEN 'TECH_RADAR' THEN 2
 WHEN 'TECH_ROCKETRY' THEN 4
 WHEN 'TECH_COMPUTERS' THEN 5
 WHEN 'TECH_TELECOM' THEN 4
 WHEN 'TECH_ADVANCED_BALLISTICS' THEN 3
 WHEN 'TECH_SATELLITES' THEN 6
 WHEN 'TECH_GLOBALIZATION' THEN 8
 WHEN 'TECH_PARTICLE_PHYSICS' THEN 3
 WHEN 'TECH_NANOTECHNOLOGY' THEN 7
 WHEN 'TECH_STEALTH' THEN 6
 WHEN 'TECH_REFINED_MICROELECTRONICS' THEN 6
 WHEN 'TECH_REFINED_AUTONOMOUS' THEN 2 END
WHERE Type IN ('TECH_RADAR','TECH_ROCKETRY','TECH_COMPUTERS','TECH_TELECOM','TECH_ADVANCED_BALLISTICS',
 'TECH_SATELLITES','TECH_GLOBALIZATION','TECH_PARTICLE_PHYSICS','TECH_NANOTECHNOLOGY','TECH_STEALTH',
 'TECH_REFINED_MICROELECTRONICS','TECH_REFINED_AUTONOMOUS');

INSERT INTO BuildingClasses (Type,DefaultBuilding,Description)
VALUES ('BUILDINGCLASS_REFINED_CINEMA','BUILDING_REFINED_CINEMA','TXT_KEY_BUILDING_REFINED_CINEMA');
INSERT INTO Buildings
 (Type,BuildingClass,Description,Help,Strategy,Civilopedia,PrereqTech,Cost,GoldMaintenance,ConquestProb,
  SpecialistType,SpecialistCount,GreatPeopleRateModifier,GreatWorkSlotType,GreatWorkCount,
  ArtDefineTag,MinAreaSize,HurryCostModifier,PortraitIndex,IconAtlas)
SELECT 'BUILDING_REFINED_CINEMA','BUILDINGCLASS_REFINED_CINEMA','TXT_KEY_BUILDING_REFINED_CINEMA',
 'TXT_KEY_BUILDING_REFINED_CINEMA_HELP','TXT_KEY_BUILDING_REFINED_CINEMA_HELP','TXT_KEY_BUILDING_REFINED_CINEMA_PEDIA',
 'TECH_REFINED_ENTERTAINMENT',300,2,66,'SPECIALIST_MUSICIAN',1,20,'GREAT_WORK_SLOT_MUSIC',1,
 ArtDefineTag,MinAreaSize,HurryCostModifier,PortraitIndex,IconAtlas
FROM Buildings WHERE Type='BUILDING_BROADCAST_TOWER';
INSERT INTO Building_YieldChanges (BuildingType,YieldType,Yield)
 VALUES ('BUILDING_REFINED_CINEMA','YIELD_CULTURE',2);
INSERT INTO Building_Flavors (BuildingType,FlavorType,Flavor) VALUES
 ('BUILDING_REFINED_CINEMA','FLAVOR_CULTURE',25),
 ('BUILDING_REFINED_CINEMA','FLAVOR_GREAT_PEOPLE',15);

CREATE TABLE Refined_NationalProjects
 (Type TEXT PRIMARY KEY, Tech TEXT, Cost INTEGER, NeedsDataCenter INTEGER);
INSERT INTO Refined_NationalProjects VALUES
 ('PROJECT_REFINED_DRONE_DEPLOYMENT','TECH_REFINED_DRONES',850,0),
 ('PROJECT_REFINED_AUTONOMOUS_COMMAND','TECH_REFINED_TACTICAL_AI',1250,0),
 ('PROJECT_REFINED_DIGITAL_HERITAGE','TECH_REFINED_NETWORKS',700,0),
 ('PROJECT_REFINED_CULTURAL_EXPANSION','TECH_REFINED_AI',1000,1),
 ('PROJECT_REFINED_MACHINE_CREATIVITY','TECH_REFINED_GENERAL_AI',1100,1);
INSERT INTO Projects
 (Type,Description,Civilopedia,Strategy,Help,TechPrereq,Cost,MaxGlobalInstances,MaxTeamInstances,PortraitIndex,IconAtlas)
SELECT n.Type,'TXT_KEY_'||n.Type,'TXT_KEY_'||n.Type||'_PEDIA','TXT_KEY_'||n.Type||'_HELP',
 'TXT_KEY_'||n.Type||'_HELP',n.Tech,n.Cost,-1,1,t.PortraitIndex,t.IconAtlas
FROM Refined_NationalProjects n JOIN Technologies t ON t.Type=n.Tech;
INSERT INTO Project_Flavors (ProjectType,FlavorType,Flavor) VALUES
 ('PROJECT_REFINED_DRONE_DEPLOYMENT','FLAVOR_OFFENSE',35),
 ('PROJECT_REFINED_DRONE_DEPLOYMENT','FLAVOR_DEFENSE',25),
 ('PROJECT_REFINED_AUTONOMOUS_COMMAND','FLAVOR_OFFENSE',40),
 ('PROJECT_REFINED_AUTONOMOUS_COMMAND','FLAVOR_DEFENSE',30),
 ('PROJECT_REFINED_DIGITAL_HERITAGE','FLAVOR_CULTURE',35),
 ('PROJECT_REFINED_CULTURAL_EXPANSION','FLAVOR_CULTURE',40),
 ('PROJECT_REFINED_MACHINE_CREATIVITY','FLAVOR_CULTURE',40);

INSERT INTO UnitPromotions
 (Type,Description,Help,CombatPercent,LostWithUpgrade,CannotBeChosen,PortraitIndex,IconAtlas,PediaType,PediaEntry)
SELECT p.Type,'TXT_KEY_'||p.Type,'TXT_KEY_'||p.Type||'_HELP',p.Bonus,0,1,
 t.PortraitIndex,t.IconAtlas,t.PediaType,'TXT_KEY_'||p.Type
FROM (
 SELECT 'PROMOTION_REFINED_DRONES' AS Type,5 AS Bonus UNION ALL
 SELECT 'PROMOTION_REFINED_DRONE_DEPLOYMENT',15 UNION ALL
 SELECT 'PROMOTION_REFINED_AUTONOMOUS_COMMAND',15
) p CROSS JOIN UnitPromotions t WHERE t.Type='PROMOTION_REFINED_NETWORK_COMMAND';

-- BNW adds TechEnhancedTourism once per building class, irrespective of building count.
-- Binary weights encode the exact integer bonus with a bounded number of hidden classes.
CREATE TABLE Refined_TourismCarriers (Type TEXT PRIMARY KEY, Weight INTEGER NOT NULL);
CREATE TEMP TABLE Refined_TourismWeights (Weight INTEGER);
INSERT INTO Refined_TourismWeights VALUES
 (1),(2),(4),(8),(16),(32),(64),(128),(256),(512),(1024),(2048),(4096),(8192),(16384),(32768),(65536);
INSERT INTO Refined_TourismCarriers
 SELECT 'BUILDING_REFINED_TOURISM_'||Weight,Weight FROM Refined_TourismWeights;
DROP TABLE Refined_TourismWeights;
INSERT INTO Refined_EffectBuildings VALUES ('BUILDING_REFINED_AUTOMATION_STEEL');
INSERT INTO Refined_EffectBuildings SELECT Type FROM Refined_TourismCarriers;
INSERT INTO BuildingClasses (Type,DefaultBuilding,Description)
 SELECT 'BUILDINGCLASS_'||substr(Type,10),Type,'TXT_KEY_REFINED_HIDDEN'
 FROM Refined_EffectBuildings
 WHERE Type='BUILDING_REFINED_AUTOMATION_STEEL' OR Type IN (SELECT Type FROM Refined_TourismCarriers);
INSERT INTO Buildings
 (Type,BuildingClass,Description,Cost,FaithCost,GreatWorkCount,NeverCapture,NukeImmune,ConquestProb,
  MinAreaSize,HurryCostModifier,ArtDefineTag,PortraitIndex,IconAtlas,EnhancedYieldTech,TechEnhancedTourism)
SELECT b.DefaultBuilding,b.Type,'TXT_KEY_REFINED_HIDDEN',-1,-1,-1,1,1,0,-1,-1,'NONE',0,'BW_ATLAS_1',
 CASE WHEN t.Weight IS NOT NULL THEN 'TECH_COMPUTERS' END,COALESCE(t.Weight,0)
FROM BuildingClasses b LEFT JOIN Refined_TourismCarriers t ON t.Type=b.DefaultBuilding
WHERE t.Type IS NOT NULL OR b.DefaultBuilding='BUILDING_REFINED_AUTOMATION_STEEL';
INSERT INTO Unit_ProductionModifierBuildings (UnitType,BuildingType,ProductionModifier)
SELECT UnitType,'BUILDING_REFINED_AUTOMATION_STEEL',10
FROM Unit_ProductionModifierBuildings WHERE BuildingType='BUILDING_REFINED_STEEL_MILL';

UPDATE Language_en_US SET Text=Text||'[NEWLINE]Drones: +5% combat strength for land units.'
 WHERE Tag='TXT_KEY_SCENARIO_TECH_BUTTON_3';
UPDATE Language_RU_RU SET Text=Text||'[NEWLINE]Беспилотные системы: +5% боевой силы сухопутных частей.'
 WHERE Tag='TXT_KEY_SCENARIO_TECH_BUTTON_3';
