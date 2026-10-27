-- v6: native BNW content. No DLL additions.
INSERT INTO Improvement_TechYieldChanges (ImprovementType, TechType, YieldType, Yield)
VALUES ('IMPROVEMENT_QUARRY', 'TECH_CONSTRUCTION', 'YIELD_PRODUCTION', 1);
UPDATE Improvement_TechYieldChanges SET TechType = 'TECH_MACHINERY'
WHERE ImprovementType = 'IMPROVEMENT_LUMBERMILL' AND TechType = 'TECH_SCIENTIFIC_THEORY'
 AND YieldType = 'YIELD_PRODUCTION';

-- Extend the Industrial era by one column. Keep all subsequent era bands aligned.
UPDATE Technologies SET GridX = GridX + 1 WHERE GridX >= 11;
-- Railroad's new row keeps Steam Power's short downward and long upward
-- outgoing adapters compatible with the native renderer (no UI replacement).
UPDATE Technologies SET GridY = 4 WHERE Type = 'TECH_RAILROAD';
-- Military Science already requires Chemistry. Explosives need that chemistry,
-- not agricultural fertilizer. Removing this gate also gives Fertilizer a single
-- outgoing connector to the agricultural branch.
DELETE FROM Technology_PrereqTechs
WHERE TechType = 'TECH_DYNAMITE' AND PrereqTech = 'TECH_FERTILIZER';
INSERT INTO Technologies
(Type, Cost, Description, Civilopedia, Help, Quote, Era, GridX, GridY, PortraitIndex, IconAtlas, Trade, ScenarioTechButton)
SELECT 'TECH_REFINED_AGRICULTURAL_MECHANIZATION', 2350,
 'TXT_KEY_REFINED_AGRICULTURE', 'TXT_KEY_REFINED_AGRICULTURE_PEDIA',
 'TXT_KEY_REFINED_AGRICULTURE_HELP', 'TXT_KEY_REFINED_AGRICULTURE_QUOTE',
 'ERA_INDUSTRIAL', 11, 9, PortraitIndex, IconAtlas, 1, 1
FROM Technologies WHERE Type = 'TECH_FERTILIZER';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech) VALUES
('TECH_REFINED_AGRICULTURAL_MECHANIZATION', 'TECH_FERTILIZER'),
('TECH_REFINED_AGRICULTURAL_MECHANIZATION', 'TECH_STEAM_POWER');
INSERT INTO Technology_Flavors (TechType, FlavorType, Flavor) VALUES
('TECH_REFINED_AGRICULTURAL_MECHANIZATION', 'FLAVOR_GROWTH', 25),
('TECH_REFINED_AGRICULTURAL_MECHANIZATION', 'FLAVOR_TILE_IMPROVEMENT', 10);

CREATE TABLE Refined_NewBuildings
(Type TEXT PRIMARY KEY, TextKey TEXT, Tech TEXT, Cost INTEGER, Maintenance INTEGER, Template TEXT);
INSERT INTO Refined_NewBuildings VALUES
('BUILDING_REFINED_STEEL_MILL', 'TXT_KEY_REFINED_STEEL_MILL', 'TECH_INDUSTRIALIZATION', 260, 3, 'BUILDING_FACTORY'),
('BUILDING_REFINED_TEXTILE', 'TXT_KEY_REFINED_TEXTILE', 'TECH_GUILDS', 100, 0, 'BUILDING_MINT'),
('BUILDING_REFINED_ACADEMY', 'TXT_KEY_REFINED_ACADEMY', 'TECH_PRINTING_PRESS', 160, 1, 'BUILDING_UNIVERSITY'),
('BUILDING_REFINED_SALON', 'TXT_KEY_REFINED_SALON', 'TECH_PRINTING_PRESS', 160, 1, 'BUILDING_OPERA_HOUSE');
INSERT INTO BuildingClasses (Type, DefaultBuilding, Description)
SELECT 'BUILDINGCLASS_' || substr(Type, 10), Type, TextKey FROM Refined_NewBuildings;
INSERT INTO Buildings
(Type, BuildingClass, Description, Civilopedia, Help, Strategy, PrereqTech, Cost, GoldMaintenance,
 ArtDefineTag, MinAreaSize, HurryCostModifier, ConquestProb, PortraitIndex, IconAtlas)
