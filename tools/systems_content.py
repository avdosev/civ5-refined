#!/usr/bin/env python3
"""Declarative v7 content: generates SQL, bilingual text and the complete ally list.

Numbers are prototype balance, not measurements. No new minor civilizations.
"""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
ALLIES = []

# Target policy, localized additional/full help, replacement versus append.
POLICY_TEXT = [
 ('TRADITION_FINISHER', 'С индустриальной эпохи столица дополнительно даёт +1 культуры за каждые 5 жителей.',
  'From the Industrial Era, the Capital also provides +1 Culture per 5 Citizens.', False),
 ('REPUBLIC', '+1 производства каждому городу. Бесплатный рабочий и +25% скорости работ рабочих.',
  '+1 Production in every city. A free Worker and +25% Worker improvement speed.', True),
 ('CITIZENSHIP', '+1 счастья за каждый город, соединённый со столицей; −5% несчастья от населения неоккупированных городов.',
  '+1 Happiness per city connected to the Capital; −5% Unhappiness from Citizens in non-occupied cities.', True),
 ('MERITOCRACY', 'Каждый специалист, работающий в здании, дополнительно даёт +1 науки и +1 производства. Безработные жители не учитываются. Требует Представительства.',
  'Each specialist working in a building provides +1 Science and +1 Production. Unemployed Citizens do not count. Requires Representation.', True),
 ('LIBERTY_FINISHER', 'Города, основанные после завершения ветки, получают монумент (или уникальную замену) без затрат производства. Содержание и продажа обычные. Все города получают +10% производства обычных зданий без ограничения населения. Чудеса, юниты и проекты не ускоряются.',
  'Cities founded after completing this branch receive a Monument (or its unique replacement) at no Production cost, with normal maintenance and sale rules. All cities gain +10% Production of ordinary buildings, with no Population limit. Wonders, units and projects are not accelerated.', False),
 ('HONOR_FINISHER', 'Дополнительно: уничтожение военного юнита другой цивилизации даёт культуру в размере 25% большей из его базовых сил ближнего и дальнего боя, с округлением вниз. Культура за варваров и золото за победы сохраняются.',
  'Additionally, killing another civilization\'s military unit grants Culture equal to 25% of the higher of its base melee and ranged strength, rounded down. Existing barbarian Culture and victory Gold remain.', False),
 ('ORGANIZED_RELIGION', 'С индустриальной эпохи храмы и их уникальные замены дополнительно дают +2 культуры и +2 науки.',
  'From the Industrial Era, Temples and their unique replacements also provide +2 Culture and +2 Science.', False),
 ('MANDATE_OF_HEAVEN', 'Стоимость покупки миссионеров, инквизиторов и зданий за веру снижена на 25%. Скидка не действует на великих людей, включая пророков, и военные юниты за веру.',
  'Faith purchases of Missionaries, Inquisitors and buildings cost 25% less. This discount does not apply to Great People, including Prophets, or military units purchased with Faith.', True),
 ('PIETY_FINISHER', 'Дополнительно: стоимость покупки миссионеров, инквизиторов и зданий за веру снижена на 10% (с Небесным мандатом суммарно на 35%). На великих людей и военные юниты скидка не действует.',
  'Additionally, Faith purchases of Missionaries, Inquisitors and buildings cost 10% less (35% total with Mandate of Heaven). Great People and military unit costs are unaffected.', False),
 ('PATRONAGE_FINISHER', 'Дополнительно: столица получает +2 культуры за каждый город-государство, с которым заключён союз. Их уникальные бонусы доступны любому союзнику, даже без этой ветки.',
  'Additionally, the Capital receives +2 Culture per allied City-State. Unique alliance benefits are available to any ally, even without this branch.', False),
 ('AESTHETICS', 'Дополнительно: каждое великое произведение даёт +1 культуры.',
  'Additionally, each Great Work provides +1 Culture.', False),
 ('CULTURAL_CENTERS', '+75% производства монументов, амфитеатров, оперных театров, музеев и вещательных башен, включая уникальные замены.',
  '+75% Production of Monuments, Amphitheaters, Opera Houses, Museums and Broadcast Towers, including unique replacements.', True),
 ('FLOURISHING_OF_ARTS', '+20% культуры в городах хотя бы с двумя великими произведениями. Начинается золотой век. Чудо света не требуется.',
  '+20% Culture in cities with at least two Great Works. Starts a Golden Age. No World Wonder is required.', True),
 ('ARTISTIC_GENIUS', 'Дополнительно: музеи дают +2 культуры.', 'Additionally, Museums provide +2 Culture.', False),
 ('TRADE_UNIONS', 'Позволяет покупать наёмников за золото: ландскнехты (гражданская служба), швейцарская гвардия (порох), наёмный иностранный легион (взаимозаменяемые детали). Линия модернизации: ландскнехты → гвардия → легион → пехота. Новые наёмники могут двигаться сразу после покупки.',
  'Allows Gold purchases of mercenaries: Landsknechts (Civil Service), Swiss Guard (Gunpowder), Mercenary Foreign Legion (Replaceable Parts). Upgrade line: Landsknecht → Guard → Legion → Infantry. New mercenaries can move immediately after purchase.', True),
 ('ENTREPRENEURSHIP', 'Дополнительно: торговые миссии великих торговцев дают на 50% больше влияния. Это усиление обычного влияния миссии, а не новая награда.',
  'Additionally, Great Merchant trade missions grant 50% more Influence. This increases the mission\'s normal Influence reward.', False),
 ('COMMERCE_FINISHER', 'Дополнительно: внутренние торговые пути приносят на 25% больше пищи и производства; базовый лимит торговых путей увеличен на 1, по обычным правилам BNW. Торговый юнит нужно построить или купить.',
  'Additionally, internal trade routes provide 25% more Food and Production; base Trade Route capacity increases by 1 under normal BNW rules. A trade unit must be trained or purchased.', False),
 ('MARITIME_INFRASTRUCTURE', 'Дополнительно: морские порты дают +2 производства.',
  'Additionally, Seaports provide +2 Production.', False),
 ('MERCHANT_NAVY', 'Маяки дают +1 золота; гавани и морские порты дают по +3 золота. Ост-Индская компания даёт +4 производства и +4 культуры.',
  'Lighthouses provide +1 Gold; Harbors and Seaports each provide +3 Gold. The East India Company provides +4 Production and +4 Culture.', True),
 ('NAVIGATION_SCHOOL', 'Дополнительно: новые морские юниты получают +10 опыта.',
  'Additionally, newly trained naval units receive +10 Experience.', False),
 ('TREASURE_FLEETS', '+6 золота за ход от каждого своего международного морского торгового пути с учётом морского множителя: к другой державе или городу-государству. Внутренние перевозки пищи и производства этот бонус не получают.',
  '+6 Gold per turn from each outgoing international sea trade route after the sea modifier, including routes to City-States. Internal Food and Production routes do not receive this bonus.', True),
 ('EXPLORATION_FINISHER', 'Дополнительно: +50% производства археологов, +1 культуры от музеев. Скрытые памятники древности и покупка великих адмиралов за веру сохраняются.',
  'Additionally, +50% Production of Archaeologists and +1 Culture from Museums. Hidden Antiquity Sites and Faith purchases of Great Admirals remain.', False),
]


