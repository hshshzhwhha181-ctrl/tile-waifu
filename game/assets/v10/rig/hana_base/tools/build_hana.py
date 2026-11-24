#!/usr/bin/env python3
"""Build Hana's rig: the shared build_rig.py (Skeleton2D + skinned Polygon2D layers from rig_def.json), then point
the scene at Hana's script (hana_rig.gd extends V10LiveRig) instead of the base live_rig.gd.

    python3 build_hana.py [--debug out_dir]
Run split_layers.py first when the layer split changed (see README.md, "Rebuild").
"""
import importlib.util, os, sys

here = os.path.dirname(os.path.abspath(__file__))
asset = os.path.dirname(here)
shared = os.path.normpath(os.path.join(here, '../../../../../scripts/v10/rig/tools/build_rig.py'))
spec = importlib.util.spec_from_file_location('build_rig', shared)
br = importlib.util.module_from_spec(spec)
spec.loader.exec_module(br)
dbg = sys.argv[sys.argv.index('--debug') + 1] if '--debug' in sys.argv else None
br.build(os.path.join(asset, 'rig_def.json'), dbg)
p = os.path.join(asset, 'rig.tscn')
s = open(p).read()
s = s.replace('path="res://scripts/v10/rig/live_rig.gd"', 'path="res://assets/v10/rig/hana_base/hana_rig.gd"')
open(p, 'w').write(s)
print('rig.tscn ->', 'hana_rig.gd' if 'hana_rig.gd' in s else 'live_rig.gd (replace failed)')
