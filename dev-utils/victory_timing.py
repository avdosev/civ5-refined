#!/usr/bin/env python3
"""Illustrative victory schedules, not an engine simulation or measured balance.

Run from anywhere; uses current SQL technology graph via tech_tree.generate().
New nodes, costs and assumptions are proposals, not changes to mod/.
Version 2: explicit 6-8 cities, city penalty includes the first city.
"""
import argparse
import itertools
import json
import math
from tech_tree import generate

NODES = {n['id'].removeprefix('TECH_'): n for n in generate()['nodes']}
PARENTS = {k: [p.removeprefix('TECH_') for p in v['parents']] for k, v in NODES.items()}
COST = {k: v['cost'] for k, v in NODES.items()}
# Common late-game frontier: every current technology through column 15.
KNOWN = {k for k, v in NODES.items() if v['x'] <= 15}
PROPOSED = {
    'ORBITAL': (9500, ['SATELLITES', 'ROBOTICS']),
    'ENGINES': (11000, ['PARTICLE_PHYSICS', 'NUCLEAR_FUSION']),
    'AUTONOMOUS': (9500, ['ROBOTICS', 'SATELLITES']),
    'BIOTECH': (8800, ['ECOLOGY', 'PENICILIN']),
    'BIOSYSTEMS': (11000, ['BIOTECH']),
    'ADVANCED_COMPUTING': (8400, ['REFINED_AI']),
    'GENERAL_AI': (9500, ['ADVANCED_COMPUTING']),
    'RECURSIVE': (10000, ['GENERAL_AI']),
}
for key, (cost, parents) in PROPOSED.items():
    COST[key], PARENTS[key] = cost, parents

# Standard snapshot: ResearchPercent=110; +5% per effective city INCLUDING the first.
# City count is explicit in each calculation; never inferred from science income.
def research_factor(city_count):
    if city_count < 1:
        raise ValueError('city_count must be positive')
    return round(1.10 * (1 + .05 * city_count), 3)


def research_cost(tech, city_count):
    # BNW: integer world scaling, then city scaling and ceiling player cost.
    world_cost = COST[tech] * 110 // 100
    return (world_cost * (100 + 5 * city_count) + 99) // 100


MARS_COSTS = (900, 1400, 1800, 2400)
TRAINING_GOAL = 13666  # User-selected symbolic final-learning goal.


def orders(targets):
    """Try every priority permutation of main goals, prerequisites by DFS.

    This is a bounded queue comparison, not exhaustive global optimisation.
    """
    found = set()
    for priority in itertools.permutations(targets):
        done, queue = set(KNOWN), []
        def add(key):
            if key in done:
                return
            for parent in PARENTS[key]:
                add(parent)
            done.add(key)
            queue.append(key)
        for target in priority:
            add(target)
        found.add(tuple(queue))
    return sorted(found)


def normalized_profiles(city_count):
    """Same top-three cities as history; other cities now have explicit production.

    All cities may build. Science is equally distributed as a controlled assumption.
    Secondary-city production is a scenario, not a measured BNW baseline.
    """
    if not 6 <= city_count <= 8:
        raise ValueError('Current baseline covers 6 to 8 cities')
    secondary = [.40, .32, .24, .16, .12][:city_count - 3]
    return {
        f's{science}_p{label}': (science, top + [round(top[0] * x) for x in secondary])
        for science in (800, 1000, 1200)
        for label, top in [('low', [60, 45, 35]), ('normal', [100, 75, 55]),
                           ('high', [160, 120, 90])]
    }


def center_science_bonus(science, city_count=7):
    # Equal initial science shares; +4 centre and +3 lab from technology bonuses.
    return .25 * (science / 2.25 / city_count + 7) + 10 * 2.65


def ordinary_science(science, city_count=7):
    return (science + city_count * 4 * 2.25
            + (science / 2.25 + city_count * 4) * .15 + city_count * 3 * 2.4)


def learning_city_science(science, city_count=7):
    per_city = ordinary_science(science, city_count) / city_count
    return [per_city + center_science_bonus(science, city_count)] + [per_city] * (city_count - 1)


def research(queue, science, center_production=None, city_count=7):
    dates, overflow, turn = {k: 0 for k in sorted(KNOWN)}, 0., 0
    for key in queue:
        need = research_cost(key, city_count)
        first_turn = True
        while first_turn or overflow < need:
            first_turn = False
            rate = science
            if 'REFINED_MICROELECTRONICS' in dates:
                rate += city_count * 4 * 2.25  # +4 per centre, +125% city modifiers
            if 'REFINED_AI' in dates:
                # +15 percentage points on city base and +3 base per lab.
                rate += (science / 2.25 + city_count * 4) * .15 + city_count * 3 * 2.4
            if center_production and 'ADVANCED_COMPUTING' in dates:
                center_end = dates['ADVANCED_COMPUTING'] + math.ceil(1200 / (center_production * 1.6))
                if turn >= center_end:
                    # Equal science shares. Local +25pp and +10 base.
                    rate += center_science_bonus(science, city_count)
            overflow += rate
            turn += 1
        overflow -= need
        dates[key] = turn
    return dates