def ally(code, name, ru, en, scope='all', classes=(), yields=None, mods=None,
         fields=None, resources=(), unitcombat=(), domainxp=0):
    ALLIES.append(dict(code=code, name=name, ru=ru, en=en, scope=scope,
                       classes=classes, yields=yields or {}, mods=mods or {},
                       fields=fields or {}, resources=resources,
                       unitcombat=unitcombat, domainxp=domainxp))


ally('BRATISLAVA', 'Братислава', '+2 культуры от амфитеатров и оперных театров.',
     '+2 Culture from Amphitheaters and Opera Houses.', classes=('AMPHITHEATER', 'OPERA_HOUSE'), yields={'CULTURE': 2})
ally('BUDAPEST', 'Будапешт', '+15% производства конных и бронетанковых юнитов.',
     '+15% Production of mounted and armored units.', unitcombat=('MOUNTED', 'ARMOR'))
ally('GENEVA', 'Женева', '+10% науки в городах, пока союзник не воюет ни с одной цивилизацией или городом-государством.',
     '+10% Science in cities while the ally is not at war with any civilization or City-State.', scope='peace', mods={'SCIENCE': 10})
ally('RIGA', 'Рига', '+2 производства от маяков и гаваней.',
     '+2 Production from Lighthouses and Harbors.', classes=('LIGHTHOUSE', 'HARBOR'), yields={'PRODUCTION': 2})