SELECT n.Type, 'BUILDINGCLASS_' || substr(n.Type, 10), n.TextKey, n.TextKey || '_PEDIA',
 n.TextKey || '_HELP', n.TextKey || '_STRATEGY', n.Tech, n.Cost, n.Maintenance,
 b.ArtDefineTag, -1, 25, 66, b.PortraitIndex, b.IconAtlas
FROM Refined_NewBuildings n JOIN Buildings b ON b.Type = n.Template;
-- Choose an unused native exclusion group; never collide with power plants.
UPDATE Buildings SET MutuallyExclusiveGroup =
 (SELECT COALESCE(MAX(MutuallyExclusiveGroup), 0) + 1 FROM Buildings
  WHERE Type NOT IN ('BUILDING_REFINED_ACADEMY', 'BUILDING_REFINED_SALON'))
WHERE Type IN ('BUILDING_REFINED_ACADEMY', 'BUILDING_REFINED_SALON');
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield) VALUES
('BUILDING_REFINED_STEEL_MILL', 'YIELD_PRODUCTION', 3),
('BUILDING_REFINED_TEXTILE', 'YIELD_PRODUCTION', 1),
('BUILDING_REFINED_ACADEMY', 'YIELD_SCIENCE', 2),
('BUILDING_REFINED_SALON', 'YIELD_CULTURE', 2);
INSERT INTO Building_YieldModifiers (BuildingType, YieldType, Yield) VALUES
('BUILDING_REFINED_ACADEMY', 'YIELD_SCIENCE', 10);
INSERT INTO Building_ResourceQuantityRequirements (BuildingType, ResourceType, Cost)
VALUES ('BUILDING_REFINED_STEEL_MILL', 'RESOURCE_IRON', 1);
INSERT INTO Building_LocalResourceOrs (BuildingType, ResourceType) VALUES
('BUILDING_REFINED_TEXTILE', 'RESOURCE_COTTON'),
('BUILDING_REFINED_TEXTILE', 'RESOURCE_SILK'),
('BUILDING_REFINED_TEXTILE', 'RESOURCE_SHEEP');
INSERT INTO Building_ResourceYieldChanges (BuildingType, ResourceType, YieldType, Yield) VALUES
('BUILDING_REFINED_TEXTILE', 'RESOURCE_COTTON', 'YIELD_GOLD', 1),
('BUILDING_REFINED_TEXTILE', 'RESOURCE_SILK', 'YIELD_GOLD', 1),
('BUILDING_REFINED_TEXTILE', 'RESOURCE_SHEEP', 'YIELD_GOLD', 1);
CREATE TABLE Refined_SteelClasses (UnitClass TEXT PRIMARY KEY);
INSERT INTO Refined_SteelClasses VALUES
('UNITCLASS_WWI_TANK'), ('UNITCLASS_TANK'), ('UNITCLASS_MODERN_ARMOR'), ('UNITCLASS_MECH'),
('UNITCLASS_IRONCLAD'), ('UNITCLASS_DESTROYER'), ('UNITCLASS_BATTLESHIP'),
('UNITCLASS_CARRIER'), ('UNITCLASS_MISSILE_CRUISER'), ('UNITCLASS_SUBMARINE'), ('UNITCLASS_NUCLEAR_SUBMARINE');
INSERT INTO Unit_ProductionModifierBuildings (UnitType, BuildingType, ProductionModifier)
SELECT u.Type, 'BUILDING_REFINED_STEEL_MILL', 15
FROM Units u JOIN Refined_SteelClasses c ON c.UnitClass = u.Class;
INSERT INTO Building_Flavors (BuildingType, FlavorType, Flavor) VALUES
('BUILDING_REFINED_STEEL_MILL', 'FLAVOR_PRODUCTION', 20),
('BUILDING_REFINED_STEEL_MILL', 'FLAVOR_NAVAL', 12),
('BUILDING_REFINED_TEXTILE', 'FLAVOR_GOLD', 15),
('BUILDING_REFINED_TEXTILE', 'FLAVOR_PRODUCTION', 8),
('BUILDING_REFINED_ACADEMY', 'FLAVOR_SCIENCE', 25),
('BUILDING_REFINED_SALON', 'FLAVOR_CULTURE', 25);

