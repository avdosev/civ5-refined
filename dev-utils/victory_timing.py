#!/usr/bin/env python3
"""Illustrative victory schedules, not an engine simulation or measured balance.

Run from anywhere; uses current SQL technology graph via tech_tree.generate().
New nodes, costs and assumptions are proposals, not changes to mod/.
"""
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
    'ADVANCED_COMPUTING': (7700, ['REFINED_AI']),
    'GENERAL_AI': (8800, ['ADVANCED_COMPUTING']),
    'RECURSIVE': (9500, ['GENERAL_AI']),
}
for key, (cost, parents) in PROPOSED.items():
    COST[key], PARENTS[key] = cost, parents

# Standard world ResearchPercent=110; 4 cities, +5% per extra city.
RESEARCH_FACTOR = 1.10 * 1.15
# P is production before ordinary +40% city modifiers; specialised modifiers add.
MARS_COSTS = (900, 1400, 1800, 2400)
PROFILES = {
    'balanced': (1100, [100, 75, 55]),
    'science': (1800, [60, 45, 35]),
    'industry': (850, [160, 120, 90]),
}


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


def research(queue, science, center_production=None):
    dates, overflow, turn = {k: 0 for k in KNOWN}, 0., 0
    for key in queue:
        need = math.ceil(COST[key] * RESEARCH_FACTOR)
        first_turn = True
        while first_turn or overflow < need:
            first_turn = False
            rate = science
            if 'REFINED_MICROELECTRONICS' in dates:
                rate += 4 * 4 * 2.25  # four centres, +4 base science, +125% mods
            if 'REFINED_AI' in dates:
                # +15 percentage points on city base and +3 base per lab.
                rate += (science / 2.25 + 16) * .15 + 4 * 3 * 2.4
            if center_production and 'ADVANCED_COMPUTING' in dates:
                center_end = dates['ADVANCED_COMPUTING'] + math.ceil(1200 / (center_production * 1.6))
                if turn >= center_end:
                    # Equal science shares across four cities. Local +25pp and +10 base.
                    rate += .25 * (science / 2.25 / 4 + 7) + 10 * 2.65
            overflow += rate
            turn += 1
        overflow -= need
        dates[key] = turn
    return dates


def schedule(queue, science, production, mars=False, advanced=False,
             factory=False, yard=False, transfer=2):
    dates = research(queue, science)
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
            return dict(turn=victory, research_end=max(dates.values()),
                        queue=list(queue), dates=dates, builds=log,
                        factory=factory, yard=yard)
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
                modifier += .5 * ('factory' in structures[city]) + .2 * ('yard' in structures[city])
            finish = turn + math.ceil(cost / (base * modifier)) - 1
            # Rate frozen during each order; no production overflow in this model.
            busy[city] = key, finish
            started.add(key)
            log.append((key, city, turn, finish))
    raise RuntimeError('Unfinished schedule')


def singularity(science, production):
    """One national centre, one national project, then empire-wide process.

    Numbers are a proposal; all participating cities already have data centres.
    Ordinary production continues to use +40%, automation +10pp and AI +10pp.
    """
    candidates = []
    for queue in orders(['ROBOTICS', 'TELECOM', 'RECURSIVE']):
        dates = research(queue, science, center_production=production[0])
        center_end = dates['ADVANCED_COMPUTING'] + math.ceil(1200 / (production[0] * 1.6))
        project_start = max(dates['GENERAL_AI'], center_end) + 1
        project_end = project_start + math.ceil(1000 / (production[0] * 1.6)) - 1
        start = max(dates['RECURSIVE'], project_end) + 1
        rate = sum(production) * 1.6
        duration = math.ceil(3000 / rate)
        candidates.append(dict(turn=start + duration - 1, research_end=max(dates.values()),
                               queue=list(queue), dates=dates, training_rate=rate,
                               training_turns=duration,
                               builds=[('supercomputer', 0, dates['ADVANCED_COMPUTING'] + 1, center_end),
                                       ('universal_ai', 0, project_start, project_end)],
                               training_start=start))
    return min(candidates, key=lambda x: x['turn'])


def compare(tuned=False):
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
        MARS_COSTS = (400, 600, 800, 1000)
    result = {}
    for profile, (science, production) in PROFILES.items():
        outcomes = {}
        for route in ['v7', 'alpha', 'mars']:
            best = None
            for ai in ([False, True] if route != 'mars' else [True]):
                for yard in ([False, True] if route == 'alpha' else [False]):
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
                                               advanced=route == 'alpha', factory=factory, yard=yard)
                            if best is None or attempt['turn'] < best['turn']:
                                best = attempt
            outcomes[route] = best
        outcomes['singularity'] = singularity(science, production)
        result[profile] = outcomes
    return result


if __name__ == '__main__':
    print(json.dumps({'initial': compare(), 'mars_faster_candidate': compare(tuned=True)},
                     ensure_ascii=False, indent=2))