ally('GENOA', 'Генуя', '+2 золота от рынков и банков.',
     '+2 Gold from Markets and Banks.', classes=('MARKET', 'BANK'), yields={'GOLD': 2})
ally('FLORENCE', 'Флоренция', '+1 культуры за каждое великое произведение в городе.',
     '+1 Culture per Great Work in a city.', scope='works', yields={'CULTURE': 1})
ally('RAGUSA', 'Рагуза', '+10% золота в прибрежных городах.',
     '+10% Gold in coastal cities.', scope='coast', mods={'GOLD': 10})
ally('SYDNEY', 'Сидней', '+2 пищи от амбаров и больниц.',
     '+2 Food from Granaries and Hospitals.', classes=('GRANARY', 'HOSPITAL'), yields={'FOOD': 2})
ally('QUEBEC_CITY', 'Квебек', '+2 пищи от маяков.',
     '+2 Food from Lighthouses.', classes=('LIGHTHOUSE',), yields={'FOOD': 2})
ally('BUCHAREST', 'Бухарест', '+1 культуры от монументов и вещательных башен.',
     '+1 Culture from Monuments and Broadcast Towers.', classes=('MONUMENT', 'BROADCAST_TOWER'), yields={'CULTURE': 1})
ally('BELGRADE', 'Белград', '+5 силы обороны и +25 очков здоровья городов.',
     '+5 city Defense Strength and +25 city Hit Points.', fields={'Defense': 500, 'ExtraCityHitPoints': 25})
ally('BRUSSELS', 'Брюссель', '+10% производства мировых и национальных чудес.',
     '+10% Production of Wonders.', fields={'WonderProductionModifier': 10})
ally('MONACO', 'Монако', '+2 золота за каждое великое произведение в городе.',
     '+2 Gold per Great Work in a city.', scope='works', yields={'GOLD': 2})
ally('KATHMANDU', 'Катманду', '+2 веры от святилищ и храмов.',
     '+2 Faith from Shrines and Temples.', classes=('SHRINE', 'TEMPLE'), yields={'FAITH': 2})
ally('HANOI', 'Ханой', '+10 опыта новым юнитам в городах с казармами.',
     '+10 starting Experience for units trained in cities with Barracks.', classes=('BARRACKS',), fields={'Experience': 10})
ally('LHASA', 'Лхаса', '+2 пищи от храмов.',
     '+2 Food from Temples.', classes=('TEMPLE',), yields={'FOOD': 2})
ally('ALMATY', 'Алматы', '+1 производства с обрабатываемых клеток лошадей и скота.',
     '+1 Production on worked Horse and Cattle tiles.', resources=('HORSE', 'COW'), yields={'PRODUCTION': 1})
ally('KUALA_LUMPUR', 'Куала-Лумпур', '+2 культуры от садов.',
     '+2 Culture from Gardens.', classes=('GARDEN',), yields={'CULTURE': 2})