-- One carrier per city, per library CLASS (including Paper Maker and Royal Library).
INSERT INTO Refined_EffectBuildings VALUES ('BUILDING_REFINED_PRINTING_CULTURE');
INSERT INTO BuildingClasses (Type, DefaultBuilding, Description)
VALUES ('BUILDINGCLASS_REFINED_PRINTING_CULTURE', 'BUILDING_REFINED_PRINTING_CULTURE', 'TXT_KEY_REFINED_HIDDEN');
INSERT INTO Buildings
(Type, BuildingClass, Description, Cost, FaithCost, GreatWorkCount, NeverCapture,
 NukeImmune, ConquestProb, MinAreaSize, HurryCostModifier, ArtDefineTag, PortraitIndex, IconAtlas)
VALUES ('BUILDING_REFINED_PRINTING_CULTURE', 'BUILDINGCLASS_REFINED_PRINTING_CULTURE',
 'TXT_KEY_REFINED_HIDDEN', -1, -1, -1, 1, 1, 0, -1, -1, 'NONE', 0, 'BW_ATLAS_1');
-- Flat culture uses the BNW culture yield; its percentage uses the dedicated field.
INSERT INTO Building_YieldChanges (BuildingType, YieldType, Yield)
VALUES ('BUILDING_REFINED_PRINTING_CULTURE', 'YIELD_CULTURE', 4);
UPDATE Buildings SET CultureRateModifier = 10 WHERE Type = 'BUILDING_REFINED_SALON';

-- Four stock ability slots exist. Slot 1 is shared by these two named abilities;
-- list both explicitly rather than fabricate an improvement yield for an icon.
UPDATE Language_en_US SET Text =
 'Computer Networks: +10% Gold in cities with a Stock Exchange.[NEWLINE]Agricultural Mechanization: each Farm gains max(0, adjacent friendly unpillaged Farms - 1) Food.'
WHERE Tag = 'TXT_KEY_SCENARIO_TECH_BUTTON_1';
UPDATE Language_RU_RU SET Text =
 'Компьютерные сети: +10% золота в городах с фондовой биржей.[NEWLINE]Механизация сельского хозяйства: каждая ферма получает max(0, соседние собственные неразграбленные фермы - 1) пищи.'
WHERE Tag = 'TXT_KEY_SCENARIO_TECH_BUTTON_1';

CREATE TABLE Refined_Eurekas (TechType TEXT PRIMARY KEY, Rule TEXT, Threshold INTEGER, Help TEXT);
INSERT INTO Refined_Eurekas VALUES ('TECH_HORSEBACK_RIDING', 'pastureHorse', 1, 'TXT_KEY_REFINED_EUREKA_HORSEBACK_RIDING');
INSERT INTO Refined_Eurekas VALUES ('TECH_CONSTRUCTION', 'quarry', 1, 'TXT_KEY_REFINED_EUREKA_CONSTRUCTION');
INSERT INTO Refined_Eurekas VALUES ('TECH_IRON_WORKING', 'mineIron', 1, 'TXT_KEY_REFINED_EUREKA_IRON_WORKING');
INSERT INTO Refined_Eurekas VALUES ('TECH_EDUCATION', 'BUILDINGCLASS_LIBRARY', 2, 'TXT_KEY_REFINED_EUREKA_EDUCATION');
INSERT INTO Refined_Eurekas VALUES ('TECH_MACHINERY', 'mine', 3, 'TXT_KEY_REFINED_EUREKA_MACHINERY');
INSERT INTO Refined_Eurekas VALUES ('TECH_BANKING', 'trade', 3, 'TXT_KEY_REFINED_EUREKA_BANKING');
INSERT INTO Refined_Eurekas VALUES ('TECH_PRINTING_PRESS', 'UNITCLASS_WRITER', 1, 'TXT_KEY_REFINED_EUREKA_PRINTING_PRESS');
INSERT INTO Refined_Eurekas VALUES ('TECH_NAVIGATION', 'BUILDINGCLASS_HARBOR', 2, 'TXT_KEY_REFINED_EUREKA_NAVIGATION');
INSERT INTO Refined_Eurekas VALUES ('TECH_RIFLING', 'UNITCLASS_MUSKETMAN', 3, 'TXT_KEY_REFINED_EUREKA_RIFLING');
INSERT INTO Refined_Eurekas VALUES ('TECH_SCIENTIFIC_THEORY', 'UNITCLASS_SCIENTIST', 1, 'TXT_KEY_REFINED_EUREKA_SCIENTIFIC_THEORY');
INSERT INTO Refined_Eurekas VALUES ('TECH_INDUSTRIALIZATION', 'BUILDINGCLASS_WORKSHOP', 2, 'TXT_KEY_REFINED_EUREKA_INDUSTRIALIZATION');
INSERT INTO Refined_Eurekas VALUES ('TECH_ECONOMICS', 'BUILDINGCLASS_REFINED_TEXTILE', 1, 'TXT_KEY_REFINED_EUREKA_ECONOMICS');
INSERT INTO Refined_Eurekas VALUES ('TECH_STEAM_POWER', 'mineCoal', 1, 'TXT_KEY_REFINED_EUREKA_STEAM_POWER');
INSERT INTO Refined_Eurekas VALUES ('TECH_ELECTRICITY', 'BUILDINGCLASS_FACTORY', 1, 'TXT_KEY_REFINED_EUREKA_ELECTRICITY');
INSERT INTO Refined_Eurekas VALUES ('TECH_PLASTIC', 'BUILDINGCLASS_PUBLIC_SCHOOL', 2, 'TXT_KEY_REFINED_EUREKA_PLASTIC');
INSERT INTO Refined_Eurekas VALUES ('TECH_NUCLEAR_FISSION', 'mineUranium', 1, 'TXT_KEY_REFINED_EUREKA_NUCLEAR_FISSION');
INSERT INTO Refined_Eurekas VALUES ('TECH_COMPUTERS', 'BUILDINGCLASS_LABORATORY', 2, 'TXT_KEY_REFINED_EUREKA_COMPUTERS');
INSERT INTO Refined_Eurekas VALUES ('TECH_REFINED_NETWORKS', 'BUILDINGCLASS_REFINED_DATA_CENTER', 2, 'TXT_KEY_REFINED_EUREKA_REFINED_NETWORKS');
INSERT INTO Refined_Eurekas VALUES ('TECH_REFINED_AUTOMATION', 'BUILDINGCLASS_REFINED_STEEL_MILL', 1, 'TXT_KEY_REFINED_EUREKA_REFINED_AUTOMATION');
UPDATE Language_en_US SET Text = Text || '[NEWLINE][NEWLINE]Eureka (25%): ' ||
 (SELECT l.Text FROM Refined_Eurekas e JOIN Technologies t ON t.Type=e.TechType
 JOIN Language_en_US l ON l.Tag=e.Help WHERE t.Help=Language_en_US.Tag)
