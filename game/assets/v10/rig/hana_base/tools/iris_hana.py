#!/usr/bin/env python3
"""Hana's moving pupils: runs scripts/v10/rig/tools/iris_patches.py with her eye openings (traced on a 9x crop
of body.png).

    python3 iris_hana.py <body.png> <out dir>
"""
import importlib.util, os, sys

here = os.path.dirname(os.path.abspath(__file__))
shared = os.path.normpath(os.path.join(here, '../../../../../scripts/v10/rig/tools/iris_patches.py'))
spec = importlib.util.spec_from_file_location('iris_patches', shared)
ip = importlib.util.module_from_spec(spec)
spec.loader.exec_module(ip)
ip.EYES = {
    # viewer-left eye (her right)
    'L': {'box': (664, 248, 724, 280), 'centre': (692.0, 262.5), 'r': 10.5,
          'open': [(671, 268), (675, 262), (681, 257), (690, 254), (700, 254), (708, 257), (714, 261), (717, 265),
                   (710, 268), (700, 271), (688, 272), (678, 272)]},
    # viewer-right eye (her left)
    'R': {'box': (768, 224, 824, 260), 'centre': (789.0, 243.0), 'r': 10.0,
          'open': [(775, 252), (777, 245), (781, 238), (788, 234), (797, 231), (806, 231), (813, 233), (817, 238),
                   (812, 244), (804, 248), (795, 251), (785, 253)]},
}
ip.main(sys.argv[1], sys.argv[2])