ally('SINGAPORE', 'Сингапур', 'За каждую новую технологию: 10 золота на стандартной скорости, с пересчётом для других скоростей. Награда не растёт по эпохам.',
     'Each new technology grants 10 Gold on Standard speed, scaled for other game speeds. The reward does not increase with era.', scope='technology')
ally('PANAMA_CITY', 'Панама', '+2 золота от маяков, гаваней и морских портов.',
     '+2 Gold from Lighthouses, Harbors and Seaports.', classes=('LIGHTHOUSE', 'HARBOR', 'SEAPORT'), yields={'GOLD': 2})
ally('CAPE_TOWN', 'Кейптаун', '+1 пищи и +1 производства в прибрежных городах.',
     '+1 Food and +1 Production in coastal cities.', scope='coast', yields={'FOOD': 1, 'PRODUCTION': 1})
ally('SIDON', 'Сидон', '+20% производства стрелковых юнитов.',
     '+20% Production of archery-class units.', unitcombat=('ARCHER',), fields={})
ally('TYRE', 'Тир', '+10 опыта новым морским юнитам.',
     '+10 starting Experience for naval units.', domainxp=10)
ally('ANTWERP', 'Антверпен', '+2 золота с обрабатываемых клеток золота, серебра и самоцветов.',
     '+2 Gold on worked Gold, Silver and Gems tiles.', resources=('GOLD', 'SILVER', 'GEMS'), yields={'GOLD': 2})
ally('CAHOKIA', 'Кахокия', '+1 пищи с обрабатываемых клеток оленей и бизонов.',
     '+1 Food on worked Deer and Bison tiles.', resources=('DEER', 'BISON'), yields={'FOOD': 1})
ally('COLOMBO', 'Коломбо', '+2 золота от святилищ и храмов.',
     '+2 Gold from Shrines and Temples.', classes=('SHRINE', 'TEMPLE'), yields={'GOLD': 2})
ally('HONG_KONG', 'Гонконг', '+10% производства в городах с фабрикой.',
     '+10% Production in cities with a Factory.', classes=('FACTORY',), mods={'PRODUCTION': 10})
ally('ORMUS', 'Ормуз', '+1 золота и +1 веры от рынков.',
     '+1 Gold and +1 Faith from Markets.', classes=('MARKET',), yields={'GOLD': 1, 'FAITH': 1})
ally('JERUSALEM', 'Иерусалим', '+3 веры от храмов.',
     '+3 Faith from Temples.', classes=('TEMPLE',), yields={'FAITH': 3})
ally('LA_VENTA', 'Ла-Вента', '+2 веры с обрабатываемых клеток камня.',
     '+2 Faith on worked Stone tiles.', resources=('STONE',), yields={'FAITH': 2})
ally('VANCOUVER', 'Ванкувер', '+3 производства от морских портов.',
     '+3 Production from Seaports.', classes=('SEAPORT',), yields={'PRODUCTION': 3})
ally('MANILA', 'Манила', '+1 золота с обрабатываемых клеток рыбы.',
     '+1 Gold on worked Fish tiles.', resources=('FISH',), yields={'GOLD': 1})
ally('ANTANANARIVO', 'Антананариву', '+2 культуры от рынков и фондовых бирж.',
     '+2 Culture from Markets and Stock Exchanges.', classes=('MARKET', 'STOCK_EXCHANGE'), yields={'CULTURE': 2})
ally('MILAN', 'Милан', '+2 культуры от мастерских.',
     '+2 Culture from Workshops.', classes=('WORKSHOP',), yields={'CULTURE': 2})
ally('MOMBASA', 'Момбаса', '+2 пищи от гаваней.',
     '+2 Food from Harbors.', classes=('HARBOR',), yields={'FOOD': 2})
ally('PRAGUE', 'Прага', '+2 культуры от университетов.',
     '+2 Culture from Universities.', classes=('UNIVERSITY',), yields={'CULTURE': 2})