def schedule(queue, science, production, mars=False, advanced=False,
             factory=False, yard=False, transfer=2, city_count=7, yard_bonus=.2):
    dates = research(queue, science, city_count=city_count)
    done, busy, log = {}, [None] * len(production), []
    structures = [set() for _ in production]
    tasks = ([('recon', MARS_COSTS[0], 'AUTONOMOUS'), ('transport', MARS_COSTS[1], 'ORBITAL'),
              ('habitat', MARS_COSTS[2], 'BIOSYSTEMS'), ('colony', MARS_COSTS[3], 'REFINED_AI')] if mars else
             [('apollo', 750, None), ('engine', 1500, 'ENGINES' if advanced else 'PARTICLE_PHYSICS'),
              ('stasis', 1500, 'NANOTECHNOLOGY'),
              ('booster1', 1500, 'ADVANCED_BALLISTICS'),
              ('booster2', 1500, 'ADVANCED_BALLISTICS'),
              ('booster3', 1500, 'ADVANCED_BALLISTICS'),
              ('cockpit', 1500, 'SATELLITES')])
    started = set()
    for turn in range(1, 1001):
        for city, job in enumerate(busy):
            if job and job[1] < turn:
                key, finish = job
                done[key] = finish
                if key.startswith('factory'):
                    structures[city].add('factory')
                if key.startswith('yard'):
                    structures[city].add('yard')
                busy[city] = None
        if all(k in done for k, _, _ in tasks):
            # Capital parts need one assembly turn; other cities travel + assembly.
            victory = max(end + (0 if mars or k == 'apollo' else (1 if c == 0 else transfer + 1))
                          for k, c, _, end in log if k in {t[0] for t in tasks})
            yards = {c: finish for key, c, _, finish in log if key.startswith('yard')}
            part_names = {'engine', 'stasis', 'booster1', 'booster2', 'booster3', 'cockpit'}
            yard_used = any(key in part_names and c in yards and start > yards[c]
                            for key, c, start, _ in log)
            return dict(turn=victory, research_end=max(dates.values()),
                        queue=list(queue), dates=dates, builds=log,
                        factory=factory, yard=yard, yard_used=yard_used, yard_bonus=yard_bonus)
        for city, base in enumerate(production):
            if busy[city]:
                continue
            available = []
            for index, (key, cost, tech) in enumerate(tasks):
                if key in started or (tech and dates.get(tech, 10000) >= turn):
                    continue
                if mars and index and tasks[index-1][0] not in done:
                    continue
                if not mars and key != 'apollo' and 'apollo' not in done:
                    continue
                available.append((key, cost, key != 'apollo' and not mars))
            # Optional preparation in idle cities; include its real time cost.
            if not mars:
                if factory and 'factory' not in structures[city] and dates.get('ROBOTICS', 10000) < turn:
                    available.insert(0, ('factory'+str(city), 360, False))
                elif yard and 'yard' not in structures[city] and dates.get('ORBITAL', 10000) < turn:
                    available.insert(0, ('yard'+str(city), 500, False))
            if not available:
                continue
            key, cost, part = available[0]
            modifier = 1.4
            if dates.get('REFINED_AUTOMATION', 10000) < turn:
                modifier += .1
            if dates.get('REFINED_AI', 10000) < turn:
                modifier += .1
            if part:
                modifier += .5 * ('factory' in structures[city]) + yard_bonus * ('yard' in structures[city])
            finish = turn + math.ceil(cost / (base * modifier)) - 1
            # Rate frozen during each order; no production overflow in this model.
            busy[city] = key, finish
            started.add(key)
            log.append((key, city, turn, finish))
    raise RuntimeError('Unfinished schedule')


