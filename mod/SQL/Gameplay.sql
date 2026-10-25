-- civ5-refined v5. Target: unmodified Brave New World.
-- Make room for Networks; preserve all existing technology Types.
UPDATE Technologies SET GridX = GridX + 1 WHERE GridX >= 15;
UPDATE Technologies SET GridX = 19 WHERE Type = 'TECH_FUTURE_TECH';

INSERT INTO Technologies
 (Type, Cost, Description, Civilopedia, Help, Quote, Era, GridX, GridY,
  PortraitIndex, IconAtlas, Trade)
VALUES
 ('TECH_REFINED_NETWORKS', 7000, 'TXT_KEY_REFINED_NETWORKS',
  'TXT_KEY_REFINED_NETWORKS_PEDIA', 'TXT_KEY_REFINED_NETWORKS_HELP',
  'TXT_KEY_REFINED_NETWORKS_QUOTE', 'ERA_POSTMODERN', 15, 2, 0, 'EXPANSION2_TECH_ATLAS', 1),
 ('TECH_REFINED_AI', 9500, 'TXT_KEY_REFINED_AI',
  'TXT_KEY_REFINED_AI_PEDIA', 'TXT_KEY_REFINED_AI_HELP',
  'TXT_KEY_REFINED_AI_QUOTE', 'ERA_FUTURE', 18, 2, 5, 'TECH_ATLAS_2', 1);
UPDATE Technologies SET
 IconAtlas = (SELECT IconAtlas FROM Technologies WHERE Type = 'TECH_INTERNET'),
 PortraitIndex = (SELECT PortraitIndex FROM Technologies WHERE Type = 'TECH_INTERNET')
 WHERE Type = 'TECH_REFINED_NETWORKS';
UPDATE Technologies SET
 IconAtlas = (SELECT IconAtlas FROM Technologies WHERE Type = 'TECH_ROBOTICS'),
 PortraitIndex = (SELECT PortraitIndex FROM Technologies WHERE Type = 'TECH_ROBOTICS')
 WHERE Type = 'TECH_REFINED_AI';

DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_COMPUTERS' AND PrereqTech = 'TECH_COMBINED_ARMS';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 SELECT 'TECH_COMPUTERS', 'TECH_ELECTRONICS'
 WHERE NOT EXISTS (SELECT 1 FROM Technology_PrereqTechs
  WHERE TechType = 'TECH_COMPUTERS' AND PrereqTech = 'TECH_ELECTRONICS');
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
 ('TECH_REFINED_NETWORKS', 'TECH_COMPUTERS'),
 ('TECH_INTERNET', 'TECH_REFINED_NETWORKS'),
 ('TECH_REFINED_AI', 'TECH_INTERNET'),
 ('TECH_REFINED_AI', 'TECH_ROBOTICS'),
 ('TECH_FUTURE_TECH', 'TECH_REFINED_AI');

INSERT INTO Technology_Flavors (TechType, FlavorType, Flavor) VALUES
 ('TECH_REFINED_NETWORKS', 'FLAVOR_GOLD', 15),
 ('TECH_REFINED_NETWORKS', 'FLAVOR_SCIENCE', 8),
 ('TECH_REFINED_AI', 'FLAVOR_SCIENCE', 20),
 ('TECH_REFINED_AI', 'FLAVOR_PRODUCTION', 15);

INSERT INTO BuildingClasses (Type, DefaultBuilding, Description) VALUES
 ('BUILDINGCLASS_REFINED_DATA_CENTER', 'BUILDING_REFINED_DATA_CENTER', 'TXT_KEY_REFINED_DATA_CENTER');
INSERT INTO Buildings
 (Type, BuildingClass, Cost, GoldMaintenance, PrereqTech, Description,
  Civilopedia, Help, Strategy, ArtDefineTag, MinAreaSize, HurryCostModifier,
  ConquestProb, PortraitIndex, IconAtlas)