ally('VALLETTA', 'Валлетта', '+15% производства военных юнитов в городах с оружейной (Armory).',
     '+15% military unit Production in cities with an Armory.', classes=('ARMORY',), fields={'MilitaryProductionModifier': 15})
ally('VATICAN_CITY', 'Ватикан', '+4 веры и +2 культуры в столице.',
     '+4 Faith and +2 Culture in the Capital.', scope='capital', yields={'FAITH': 4, 'CULTURE': 2})
ally('WITTENBERG', 'Виттенберг', '+2 науки от храмов.',
     '+2 Science from Temples.', classes=('TEMPLE',), yields={'SCIENCE': 2})
ally('YEREVAN', 'Ереван', '+2 веры от садов.',
     '+2 Faith from Gardens.', classes=('GARDEN',), yields={'FAITH': 2})
ally('ZANZIBAR', 'Занзибар', '+2 золота с обрабатываемых клеток пряностей и сахара.',
     '+2 Gold on worked Spices and Sugar tiles.', resources=('SPICES', 'SUGAR'), yields={'GOLD': 2})
ally('ZURICH', 'Цюрих', '+10% золота в городах с банком.',
     '+10% Gold in cities with a Bank.', classes=('BANK',), mods={'GOLD': 10})
ally('SAMARKAND', 'Самарканд', '+3 золота от караван-сараев.',
     '+3 Gold from Caravansaries.', classes=('CARAVANSARY',), yields={'GOLD': 3})
ally('MALACCA', 'Малакка', '+4 золота от международных морских торговых путей из городов союзника с учётом морского множителя.',
     '+4 Gold from international sea trade routes originating in the ally\'s cities after the sea modifier.', fields={'TradeRouteSeaGoldBonus': 200})
ally('MOGADISHU', 'Могадишо', '+15% производства морских юнитов ближнего боя.',
     '+15% Production of naval melee units.', unitcombat=('NAVALMELEE',))
ally('BYBLOS', 'Библ', '+2 науки от библиотек.',
     '+2 Science from Libraries.', classes=('LIBRARY',), yields={'SCIENCE': 2})
ally('KYZYL', 'Кызыл', '+1 культуры с обрабатываемых клеток лошадей и овец.',
     '+1 Culture on worked Horse and Sheep tiles.', resources=('HORSE', 'SHEEP'), yields={'CULTURE': 1})
ally('IFE', 'Ифе', '+1 веры за каждое великое произведение в городе.',
     '+1 Faith per Great Work in a city.', scope='works', yields={'FAITH': 1})
ally('KIEV', 'Киев', '+2 пищи от водяных мельниц.',
     '+2 Food from Water Mills.', classes=('WATERMILL',), yields={'FOOD': 2})
ally('BUENOS_AIRES', 'Буэнос-Айрес', '+3 культуры от зоопарков и стадионов.',
     '+3 Culture from Zoos and Stadiums.', classes=('THEATRE', 'STADIUM'), yields={'CULTURE': 3})
ally('MBANZA_KONGO', 'Мбанза-Конго', '+10% производства юнитов ближнего боя и огнестрельной пехоты.',
     '+10% Production of melee and gunpowder infantry units.', unitcombat=('MELEE', 'GUN'))
ally('KABUL', 'Кабул', '+5 опыта новым юнитам за каждую оружейную (Armory) и военную академию в городе.',
     '+5 starting Experience for each Armory and Military Academy in the training city.', classes=('ARMORY', 'MILITARY_ACADEMY'), fields={'Experience': 5})
ally('SOFIA', 'София', '+20% производства осадных юнитов.',
     '+20% Production of siege units.', unitcombat=('SIEGE',))
ally('UR', 'Ур', '+1 производства с обрабатываемых клеток пшеницы.',
     '+1 Production on worked Wheat tiles.', resources=('WHEAT',), yields={'PRODUCTION': 1})
ally('MELBOURNE', 'Мельбурн', '+3 золота от фабрик.',
     '+3 Gold from Factories.', classes=('FACTORY',), yields={'GOLD': 3})
