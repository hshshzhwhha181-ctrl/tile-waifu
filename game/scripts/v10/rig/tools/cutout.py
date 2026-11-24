#!/usr/bin/env python3
"""Cut the heroine out of a finished illustration (rembg, isnet-anime) and prepare body.png.

    python3 cutout.py <art.png> <out body.png> [size=1400]

One image per process: several in one process got OOM-killed on the 16 GB box. The art is
downscaled to <size> first (1400 px is plenty for a 720x1280 screen). Semi-transparent edge pixels
get the colour of the nearest solid pixel, so mipmaps and bilinear filtering never show the old
background as a dark/coloured fringe.
"""
import sys
import numpy as np
from PIL import Image
from scipy import ndimage as ndi
from rembg import remove, new_session

src, dst = sys.argv[1], sys.argv[2]
size = int(sys.argv[3]) if len(sys.argv) > 3 else 1400
im = Image.open(src).convert('RGB').resize((size, size), Image.LANCZOS)
out = np.asarray(remove(im, session=new_session('isnet-anime'), post_process_mask=False)).copy()
solid = out[..., 3] > 200
idx = ndi.distance_transform_edt(~solid, return_distances=False, return_indices=True)
rgb = out[..., :3][idx[0], idx[1]]
m = ~solid
out[..., :3][m] = rgb[m]
Image.fromarray(out).save(dst, optimize=True)
print('cutout', out.shape, 'opaque %.1f%%' % (100 * solid.mean()))
