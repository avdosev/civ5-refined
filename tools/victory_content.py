#!/usr/bin/env python3
"""Author-owned RU/EN text for the three BNW science routes. No copied prose."""
from pathlib import Path
import xml.etree.ElementTree as ET

ROOT = Path(__file__).resolve().parents[1]
TEXT = {}


def entry(key, ru, en, help_ru, help_en, pedia_ru=None, pedia_en=None):
    TEXT[key] = (ru, en)
    TEXT[key + '_HELP'] = (help_ru, help_en)
    TEXT[key + '_PEDIA'] = (pedia_ru or help_ru, pedia_en or help_en)


entry('TECH_REFINED_ORBITAL', 'Орбитальная инфраструктура', 'Orbital Infrastructure',
      'Открывает орбитальную верфь (+20% производства частей корабля) и проект орбитальной транспортной системы для колонизации Марса.',
      'Unlocks the Orbital Shipyard (+20% spaceship part Production) and the Orbital Transport System project for Mars colonization.')
entry('TECH_REFINED_AUTONOMOUS', 'Автономные космические системы', 'Autonomous Space Systems',
      'Открывает проект автоматической разведки Марса — первый этап марсианского пути к научной победе.',
      'Unlocks Automated Mars Reconnaissance, the first project of the Mars science victory route.',
      'Зонды и автономные аппараты исследуют опасную среду без постоянного управления с Земли. Такая ограниченная автономность не требует общего искусственного интеллекта.',
      'Probes and autonomous vehicles explore hazardous environments without continuous control from Earth. Such limited autonomy does not require general artificial intelligence.')
entry('TECH_REFINED_BIOSYSTEMS', 'Замкнутые биосистемы', 'Closed Biosystems',
      'Открывает проект марсианского жилого комплекса.', 'Unlocks the Mars Habitat project.',
      'Прикладная биотехнология позволяет повторно использовать воду, поддерживать состав атмосферы и выращивать пищу в ограниченном объёме обитаемой среды.',
      'Applied biotechnology recycles water, maintains atmospheric composition and grows food within a limited inhabited environment.')
entry('TECH_REFINED_ENGINES', 'Перспективные двигатели', 'Advanced Propulsion',
      'Открывает двигатель межзвёздного корабля. Требует физику элементарных частиц и ядерный синтез.',
      'Unlocks the interstellar spaceship engine. Requires Particle Physics and Nuclear Fusion.')
entry('TECH_REFINED_ADVANCED_COMPUTING', 'Передовые вычислительные системы', 'Advanced Computing Systems',
      'Открывает национальный суперкомпьютерный центр. Для строительства нужен дата-центр в этом городе.',
      'Unlocks the national Supercomputer Center. Requires a Data Center in its city.')
entry('TECH_REFINED_GENERAL_AI', 'Общий искусственный интеллект', 'Artificial General Intelligence',
      'Открывает национальный проект «Универсальный ИИ». Для его выполнения нужен действующий суперкомпьютерный центр.',
      'Unlocks the national Universal AI project. Requires an operational Supercomputer Center.',
      'Гипотетическая система широких интеллектуальных возможностей выходит за пределы отдельных прикладных задач. Общий ИИ сам по себе ещё не означает технологическую сингулярность.',
      'A hypothetical system with broad intellectual capabilities goes beyond individual applied tasks. General AI alone does not constitute a technological singularity.')
entry('TECH_REFINED_RECURSIVE', 'Рекурсивное самоусовершенствование', 'Recursive Self-improvement',
      'После завершения «Универсального ИИ» позволяет выбрать «Рекурсивное обучение» в городах с дата-центрами. Наука этих городов создаёт общий прогресс к научной победе.',
      'After Universal AI is completed, cities with Data Centers may run Recursive Learning. Their Science contributes to shared progress toward a science victory.',
      'Это гипотетический рубеж: система способна самостоятельно совершенствовать собственные интеллектуальные способности. Его достижение не предполагается неизбежным следствием развития современного ИИ.',
      'This is a hypothetical threshold: a system can improve its own intellectual capabilities. It is not assumed to be an inevitable consequence of developing contemporary AI.')