ally('BOGOTA', 'Богота', '+1 культуры за каждые 5 жителей каждого города.',
     '+1 Culture per 5 Citizens in each city.', scope='population', yields={'CULTURE': 1})
ally('VILNIUS', 'Вильнюс', '+2 культуры от храмов.',
     '+2 Culture from Temples.', classes=('TEMPLE',), yields={'CULTURE': 2})
ally('WELLINGTON', 'Веллингтон', '+5% науки в прибрежных городах.',
     '+5% Science in coastal cities.', scope='coast', mods={'SCIENCE': 5})


def quote(value):
    if value is None:
        return 'NULL'
    if isinstance(value, int):
        return str(value)
    return "'" + str(value).replace("'", "''") + "'"


def insert(table, **values):
    return f"INSERT INTO {table} ({','.join(values)}) VALUES ({','.join(map(quote, values.values()))});"


def generate():
    sql = ['-- Generated by tools/systems_content.py. BNW only; no new minor civilizations.',
           'CREATE TABLE Refined_Allies (MinorType TEXT PRIMARY KEY, BuildingType TEXT, Scope TEXT, Help TEXT);',
           'CREATE TABLE Refined_AllyClasses (MinorType TEXT, BuildingClass TEXT);',
           'CREATE TABLE Refined_SocietyCarriers (BuildingType TEXT PRIMARY KEY);']
    root = ET.Element('GameData')
    languages = {lang: ET.SubElement(root, lang) for lang in ['Language_en_US', 'Language_RU_RU']}

    def text(key, en, ru):
        for lang, value in [('Language_en_US', en), ('Language_RU_RU', ru)]:
            ET.SubElement(ET.SubElement(languages[lang], 'Row', Tag=key), 'Text').text = value

    text('TXT_KEY_REFINED_SOCIETY_HIDDEN', 'Refined society effect', 'Эффект институтов и союзов Refined')
    text('TXT_KEY_REFINED_ALLY_GAIN', '{1_Name}: alliance benefit', '{1_Name}: бонус союза')
    text('TXT_KEY_REFINED_ALLY_LOST', '{1_Name}: alliance benefit lost', '{1_Name}: бонус союза утрачен')
    text('TXT_KEY_REFINED_MERCHANT', 'Trade diplomacy', 'Торговая дипломатия')
    text('TXT_KEY_REFINED_MERCHANT_HELP', '+50% Influence from trade missions while Entrepreneurship is active.', '+50% влияния за торговые миссии при действующем Предпринимательстве.')
    text('TXT_KEY_REFINED_SWISS', 'Swiss Guard', 'Швейцарская гвардия')
    text('TXT_KEY_REFINED_SWISS_HELP', 'Purchase-only mercenary infantry. Strength 26, 2 Moves. Requires Mercenary Army and Gunpowder. Can move after purchase; upgrades to Mercenary Foreign Legion.', 'Наёмная пехота, доступная только за золото. Сила 26, 2 хода. Требует Наёмной армии и пороха. Может двигаться после покупки; модернизируется в наёмный иностранный легион.')
    text('TXT_KEY_REFINED_SWISS_PEDIA', 'Swiss mercenary infantry continued the tradition of professional troops serving foreign states. Uses stock Musketman art in this prototype.', 'Швейцарские наёмные пехотные части продолжили традицию профессиональной службы иностранным государствам. В прототипе используется штатная модель мушкетёра.')
    text('TXT_KEY_REFINED_LEGION', 'Mercenary Foreign Legion', 'Наёмный иностранный легион')
    text('TXT_KEY_REFINED_LEGION_HELP', 'Purchase-only infantry. Strength 42, 2 Moves. Requires Mercenary Army and Replaceable Parts. +20% strength outside friendly territory. Can move after purchase; upgrades to Infantry.', 'Пехота, доступная только за золото. Сила 42, 2 хода. Требует Наёмной армии и взаимозаменяемых деталей. +20% силы вне дружественных земель. Может двигаться после покупки; модернизируется в пехоту.')
    text('TXT_KEY_REFINED_LEGION_PEDIA', 'Foreign recruitment supports a standing professional army. Uses stock Foreign Legion art; the original Volunteer Army unit remains separate.', 'Иностранное комплектование позволяет содержать профессиональные военные части. Используется штатная модель иностранного легиона; исходный юнит Добровольческой армии остаётся отдельным.')

    for code, ru, en, replace in POLICY_TEXT:
        key = 'TXT_KEY_REFINED_POLICY_' + code
        text(key, en, ru)
        if code.endswith('_FINISHER'):
            target = f"SELECT Help FROM PolicyBranchTypes WHERE Type={quote('POLICY_BRANCH_' + code[:-9])}"
        else:
            target = f"SELECT Help FROM Policies WHERE Type={quote('POLICY_' + code)}"
        for lang in languages:
            value = f'(SELECT Text FROM {lang} WHERE Tag={quote(key)})'
            if not replace:
                value = "Text || '[NEWLINE][NEWLINE]' || " + value
            sql.append(f'UPDATE {lang} SET Text={value} WHERE Tag=({target});')

    def carrier(name, yields=None, mods=None, fields=None):
        b = 'BUILDING_REFINED_SOCIETY_' + name
        sql.append(insert('Refined_SocietyCarriers', BuildingType=b))
        sql.append(insert('BuildingClasses', Type='BUILDINGCLASS_REFINED_SOCIETY_' + name,
                          DefaultBuilding=b, Description='TXT_KEY_REFINED_SOCIETY_HIDDEN'))
        sql.append(insert('Buildings', Type=b, BuildingClass='BUILDINGCLASS_REFINED_SOCIETY_' + name,
                          Description='TXT_KEY_REFINED_SOCIETY_HIDDEN', Cost=-1, FaithCost=-1,
                          GreatWorkCount=-1, NeverCapture=1, NukeImmune=1, GoldMaintenance=0,
                          ConquestProb=0, MinAreaSize=-1, HurryCostModifier=-1, **(fields or {})))
        for yield_, amount in (yields or {}).items():
            sql.append(insert('Building_YieldChanges', BuildingType=b, YieldType='YIELD_' + yield_, Yield=amount))
        for yield_, amount in (mods or {}).items():
            if yield_ == 'CULTURE':
                sql.append(f'UPDATE Buildings SET CultureRateModifier={amount} WHERE Type={quote(b)};')
            else:
                sql.append(insert('Building_YieldModifiers', BuildingType=b, YieldType='YIELD_' + yield_, Yield=amount))
        return b

    for a in ALLIES:
        key = 'TXT_KEY_REFINED_ALLY_' + a['code']
        text(key, a['en'], a['ru'])
        b = carrier(a['code'], a['yields'] if not a['resources'] else {}, a['mods'], a['fields'])
        sql.append(insert('Refined_Allies', MinorType='MINOR_CIV_' + a['code'], BuildingType=b, Scope=a['scope'], Help=key))
        for cls in a['classes']:
            sql.append(insert('Refined_AllyClasses', MinorType='MINOR_CIV_' + a['code'], BuildingClass='BUILDINGCLASS_' + cls))
        for resource in a['resources']:
            for y, n in a['yields'].items():
                sql.append(insert('Building_ResourceYieldChanges', BuildingType=b, ResourceType='RESOURCE_' + resource, YieldType='YIELD_' + y, Yield=n))
        if a['domainxp']:
            sql.append(insert('Building_DomainFreeExperiences', BuildingType=b, DomainType='DOMAIN_SEA', Experience=a['domainxp']))
        if a['unitcombat']:
            amount = 20 if a['code'] in ['SIDON', 'SOFIA'] else 10 if a['code'] == 'MBANZA_KONGO' else 15
            combat = ','.join(quote('UNITCOMBAT_' + s) for s in a['unitcombat'])
            sql.append(f'INSERT INTO Unit_ProductionModifierBuildings (UnitType,BuildingType,ProductionModifier) SELECT Type,{quote(b)},{amount} FROM Units WHERE CombatClass IN ({combat});')
        # Put the exact benefit in the existing Civilopedia entry, preserving lore.
        for lang in languages:
            sql.append(f"UPDATE {lang} SET Text=Text || '[NEWLINE][NEWLINE]' || (SELECT Text FROM {lang} WHERE Tag={quote(key)}) WHERE Tag=(SELECT Civilopedia FROM MinorCivilizations WHERE Type={quote('MINOR_CIV_' + a['code'])});")

    carrier('COMMERCE_ROUTE', fields={'NumTradeRouteBonus': 1})
    carrier('TRADITION_LATE', yields={'CULTURE': 1})
    carrier('COLLECTION', mods={'CULTURE': 20})
    carrier('TEMPLE_LATE', yields={'CULTURE': 2, 'SCIENCE': 2})
    carrier('ALLIED_CULTURE', yields={'CULTURE': 2})
    navigator = carrier('NAVIGATORS')
    sql.append(insert('Building_DomainFreeExperiences', BuildingType=navigator, DomainType='DOMAIN_SEA', Experience=10))
    arch = carrier('ARCHAEOLOGY')
    sql.append(f"INSERT INTO Unit_ProductionModifierBuildings (UnitType,BuildingType,ProductionModifier) SELECT Type,{quote(arch)},50 FROM Units WHERE Class='UNITCLASS_ARCHAEOLOGIST';")
    (ROOT / 'mod/SQL/Allies.sql').write_text('\n'.join(sql) + '\n')
    ET.indent(root)
    ET.ElementTree(root).write(ROOT / 'mod/Text/Society.xml', encoding='utf-8', xml_declaration=True)
    rows = ['# Уникальные города-государства — v7', '',
            'Полный набор: 58 существующих городов-государств BNW. Новые города не добавляются. Числа — стартовый баланс агента в рамках поручения от 29 октября 2026 года; фиксированные 10 золота Сингапура выбраны пользователем отдельно.', '',
            'Бонус дополняет штатные награды дружбы и союза. Доступен только текущему союзнику; постоянный эффект снимается при потере союза. Уже полученные доходы и опыт сохраняются. Уникальные замены зданий учитываются по классу. Ресурсные бонусы собираются только при обычной обработке клетки жителем; улучшение отдельно не требуется.', '',
            '| Город-государство | Уникальный бонус союзнику |', '| --- | --- |']
    rows += [f"| {a['name']} | {a['ru']} |" for a in sorted(ALLIES, key=lambda a: a['name'])]
    rows += ['', 'Эффекты видны в существующих статьях Civilopedia и в уведомлении о получении союза. Отдельного экрана нет. Исчезновение союза снимает постоянные эффекты, а не построенные объекты и накопленные награды.', '',
             'Сингапур: по решению пользователя прежние 25 × (индекс эпохи + 1) заменены фиксированными 10 золота за новый Type технологии на стандартной скорости. Эпоха больше не влияет на награду. Для других скоростей применяется ResearchPercent с округлением вниз. При одном открытии за 10 ходов это в среднем +1 золота/ход на стандартной скорости. Старые технологии, загрузка и повторное событие награды не дают; получатель — текущий союзник, не вся его команда. Повторяемая технология будущего вознаграждается один раз за её Type.', '',
             'Статус проверки указывается в спецификации. Источник состава и стандартных полей: публичный справочный [снимок BNW civvapi](https://github.com/Eyefyre/civvapi/blob/master/Civ5DebugDatabase.db); это не база установленной игры.']
    (ROOT / 'docs/city-states.md').write_text('\n'.join(rows) + '\n')


if __name__ == '__main__':
    generate()
