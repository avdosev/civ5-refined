# Локальная сборка

Полное интерактивное [дерево технологий](../../dev-utils/tech-tree.html) с текущими правками открывается в браузере без сервера. Есть поиск, масштаб и подсветка зависимостей. После изменения SQL обновляйте его командой `python3 dev-utils/tech_tree.py`; [описание и источники данных](../../dev-utils/README.md).

Команды выполняются из корня репозитория.

Исходники пакета — `mod/`. Сборка готовой папки и ZIP не требует ModBuddy:

```sh
python3 tools/build.py
python3 tests/validate.py
python3 tests/run_lua.py --lua lua5.1
python3 tests/society.py --lua lua5.1
python3 tests/victories.py --lua lua5.1
python3 tests/victory_timing.py
```

Команды run_lua.py, society.py и victories.py требуют Lua 5.1 (можно передать путь через --lua). victories.py применяет полный стек SQL v8 к фактической проекции BNW, проверяет 94 технологии и геометрию штатных соединений, затем запускает реальный Victories.lua с моделью API. Дополнение tests/data/bnw-victories.json содержит схему и механические параметры проектов/процессов из того же публичного снимка, что bnw-society.json; это не установленная игра. victory_timing.py проверяет отдельно условную модель темпа. SQLite-проверка validate.py сохраняет проверки прежних механик на представительном наборе. Если доступна чистая игровая база:

```sh
python3 tests/validate.py --database /path/to/Civ5DebugDatabase.db
```

Файл базы открывается только для чтения; изменения проверяются на копии в памяти. Пакет создаётся в `dist/`. Концепция и текущий баланс описаны в `spec.md`; обсуждение и решения ведём в чате.
