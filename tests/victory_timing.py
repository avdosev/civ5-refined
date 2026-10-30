#!/usr/bin/env python3
"""Regression checks for the planning model, not tests of the Civ V engine."""
import math
from pathlib import Path
import sys

sys.path.insert(0, str(Path(__file__).resolve().parents[1] / 'dev-utils'))
import victory_timing as model

# Independent arithmetic from the inspected BNW formula. Includes the first city.
assert model.research_cost('REFINED_MICROELECTRONICS', 1) == 8085
assert model.research_cost('REFINED_MICROELECTRONICS', 7) == 10395
assert model.research_cost('REFINED_AGRICULTURAL_MECHANIZATION', 7) == 3490
assert model.research_factor(7) == 1.485
assert model.TRAINING_GOAL == 13666
assert [model.COST[k] for k in ('ADVANCED_COMPUTING', 'GENERAL_AI', 'RECURSIVE')] == [8400, 9500, 10000]
for before, after in zip((7700, 8800, 9500), (8400, 9500, 10000)):
    assert 1.05 <= after / before <= 1.10 and after % 100 == 0

# V2 reference: seven cities, science=1000, symbolic final goal 13666; rounded research increases within 5-10%.
reference = {'s1000_plow': (120, 117, 113),
             's1000_pnormal': (115, 111, 112),
             's1000_phigh': (112, 107, 112)}
for count in (6, 7, 8):
    profiles = model.normalized_profiles(count)
    outcomes = model.compare(tuned=True, profiles=profiles, city_count=count)
    assert all(len(production) == count for _, production in profiles.values())
    for profile, routes in outcomes.items():
        for route, result in routes.items():
            dates = result['dates']
            for tech in result['queue']:
                assert all(dates[p] < dates[tech] for p in model.PARENTS[tech])
            for city in range(count):
                jobs = sorted((j for j in result['builds'] if j[1] == city), key=lambda j: j[2])
                assert all(a[3] < b[2] for a, b in zip(jobs, jobs[1:]))
            if route == 'mars':
                assert result['builds'][-1][2] > dates['REFINED_AI']
                assert all(a[3] < b[2] for a, b in zip(result['builds'], result['builds'][1:]))
            if route == 'singularity':
                assert len(result['participating_city_science']) == count
                assert result['training_start'] > max(dates['RECURSIVE'], result['builds'][-1][3])
                assert result['training_turns'] == math.ceil(13666 / result['training_rate'])
                assert math.isclose(result['training_rate'], sum(result['participating_city_science']))
        if count == 7 and profile in reference:
            assert tuple(routes[r]['turn'] for r in ('alpha', 'mars', 'singularity')) == reference[profile]

assert model.MARS_COSTS == (500, 600, 800, 1000)

# More factories can change preparation, but cannot directly change training speed.
slow = model.singularity(1000, [60, 45, 35, 24, 19, 14, 10], city_count=7)
fast = model.singularity(1000, [160, 120, 90, 64, 51, 38, 26], city_count=7)
assert slow['training_rate'] == fast['training_rate']

# A requested building strategy is not evidence that a part received its bonus.
profile = {'reference': model.normalized_profiles(7)['s1000_pnormal']}
base = model.compare(tuned=True, profiles=profile, city_count=7)['reference']['alpha']
unused = model.schedule(base['queue'] + ['ORBITAL'], 1000, profile['reference'][1],
                        advanced=True, factory=base['factory'], yard=True, city_count=7)
assert unused['yard'] and not unused['yard_used']
experiment = model.compare(tuned=True, profiles=profile, city_count=7,
                           yard_bonus=.5, require_yard=True)['reference']['alpha']
assert experiment['yard_used'] and experiment['turn'] == 121
assert base['turn'] == 115
print('Victory timing v2: city-cost regression, 27 scenarios, prerequisite and schedule checks passed.')
