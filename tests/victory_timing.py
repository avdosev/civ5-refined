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
assert model.TRAINING_GOAL == 13800
assert [model.COST[k] for k in ('ADVANCED_COMPUTING', 'GENERAL_AI', 'RECURSIVE')] == [7700, 8800, 9500]

# V2 reference: seven cities, science=1000, final learning +15%; tech prices unchanged.
reference = {'s1000_plow': (120, 117, 112),
             's1000_pnormal': (115, 111, 110),
             's1000_phigh': (112, 107, 110)}
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
                assert result['training_turns'] == math.ceil(13800 / result['training_rate'])
                assert math.isclose(result['training_rate'], sum(result['participating_city_science']))
        if count == 7 and profile in reference:
            assert tuple(routes[r]['turn'] for r in ('alpha', 'mars', 'singularity')) == reference[profile]

# More factories can change preparation, but cannot directly change training speed.
slow = model.singularity(1000, [60, 45, 35, 24, 19, 14, 10], city_count=7)
fast = model.singularity(1000, [160, 120, 90, 64, 51, 38, 26], city_count=7)
assert slow['training_rate'] == fast['training_rate']
print('Victory timing v2: city-cost regression, 27 scenarios, prerequisite and schedule checks passed.')