entry('TECH_REFINED_NETWORK_WAR', 'Сетецентрическая война', 'Network-centric Warfare',
      'Открывает чудо «Центр боевого управления», дающее боевым частям +1 обзора и +10% боевой силы.',
      'Unlocks the Battle Command Center wonder, granting combat units +1 Sight and +10% combat strength.')
for key in list(TEXT):
    if key.startswith('TECH_') and not key.endswith(('_HELP', '_PEDIA')):
        TEXT[key + '_QUOTE'] = ('Новые знания открывают новые возможности.', 'New knowledge opens new possibilities.')

entry('BUILDING_REFINED_ORBITAL_YARD', 'Орбитальная верфь', 'Orbital Shipyard',
      '+20% [ICON_PRODUCTION] производства частей корабля в этом городе. Складывается с космическим заводом. Содержание: 4 [ICON_GOLD].',
      '+20% [ICON_PRODUCTION] spaceship part Production in this city. Adds to the Spaceship Factory bonus. Maintenance: 4 [ICON_GOLD].')
entry('BUILDING_REFINED_SUPERCOMPUTER', 'Суперкомпьютерный центр', 'Supercomputer Center',
      'Национальный объект: один на державу. +10 [ICON_RESEARCH] науки и +25% науки города. Содержание: 20 [ICON_GOLD]. Требует местный дата-центр. Обеспечивает работу «Универсального ИИ» и «Рекурсивного обучения»; при потере центра обучение останавливается до восстановления.',
      'National facility: one per civilization. +10 [ICON_RESEARCH] Science and +25% city Science. Maintenance: 20 [ICON_GOLD]. Requires a local Data Center. Enables Universal AI and Recursive Learning; losing the center pauses learning until it is restored.')
entry('BUILDING_REFINED_BATTLE_COMMAND', 'Центр боевого управления', 'Battle Command Center',
      'Мировое чудо. Требует дата-центр в этом городе. Все существующие и новые обычные боевые части получают «Единую систему управления»: +1 обзора и +10% боевой силы. При потере чуда повышение снимается у прежнего владельца и действует у нового. Содержание отсутствует.',
      'World Wonder. Requires a Data Center in this city. All existing and new conventional combat units gain Integrated Command: +1 Sight and +10% combat strength. Losing the wonder removes the promotion from its former owner and grants it to the new owner. No maintenance.')
entry('PROJECT_REFINED_MARS_RECON', 'Автоматическая разведка Марса', 'Automated Mars Reconnaissance',
      'Первый из четырёх последовательных проектов колонизации Марса. Программа «Аполлон» не требуется.',
      'The first of four sequential Mars colonization projects. Does not require the Apollo Program.')
entry('PROJECT_REFINED_MARS_TRANSPORT', 'Орбитальная транспортная система', 'Orbital Transport System',
      'Второй этап колонизации Марса. Требует завершённую автоматическую разведку Марса.',
      'The second Mars colonization stage. Requires completed Automated Mars Reconnaissance.')
entry('PROJECT_REFINED_MARS_HABITAT', 'Марсианский жилой комплекс', 'Mars Habitat',
      'Третий этап колонизации Марса. Требует завершённую орбитальную транспортную систему.',
      'The third Mars colonization stage. Requires a completed Orbital Transport System.')
entry('PROJECT_REFINED_MARS_COLONY', 'Самодостаточная колония', 'Self-sufficient Colony',
      'Завершает научную победу через колонизацию Марса. Требует предыдущие три проекта, прикладной ИИ и дата-центр в строящем городе.',
      'Completes a science victory through Mars colonization. Requires the preceding three projects, Applied AI and a Data Center in the producing city.')
entry('PROJECT_REFINED_UNIVERSAL_AI', 'Универсальный ИИ', 'Universal AI',
      'Национальный проект. Требует общий ИИ и действующий суперкомпьютерный центр. Вместе с рекурсивным самоусовершенствованием открывает обучение; сам по себе победы не даёт.',
      'National project. Requires General AI and an operational Supercomputer Center. Together with Recursive Self-improvement, unlocks learning; does not itself grant victory.')