VALUES
 ('BUILDING_REFINED_DATA_CENTER', 'BUILDINGCLASS_REFINED_DATA_CENTER',
  500, 4, 'TECH_COMPUTERS', 'TXT_KEY_REFINED_DATA_CENTER',
  'TXT_KEY_REFINED_DATA_CENTER_PEDIA', 'TXT_KEY_REFINED_DATA_CENTER_HELP',
  'TXT_KEY_REFINED_DATA_CENTER_STRATEGY', 'RESEARCH_LAB', -1, 25, 66, 0, 'BW_ATLAS_1');
UPDATE Buildings SET
 ArtDefineTag = (SELECT ArtDefineTag FROM Buildings WHERE Type = 'BUILDING_LABORATORY'),
 PortraitIndex = (SELECT PortraitIndex FROM Buildings WHERE Type = 'BUILDING_LABORATORY'),
 IconAtlas = (SELECT IconAtlas FROM Buildings WHERE Type = 'BUILDING_LABORATORY')
 WHERE Type = 'BUILDING_REFINED_DATA_CENTER';
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield)
 VALUES ('BUILDING_REFINED_DATA_CENTER', 'YIELD_SCIENCE', 25);
INSERT INTO Building_Flavors (BuildingType, FlavorType, Flavor) VALUES
 ('BUILDING_REFINED_DATA_CENTER', 'FLAVOR_SCIENCE', 50);

-- Hidden, unbuildable effect carriers. Lua grants exactly zero or one of each.
CREATE TABLE Refined_EffectBuildings (Type TEXT PRIMARY KEY);
INSERT INTO Refined_EffectBuildings VALUES
 ('BUILDING_REFINED_COMPUTER_UNIVERSITY'),
 ('BUILDING_REFINED_COMPUTER_LAB'),
 ('BUILDING_REFINED_NETWORK_GOLD'),
 ('BUILDING_REFINED_AI_DATA_CENTER'),
 ('BUILDING_REFINED_AI_FACTORY'),
 ('BUILDING_REFINED_AI_LAB');
INSERT INTO BuildingClasses (Type, DefaultBuilding, Description)
 SELECT 'BUILDINGCLASS_' || substr(Type, 10), Type, 'TXT_KEY_REFINED_HIDDEN'
 FROM Refined_EffectBuildings;
INSERT INTO Buildings
 (Type, BuildingClass, Description, Cost, FaithCost, GreatWorkCount,
  NeverCapture, NukeImmune, ConquestProb, MinAreaSize, HurryCostModifier,
  ArtDefineTag, PortraitIndex, IconAtlas)
 SELECT Type, 'BUILDINGCLASS_' || substr(Type, 10), 'TXT_KEY_REFINED_HIDDEN',
  -1, -1, -1, 1, 1, 0, -1, -1, 'NONE', 0, 'BW_ATLAS_1'
 FROM Refined_EffectBuildings;
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES
 ('BUILDING_REFINED_COMPUTER_UNIVERSITY', 'YIELD_SCIENCE', 2),
 ('BUILDING_REFINED_COMPUTER_LAB', 'YIELD_SCIENCE', 3),
 ('BUILDING_REFINED_AI_LAB', 'YIELD_SCIENCE', 3);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES
 ('BUILDING_REFINED_AI_DATA_CENTER', 'YIELD_SCIENCE', 15),
 ('BUILDING_REFINED_AI_FACTORY', 'YIELD_PRODUCTION', 10),
 ('BUILDING_REFINED_NETWORK_GOLD', 'YIELD_GOLD', 10);

-- Extend stock help rather than replace the original descriptions.
UPDATE Language_en_US SET Text = Text || '[NEWLINE][NEWLINE]' ||
 'Refined: +2 Science in cities with a University and +3 with a Research Lab. Unlocks the Data Center.'
 WHERE Tag = (SELECT Help FROM Technologies WHERE Type = 'TECH_COMPUTERS');
UPDATE Language_RU_RU SET Text = Text || '[NEWLINE][NEWLINE]' ||
 'Refined: +2 науки в городах с университетом и +3 с исследовательской лабораторией. Открывает дата-центр.'
 WHERE Tag = (SELECT Help FROM Technologies WHERE Type = 'TECH_COMPUTERS');
