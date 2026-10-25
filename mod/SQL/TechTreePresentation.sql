-- v5: route new branches within the stock BNW renderer's four-row limit.
-- Earlier v4 fixtures used guessed coordinates (notably Computers row 6 vs 7).
UPDATE Technologies SET GridY = 7 WHERE Type = 'TECH_REFINED_NETWORKS';
UPDATE Technologies SET GridY = 8 WHERE Type = 'TECH_REFINED_MICROELECTRONICS';
UPDATE Technologies SET GridY = 9 WHERE Type = 'TECH_REFINED_AUTOMATION';
UPDATE Technologies SET GridY = 3 WHERE Type = 'TECH_TELECOM';
UPDATE Technologies SET GridX = 17, GridY = 3 WHERE Type = 'TECH_REFINED_AI';
UPDATE Technologies SET GridX = 18, GridY = 4 WHERE Type = 'TECH_FUTURE_TECH';

-- Use adjacent-column foundations rather than long transitive connectors.
-- Radio already requires Electricity; Atomic Theory requires Electronics/Plastic.
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_ELECTRONICS' AND PrereqTech = 'TECH_ELECTRICITY';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 SELECT 'TECH_ELECTRONICS', 'TECH_RADIO'
 WHERE NOT EXISTS (SELECT 1 FROM Technology_PrereqTechs
  WHERE TechType = 'TECH_ELECTRONICS' AND PrereqTech = 'TECH_RADIO');
DELETE FROM Technology_PrereqTechs WHERE TechType = 'TECH_COMPUTERS';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 VALUES ('TECH_COMPUTERS', 'TECH_ATOMIC_THEORY');
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_TELECOM' AND PrereqTech = 'TECH_RADIO';
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_LASERS' AND PrereqTech = 'TECH_COMPUTERS';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 VALUES ('TECH_LASERS', 'TECH_REFINED_MICROELECTRONICS');

-- Internet and AI are parallel applications of the same communications base.
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_REFINED_AI' AND PrereqTech = 'TECH_INTERNET';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 VALUES ('TECH_REFINED_AI', 'TECH_TELECOM');
-- Fission remains an ancestor via Advanced Ballistics, without a long direct line.
DELETE FROM Technology_PrereqTechs
 WHERE TechType = 'TECH_PARTICLE_PHYSICS' AND PrereqTech = 'TECH_NUCLEAR_FISSION';
INSERT INTO Technology_PrereqTechs (TechType, PrereqTech)
 VALUES ('TECH_PARTICLE_PHYSICS', 'TECH_ADVANCED_BALLISTICS');

-- BNW supports four scenario-ability markers without replacing TechTree Lua.
-- These are UI flags only: all actual bonuses still come from Refined.lua.
UPDATE Technologies SET ScenarioTechButton = 1 WHERE Type = 'TECH_REFINED_NETWORKS';
UPDATE Technologies SET ScenarioTechButton = 2 WHERE Type = 'TECH_REFINED_MICROELECTRONICS';
UPDATE Technologies SET ScenarioTechButton = 3 WHERE Type = 'TECH_REFINED_AUTOMATION';
UPDATE Technologies SET ScenarioTechButton = 4 WHERE Type = 'TECH_REFINED_AI';
INSERT OR REPLACE INTO Language_en_US (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_1', Text FROM Language_en_US WHERE Tag = 'TXT_KEY_REFINED_NETWORKS_HELP';
INSERT OR REPLACE INTO Language_en_US (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_2', Text FROM Language_en_US WHERE Tag = 'TXT_KEY_REFINED_MICRO_HELP';
INSERT OR REPLACE INTO Language_en_US (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_3', Text FROM Language_en_US WHERE Tag = 'TXT_KEY_REFINED_AUTOMATION_HELP';
INSERT OR REPLACE INTO Language_en_US (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_4', Text FROM Language_en_US WHERE Tag = 'TXT_KEY_REFINED_AI_HELP';
INSERT OR REPLACE INTO Language_RU_RU (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_1', Text FROM Language_RU_RU WHERE Tag = 'TXT_KEY_REFINED_NETWORKS_HELP';
INSERT OR REPLACE INTO Language_RU_RU (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_2', Text FROM Language_RU_RU WHERE Tag = 'TXT_KEY_REFINED_MICRO_HELP';
INSERT OR REPLACE INTO Language_RU_RU (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_3', Text FROM Language_RU_RU WHERE Tag = 'TXT_KEY_REFINED_AUTOMATION_HELP';
INSERT OR REPLACE INTO Language_RU_RU (Tag, Text)
 SELECT 'TXT_KEY_SCENARIO_TECH_BUTTON_4', Text FROM Language_RU_RU WHERE Tag = 'TXT_KEY_REFINED_AI_HELP';
