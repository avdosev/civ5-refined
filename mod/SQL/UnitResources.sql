-- Exact requirements for selected classes, not an additional per-turn expense.
-- Snapshot the real input for debugging and before/after reports.
CREATE TABLE Refined_OriginalUnitResources AS
 SELECT UnitType, ResourceType, Cost FROM Unit_ResourceQuantityRequirements;

CREATE TABLE Refined_UnitResourcePolicy (
 UnitClass TEXT NOT NULL,
 ResourceType TEXT NOT NULL,
 Cost INTEGER NOT NULL,
 PRIMARY KEY (UnitClass, ResourceType)
);
INSERT INTO Refined_UnitResourcePolicy (UnitClass, ResourceType, Cost) VALUES
 -- Armored cavalry. Ranged/animal unique replacements retain their exemptions.
 ('UNITCLASS_KNIGHT', 'RESOURCE_IRON', 1),
 ('UNITCLASS_KNIGHT', 'RESOURCE_HORSE', 1),
 -- Heavy guns; light and infantry-carried weapons keep their vanilla rules.
 ('UNITCLASS_CANNON', 'RESOURCE_IRON', 1),
 ('UNITCLASS_ARTILLERY', 'RESOURCE_IRON', 1),
 ('UNITCLASS_ROCKET_ARTILLERY', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_ROCKET_ARTILLERY', 'RESOURCE_OIL', 1),
 -- Armor and motorized support.
 ('UNITCLASS_WWI_TANK', 'RESOURCE_IRON', 1),
 ('UNITCLASS_WWI_TANK', 'RESOURCE_OIL', 1),
 ('UNITCLASS_TANK', 'RESOURCE_IRON', 1),
 ('UNITCLASS_TANK', 'RESOURCE_OIL', 1),
 ('UNITCLASS_MODERN_ARMOR', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_MODERN_ARMOR', 'RESOURCE_OIL', 1),
 ('UNITCLASS_MECHANIZED_INFANTRY', 'RESOURCE_OIL', 1),
 ('UNITCLASS_MOBILE_SAM', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_MOBILE_SAM', 'RESOURCE_OIL', 1),
 ('UNITCLASS_HELICOPTER_GUNSHIP', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_HELICOPTER_GUNSHIP', 'RESOURCE_OIL', 1),
 ('UNITCLASS_MECH', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_MECH', 'RESOURCE_URANIUM', 1),
 -- Fleet: nuclear propulsion is a different fuel path, not oil plus uranium.
 ('UNITCLASS_IRONCLAD', 'RESOURCE_IRON', 1),
 ('UNITCLASS_IRONCLAD', 'RESOURCE_COAL', 1),
 ('UNITCLASS_DESTROYER', 'RESOURCE_IRON', 1),
 ('UNITCLASS_DESTROYER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_BATTLESHIP', 'RESOURCE_IRON', 1),
 ('UNITCLASS_BATTLESHIP', 'RESOURCE_OIL', 1),
 ('UNITCLASS_CARRIER', 'RESOURCE_IRON', 1),
 ('UNITCLASS_CARRIER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_SUBMARINE', 'RESOURCE_IRON', 1),
 ('UNITCLASS_SUBMARINE', 'RESOURCE_OIL', 1),
 ('UNITCLASS_NUCLEAR_SUBMARINE', 'RESOURCE_IRON', 1),
 ('UNITCLASS_NUCLEAR_SUBMARINE', 'RESOURCE_URANIUM', 1),
 ('UNITCLASS_MISSILE_CRUISER', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_MISSILE_CRUISER', 'RESOURCE_OIL', 1),
 -- Early aircraft: mixed wood/fabric construction; later aircraft: light alloys.
 ('UNITCLASS_TRIPLANE', 'RESOURCE_OIL', 1),
 ('UNITCLASS_WWI_BOMBER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_FIGHTER', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_FIGHTER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_BOMBER', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_BOMBER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_JET_FIGHTER', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_JET_FIGHTER', 'RESOURCE_OIL', 1),
 ('UNITCLASS_STEALTH_BOMBER', 'RESOURCE_ALUMINUM', 1),
 ('UNITCLASS_STEALTH_BOMBER', 'RESOURCE_OIL', 1),
 -- A missile is not treated as an oil-powered vehicle. Nuclear weapons unchanged.
 ('UNITCLASS_GUIDED_MISSILE', 'RESOURCE_ALUMINUM', 1);

-- Explicit resource exemption keeps the Zero's civilization-specific oil advantage.
CREATE TABLE Refined_UnitResourceExemptions (
 UnitType TEXT NOT NULL,
 ResourceType TEXT NOT NULL,
 PRIMARY KEY (UnitType, ResourceType)
);
INSERT INTO Refined_UnitResourceExemptions VALUES
 ('UNIT_JAPANESE_ZERO', 'RESOURCE_OIL'),
 ('UNIT_MONGOLIAN_KESHIK', 'RESOURCE_IRON'),
 ('UNIT_ARABIAN_CAMELARCHER', 'RESOURCE_HORSE'),
 ('UNIT_ARABIAN_CAMELARCHER', 'RESOURCE_IRON'),
 ('UNIT_SIAMESE_WARELEPHANT', 'RESOURCE_HORSE'),
 ('UNIT_SIAMESE_WARELEPHANT', 'RESOURCE_IRON');

DELETE FROM Unit_ResourceQuantityRequirements
 WHERE UnitType IN (SELECT u.Type FROM Units u
  JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class);
INSERT INTO Unit_ResourceQuantityRequirements (UnitType, ResourceType, Cost)
 SELECT u.Type, p.ResourceType, p.Cost
 FROM Units u JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class
 WHERE NOT EXISTS (SELECT 1 FROM Refined_UnitResourceExemptions e
  WHERE e.UnitType = u.Type AND e.ResourceType = p.ResourceType);

-- Append the complete effective list so stock prose cannot hide a new requirement.
-- Built-in unit tooltips also read Unit_ResourceQuantityRequirements directly.
CREATE TABLE Refined_ResourceLabels (ResourceType TEXT PRIMARY KEY, EN TEXT, RU TEXT);
INSERT INTO Refined_ResourceLabels VALUES
 ('RESOURCE_HORSE', 'Horses', 'лошади'),
 ('RESOURCE_IRON', 'Iron', 'железо'),
 ('RESOURCE_COAL', 'Coal', 'уголь'),
 ('RESOURCE_OIL', 'Oil', 'нефть'),
 ('RESOURCE_ALUMINUM', 'Aluminum', 'алюминий'),
 ('RESOURCE_URANIUM', 'Uranium', 'уран');
CREATE VIEW Refined_UnitResourceHelp AS
 SELECT r.UnitType,
 group_concat(CAST(r.Cost AS TEXT) || ' ' || labels.EN, ', ') AS EN,
 group_concat(CAST(r.Cost AS TEXT) || ' ' || labels.RU, ', ') AS RU
 FROM Unit_ResourceQuantityRequirements r
 JOIN Refined_ResourceLabels labels ON labels.ResourceType = r.ResourceType
 GROUP BY r.UnitType;
UPDATE Language_en_US SET Text = Text || '[NEWLINE][NEWLINE]Refined resources: ' ||
 COALESCE((SELECT h.EN FROM Refined_UnitResourceHelp h JOIN Units u ON u.Type = h.UnitType
  WHERE u.Help = Language_en_US.Tag LIMIT 1), 'None') || '.'
 WHERE Tag IN (SELECT u.Help FROM Units u
  JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class);
UPDATE Language_RU_RU SET Text = Text || '[NEWLINE][NEWLINE]Ресурсы Refined: ' ||
 COALESCE((SELECT h.RU FROM Refined_UnitResourceHelp h JOIN Units u ON u.Type = h.UnitType
  WHERE u.Help = Language_RU_RU.Tag LIMIT 1), 'нет') || '.'
 WHERE Tag IN (SELECT u.Help FROM Units u
  JOIN Refined_UnitResourcePolicy p ON p.UnitClass = u.Class);