entry('PROCESS_REFINED_LEARNING', 'Рекурсивное обучение', 'Recursive Learning',
      'Очередь производства занята обучением; здания и части не строятся. Обычная наука города одновременно идёт в исследования и создаёт прогресс обучения 1:1. Требуются местный дата-центр, суперкомпьютерный центр державы, «Универсальный ИИ» и рекурсивное самоусовершенствование. Цель — 13 666 прогресса на стандартной скорости; скорость игры изменяет порог. Переключение заказа сохраняет накопленное.',
      'The production queue is occupied by learning; no buildings or units are produced. Normal city Science both continues research and contributes learning progress at 1:1. Requires a local Data Center, an operational national Supercomputer Center, Universal AI and Recursive Self-improvement. Goal: 13,666 progress on Standard speed, scaled by game speed. Switching orders preserves accumulated progress.')
entry('PROMOTION_REFINED_NETWORK_COMMAND', 'Единая система управления', 'Integrated Command',
      '+1 обзора и +10% боевой силы в ближнем и дальнем бою против городов и юнитов, при атаке и защите. Дальность огня не увеличивается. Действует, пока держава владеет Центром боевого управления.',
      '+1 Sight and +10% combat strength in melee and ranged combat against cities and units, when attacking or defending. Does not increase attack range. Active while the civilization owns the Battle Command Center.')

TEXT.update({
 'VICTORY_PANEL': ('Научные программы', 'Science programs'),
 'VICTORY_LINE': ('Марс: {1_Num}/4   •   Сингулярность: {2_Num}%', 'Mars: {1_Num}/4   •   Singularity: {2_Num}%'),
 'VICTORY_RATE': ('[ICON_RESEARCH] +{1_Num}/ход   •   {2_Num}/{3_Num}', '[ICON_RESEARCH] +{1_Num}/turn   •   {2_Num}/{3_Num}'),
 'VICTORY_TOOLTIP': ('Три пути дают одну научную победу: межзвёздный корабль, Марс или технологическая сингулярность.[NEWLINE][NEWLINE]Марсианские проекты: {1_Num}/4.[NEWLINE]Обучение: {2_Num}/{3_Num}.[NEWLINE]Текущий вклад городов: {4_Num}/ход.[NEWLINE]{5_Text}',
                     'Three routes grant the same science victory: interstellar spaceship, Mars, or technological singularity.[NEWLINE][NEWLINE]Mars projects: {1_Num}/4.[NEWLINE]Learning: {2_Num}/{3_Num}.[NEWLINE]Current city contribution: {4_Num}/turn.[NEWLINE]{5_Text}'),
 'VICTORY_CITY_RATE': ('{1_Name}: {2_Num}', '{1_Name}: {2_Num}'),
 'VICTORY_BLOCKED': ('Для обучения нужны рекурсивное самоусовершенствование, завершённый «Универсальный ИИ» и действующий суперкомпьютерный центр. Выберите процесс в городах с дата-центрами.',
                     'Learning requires Recursive Self-improvement, completed Universal AI and an operational Supercomputer Center. Select the process in cities with Data Centers.'),
 'VICTORY_MARS_WON': ('Основана самодостаточная колония на Марсе. Достигнута научная победа.', 'A self-sufficient colony has been established on Mars. Science victory achieved.'),
 'VICTORY_SINGULARITY_WON': ('Достигнута технологическая сингулярность. Достигнута научная победа.', 'Technological singularity has been achieved. Science victory achieved.'),
 'VICTORY_TITLE': ('Научная победа', 'Science victory'),
})


def generate():
    root = ET.Element('GameData')
    for index, language in enumerate(('Language_RU_RU', 'Language_en_US')):
        lang = ET.SubElement(root, language)
        for key, values in TEXT.items():
            tag = 'TXT_KEY_' + key if key.startswith(('TECH_', 'BUILDING_', 'PROJECT_', 'PROCESS_', 'PROMOTION_')) else 'TXT_KEY_REFINED_' + key
            ET.SubElement(ET.SubElement(lang, 'Row', Tag=tag), 'Text').text = values[index]
    ET.indent(root)
    ET.ElementTree(root).write(ROOT / 'mod/Text/Victories.xml', encoding='utf-8', xml_declaration=True)


if __name__ == '__main__':
    generate()
