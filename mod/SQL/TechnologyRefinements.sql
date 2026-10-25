-- v4: give computing, communications and industrial automation distinct roles.
INSERT INTO Technologies
 (Type, Cost, Description, Civilopedia, Help, Quote, Era, GridX, GridY,
  PortraitIndex, IconAtlas, Trade)
SELECT 'TECH_REFINED_MICROELECTRONICS', 7000, 'TXT_KEY_REFINED_MICRO',
 'TXT_KEY_REFINED_MICRO_PEDIA', 'TXT_KEY_REFINED_MICRO_HELP',
 'TXT_KEY_REFINED_MICRO_QUOTE', 'ERA_POSTMODERN', 15, 4,
 PortraitIndex, IconAtlas, 1 FROM Technologies WHERE Type = 'TECH_ELECTRONICS';
INSERT INTO Technologies
 (Type, Cost, Description, Civilopedia, Help, Quote, Era, GridX, GridY,
  PortraitIndex, IconAtlas, Trade)
SELECT 'TECH_REFINED_AUTOMATION', 7000, 'TXT_KEY_REFINED_AUTOMATION',
 'TXT_KEY_REFINED_AUTOMATION_PEDIA', 'TXT_KEY_REFINED_AUTOMATION_HELP',
 'TXT_KEY_REFINED_AUTOMATION_QUOTE', 'ERA_POSTMODERN', 15, 6,
 PortraitIndex, IconAtlas, 1 FROM Technologies WHERE Type = 'TECH_INDUSTRIALIZATION';

-- Electronics, rather than military radar research, is the computing foundation.
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 SELECT 'TECH_ELECTRONICS', 'TECH_ELECTRICITY'
 WHERE NOT EXISTS (SELECT 1 FROM Technology_PrereqTechs
  WHERE TechType = 'TECH_ELECTRONICS' AND PrereqTech = 'TECH_ELECTRICITY');
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_COMPUTERS' AND PrereqTech = 'TECH_RADAR';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
 ('TECH_REFINED_MICROELECTRONICS', 'TECH_COMPUTERS'),
 ('TECH_REFINED_AUTOMATION', 'TECH_COMPUTERS');

-- Telecom is advanced network infrastructure, no longer an ecology discovery.
DELETE FROM Technology_PrereqTechs WHERE TechType = 'TECH_TELECOM';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
 ('TECH_TELECOM', 'TECH_REFINED_NETWORKS'),
 ('TECH_TELECOM', 'TECH_RADIO');
-- Networks are now an ancestor through Telecom, so avoid a redundant tree line.
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_INTERNET' AND PrereqTech = 'TECH_REFINED_NETWORKS';

-- The robotics discipline is independent of rockets; applications still need them.
DELETE FROM Technology_PrereqTechs WHERE TechType = 'TECH_ROBOTICS';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
 ('TECH_ROBOTICS', 'TECH_REFINED_MICROELECTRONICS'),
 ('TECH_ROBOTICS', 'TECH_REFINED_AUTOMATION');
INSERT INTO Building_TechAndPrereqs (BuildingType, TechType)
 SELECT Type, 'TECH_ROCKETRY' FROM Buildings
 WHERE BuildingClass = 'BUILDINGCLASS_SPACESHIP_FACTORY'
 AND NOT EXISTS (SELECT 1 FROM Building_TechAndPrereqs p
  WHERE p.BuildingType = Buildings.Type AND p.TechType = 'TECH_ROCKETRY');
INSERT INTO Unit_TechTypes (UnitType, TechType)
 SELECT Type, 'TECH_ROCKETRY' FROM Units WHERE Class = 'UNITCLASS_MISSILE_CRUISER'
 AND NOT EXISTS (SELECT 1 FROM Unit_TechTypes p
  WHERE p.UnitType = Units.Type AND p.TechType = 'TECH_ROCKETRY');
-- Radio communications alone do not teach nuclear propulsion.
INSERT INTO Unit_TechTypes (UnitType, TechType)
 SELECT Type, 'TECH_NUCLEAR_FISSION' FROM Units WHERE Class = 'UNITCLASS_NUCLEAR_SUBMARINE'
 AND NOT EXISTS (SELECT 1 FROM Unit_TechTypes p
  WHERE p.UnitType = Units.Type AND p.TechType = 'TECH_NUCLEAR_FISSION');

-- The existing spaceship-engine technology joins nuclear science and spaceflight.
DELETE FROM Technology_PrereqTechs WHERE TechType = 'TECH_PARTICLE_PHYSICS';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
 ('TECH_PARTICLE_PHYSICS', 'TECH_NUCLEAR_FISSION'),
 ('TECH_PARTICLE_PHYSICS', 'TECH_SATELLITES');

INSERT INTO Technology_Flavors (TechType, FlavorType, Flavor) VALUES
 ('TECH_REFINED_MICROELECTRONICS', 'FLAVOR_SCIENCE', 20),
 ('TECH_REFINED_AUTOMATION', 'FLAVOR_PRODUCTION', 20);

-- Reuse the established city-effect system, with the same save/capture handling.
INSERT INTO Refined_EffectBuildings VALUES
 ('BUILDING_REFINED_MICRO_DATA_CENTER'), ('BUILDING_REFINED_AUTOMATION_FACTORY');
INSERT INTO BuildingClasses (Type, DefaultBuilding, Description) VALUES
 ('BUILDINGCLASS_REFINED_MICRO_DATA_CENTER', 'BUILDING_REFINED_MICRO_DATA_CENTER', 'TXT_KEY_REFINED_HIDDEN'),
 ('BUILDINGCLASS_REFINED_AUTOMATION_FACTORY', 'BUILDING_REFINED_AUTOMATION_FACTORY', 'TXT_KEY_REFINED_HIDDEN');
INSERT INTO Buildings
 (Type, BuildingClass, Description, Cost, FaithCost, GreatWorkCount,
  NeverCapture, NukeImmune, ConquestProb, MinAreaSize, HurryCostModifier,
  ArtDefineTag, PortraitIndex, IconAtlas)
 SELECT Type, 'BUILDINGCLASS_' || substr(Type, 10), 'TXT_KEY_REFINED_HIDDEN',
  -1, -1, -1, 1, 1, 0, -1, -1, 'NONE', 0, 'BW_ATLAS_1'
 FROM Refined_EffectBuildings
 WHERE Type IN ('BUILDING_REFINED_MICRO_DATA_CENTER', 'BUILDING_REFINED_AUTOMATION_FACTORY');
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
 VALUES ('BUILDING_REFINED_MICRO_DATA_CENTER', 'YIELD_SCIENCE', 4);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield)
 VALUES ('BUILDING_REFINED_AUTOMATION_FACTORY', 'YIELD_PRODUCTION', 10);