def singularity(science, production, training_goal=TRAINING_GOAL, city_count=7):
    """One national centre, one national project, then empire-wide process.

    Numbers are a proposal; all participating cities already have data centres.
    Production builds the centre/project, with +40%, automation +10pp and AI +10pp.
    Training uses ordinary local science from all city_count participating cities. The 13666
    goal replaces the proposed 13800; technology prices are separate parameters.
    """
    candidates = []
    for queue in orders(['ROBOTICS', 'TELECOM', 'RECURSIVE']):
        dates = research(queue, science, center_production=production[0], city_count=city_count)
        center_end = dates['ADVANCED_COMPUTING'] + math.ceil(1200 / (production[0] * 1.6))
        project_start = max(dates['GENERAL_AI'], center_end) + 1
        project_end = project_start + math.ceil(1000 / (production[0] * 1.6)) - 1
        start = max(dates['RECURSIVE'], project_end) + 1
        city_science = learning_city_science(science, city_count)
        rate = sum(city_science)
        duration = math.ceil(training_goal / rate)
        candidates.append(dict(turn=start + duration - 1, research_end=max(dates.values()),
                               queue=list(queue), dates=dates, training_rate=rate,
                               training_goal=training_goal, training_basis='city_science',
                               participating_city_science=city_science,
                               training_turns=duration,
                               builds=[('supercomputer', 0, dates['ADVANCED_COMPUTING'] + 1, center_end),
                                       ('universal_ai', 0, project_start, project_end)],
                               training_start=start))
    return min(candidates, key=lambda x: x['turn'])


def compare(tuned=False, profiles=None, city_count=7, yard_bonus=.2, require_yard=False):
    global MARS_COSTS
    for key, (cost, parents) in PROPOSED.items():
        COST[key], PARENTS[key] = cost, parents
    MARS_COSTS = (900, 1400, 1800, 2400)
    if tuned:
        # Candidate for the user's target: Mars a few turns before Alpha.
        # Closed biosystems itself represents biotechnology; no extra tech tax.
        COST.update(AUTONOMOUS=6000, ORBITAL=6000, BIOSYSTEMS=7000)
        PARENTS.update(AUTONOMOUS=['SATELLITES', 'COMPUTERS'],
                       ORBITAL=['SATELLITES'], BIOSYSTEMS=['ECOLOGY'])
        MARS_COSTS = (500, 600, 800, 1000)
    result = {}
    for profile, (science, production) in (normalized_profiles(city_count) if profiles is None else profiles).items():
        outcomes = {}
        for route in ['v7', 'alpha', 'mars']:
            best = None
            for ai in ([False, True] if route != 'mars' else [True]):
                for yard in ([False, True] if route == 'alpha' else [False]):
                    if route == 'alpha' and require_yard and not yard:
                        continue
                    targets = (['AUTONOMOUS', 'ORBITAL', 'BIOSYSTEMS', 'REFINED_AI'] if route == 'mars' else
                               ['ADVANCED_BALLISTICS', 'SATELLITES', 'NANOTECHNOLOGY',
                                'ENGINES' if route == 'alpha' else 'PARTICLE_PHYSICS'])
                    if ai and route != 'mars':
                        targets += ['REFINED_AI']
                    if yard:
                        targets += ['ORBITAL']
                    for queue in orders(targets):
                        for factory in ([False, True] if route != 'mars' else [False]):
                            attempt = schedule(queue, science, production, mars=route == 'mars',
                                               advanced=route == 'alpha', factory=factory, yard=yard,
                                               city_count=city_count, yard_bonus=yard_bonus)
                            if route == 'alpha' and require_yard and not attempt['yard_used']:
                                continue
                            if best is None or attempt['turn'] < best['turn']:
                                best = attempt
            outcomes[route] = best
        outcomes['singularity'] = singularity(science, production, city_count=city_count)
        result[profile] = outcomes
    return result


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--normalized', action='store_true',
                        help='Current default; 800/1000/1200 science with three industry levels')
    parser.add_argument('--cities', type=int, default=7, choices=(6, 7, 8),
                        help='Empire city count, default 7')
    parser.add_argument('--yard-bonus', type=int, choices=(20, 50), default=20,
                        help='Compare proposed local ship-part bonus, default 20 percent')
    parser.add_argument('--require-yard', action='store_true',
                        help='Alpha must actually build a part in a city with a completed yard')
    args = parser.parse_args()
    profiles = normalized_profiles(args.cities)
    outcomes = compare(tuned=True, profiles=profiles, city_count=args.cities,
                       yard_bonus=args.yard_bonus / 100, require_yard=args.require_yard)
    result = dict(parameters=dict(model_version=2, city_count=args.cities,
                                  research_factor=research_factor(args.cities),
                                  effective_cities_assumed_equal_current_cities=True,
                                  science_is_total_empire_income=True,
                                  participating_training_cities=args.cities,
                                  historical=False,
                                  yard_bonus_percent=args.yard_bonus, require_actual_yard=args.require_yard,
                                  training_goal=TRAINING_GOAL,
                                  data_centres=args.cities, laboratories=args.cities,
                                  local_science_multiplier=2.25,
                                  science_distribution='equal shares before national centre',
                                  population_growth=False,
                                  technology_costs={key: COST[key] for key in PROPOSED},
                                  common_known_technologies=sorted(KNOWN)),
                  profiles=profiles,
                  mars_faster_candidate=outcomes)
    print(json.dumps(result, ensure_ascii=False, indent=2))