WHERE Tag IN (SELECT t.Help FROM Technologies t JOIN Refined_Eurekas e ON e.TechType=t.Type);
UPDATE Language_RU_RU SET Text = Text || '[NEWLINE][NEWLINE]Эврика (25%): ' ||
 (SELECT l.Text FROM Refined_Eurekas e JOIN Technologies t ON t.Type=e.TechType
 JOIN Language_RU_RU l ON l.Tag=e.Help WHERE t.Help=Language_RU_RU.Tag)
WHERE Tag IN (SELECT t.Help FROM Technologies t JOIN Refined_Eurekas e ON e.TechType=t.Type);
UPDATE Language_en_US SET Text=Text || '[NEWLINE][NEWLINE]Refined: +1 Food on Fish tiles with unpillaged Fishing Boats.' WHERE Tag=(SELECT Help FROM Technologies WHERE Type='TECH_REFRIGERATION');
UPDATE Language_RU_RU SET Text=Text || '[NEWLINE][NEWLINE]Refined: +1 пищи на клетках рыбы с неразграбленными рыбацкими лодками.' WHERE Tag=(SELECT Help FROM Technologies WHERE Type='TECH_REFRIGERATION');
UPDATE Language_en_US SET Text=Text || '[NEWLINE][NEWLINE]Refined: Libraries and their unique replacements provide +4 Culture.' WHERE Tag=(SELECT Help FROM Technologies WHERE Type='TECH_PRINTING_PRESS');
UPDATE Language_RU_RU SET Text=Text || '[NEWLINE][NEWLINE]Refined: библиотеки и их уникальные замены дают +4 культуры.' WHERE Tag=(SELECT Help FROM Technologies WHERE Type='TECH_PRINTING_PRESS');
-- Keep stock ability tooltips in sync after appending eureka help.
UPDATE Language_en_US SET Text=(SELECT Text FROM Language_en_US WHERE Tag='TXT_KEY_REFINED_AUTOMATION_HELP') WHERE Tag='TXT_KEY_SCENARIO_TECH_BUTTON_3';
UPDATE Language_RU_RU SET Text=(SELECT Text FROM Language_RU_RU WHERE Tag='TXT_KEY_REFINED_AUTOMATION_HELP') WHERE Tag='TXT_KEY_SCENARIO_TECH_BUTTON_3';
