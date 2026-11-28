#!/usr/bin/env python3
"""art-ui worker: assemble picks from the scratch raw/ tree into assets/incoming/art_ui/ (finals + small candidates), picks.json and contact_sheet.jpg.
usage: ui_kit_finalize.py RAW_DIR OUT_DIR   (RAW_DIR holds raw/<icon|small|cover|nav|cur|pilot>/*.png downloaded from Higgsfield)"""
import sys, os, json
from PIL import Image, ImageDraw
RAW, OUT = sys.argv[1], sys.argv[2]
PLUM = (26, 14, 24)
def P(x): return os.path.join(RAW, x + '.png')
# name -> (group, raw path (no ext), note)
picks = {}
def add(group, name, raw, note=''): picks[(group, name)] = (raw, note)
# navbar (owner mock: teapot, fan for heroines, tiles, lotus, shop awning); alternates from the batch (lantern, pouch)
add('icons_nav','tab_tea','pilot/tea_2'); add('icons_nav','tab_heroines','pilot/fan_1'); add('icons_nav','tab_games','nav/games')
add('icons_nav','tab_wishes','nav/wishes_lotus','owner-mock lotus'); add('icons_nav','tab_wishes_alt_lantern','nav/wishes_lantern','batch version: lantern + star')
add('icons_nav','tab_shop','nav/shop_awning','owner-mock shop front'); add('icons_nav','tab_shop_alt_pouch','nav/shop_pouch','batch version: pouch')
cur = {'gems':'cur/gems','moon':'icon/icon_cur_moon_c1','coins':'icon/icon_cur_coins_c2','petals':'icon/icon_cur_petals_c2','ticket':'icon/icon_cur_ticket_c2','candle':'icon/icon_cur_candle_c1'}
for k,v in cur.items(): add('icons_currency','cur_'+k,v)
add('icons_currency','cur_gems_alt','icon/icon_cur_gems_c1')
def grp(prefix, group, m):
    for k,c in m.items(): add(group, prefix+k, f'icon/icon_{prefix}{k}_c{c}')
grp('act_','icons_action',{'undo':1,'shuffle':1,'hint':1,'slot':2,'pause':1,'play':1,'retry':2,'next':1})
grp('st_','icons_status',{'star':1,'heart_bond':1,'lock':1,'check':1,'cross':1,'bell':1,'calendar':1,'timer':1,'trophy':2,'flag':1})
grp('sys_','icons_system',{'settings':1,'back':1,'close':1,'home':1,'phone':1,'mail':2,'gift':1,'chest':2,'quests':1,'gallery':1,'wardrobe':1,'salon':1})
grp('au_','icons_audio',{'music':1,'sfx':1,'voice':1,'mute':1,'subtitles':1,'quiet':1})
grp('md_','icons_mode',{'path':1,'daily':1,'classic':1,'triples':1,'connect':1,'garden':1,'riichi':1,'koikoi':1,'palm':1,'duels':1,'adventure':1})
grp('misc_','icons_misc',{'share':1,'filter':1})
sm = {'rarity_a_frame':1,'rarity_s_frame':1,'rarity_ssr_frame':2,'avatar_frame_bamboo':1,'avatar_frame_lacquer':1,'avatar_frame_jade':2,'avatar_frame_night':2,
      'badge_silver':2,'badge_gold':1,'badge_perfect':1,'ribbon_new':1,'ribbon_limited':1,'divider_lantern':1,'divider_wave':2,
      'panel_corner_gold':2,'button_plate_lacquer':2,'tab_underline':1,'loading_ring':2,'toast_plate':1}
for k,c in sm.items(): add('ornaments','small_'+k,f'small/small_{k}_c{c}')
add('ornaments','small_badge_bronze','small/rr_badge_bronze_c2','reroll: bronze tone'); add('ornaments','small_panel_corner_jade','small/rr_panel_corner_jade_c2','reroll: jade tone')
add('ornaments','small_button_plate_paper','small/rr_button_plate_paper_c1','reroll: paper tone')
cov = {'path':1,'daily':1,'triples':1,'connect':1,'garden':2,'riichi':2,'koikoi':1,'palm':1,'duels':3,'adventure':2}
for k,c in cov.items(): add('covers',f'cover_{k}',f'cover/cover_{k}_c{c}')
add('covers','cover_classic','cover/rr_classic_c2','reroll: upright jade-backed tiles (batch version showed cubes)')
add('covers','cover_classic_hero','cover/hero_mc_c1','with Mahjong-chan (element recipe)'); add('covers','cover_palm_hero','cover/hero_yue_c1','with Yue (element recipe)'); add('covers','cover_duels_hero','cover/hero_nova_c2','with Nova (element recipe)')

def trim(im, pad=16):
    a = im.getchannel('A').point(lambda v: 255 if v > 10 else 0); bb = a.getbbox()
    if not bb: return im
    l,t,r,b = bb; return im.crop((max(0,l-pad),max(0,t-pad),min(im.width,r+pad),min(im.height,b+pad)))
os.makedirs(OUT, exist_ok=True); manifest = []; used = set()
for (group, name), (raw, note) in picks.items():
    src = P(raw); im = Image.open(src); used.add(raw)
    d = os.path.join(OUT, group); os.makedirs(d, exist_ok=True)
    if group == 'covers':
        f = os.path.join(d, name + '.jpg'); im.convert('RGB').save(f, quality=92, subsampling=0)
    else:
        im = im.convert('RGBA')
        if group == 'ornaments': im = trim(im)
        im.thumbnail((768 if group == 'ornaments' else 512, 768 if group == 'ornaments' else 512), Image.LANCZOS)
        f = os.path.join(d, name + '.png'); im.save(f, optimize=True)
    manifest.append({'group': group, 'name': name, 'file': os.path.relpath(f, OUT), 'source_candidate': raw, 'size': list(Image.open(f).size), 'note': note})
# candidates (non-picked + picked), small jpg on plum
cdir = os.path.join(OUT, 'candidates'); n = 0
for sub in ('icon','small','cover','nav','cur','pilot'):
    sd = os.path.join(RAW, sub)
    if not os.path.isdir(sd): continue
    for fn in sorted(os.listdir(sd)):
        if not fn.endswith('.png'): continue
        im = Image.open(os.path.join(sd, fn)); os.makedirs(os.path.join(cdir, sub), exist_ok=True)
        if sub == 'cover':
            im.convert('RGB').resize((1168, int(1168*im.height/im.width)), Image.LANCZOS).save(os.path.join(cdir, sub, fn[:-4] + '.jpg'), quality=88)
        else:
            bg = Image.new('RGBA', im.size, PLUM + (255,)); bg.alpha_composite(im.convert('RGBA')); bg = bg.convert('RGB'); bg.thumbnail((384, 384), Image.LANCZOS)
            bg.save(os.path.join(cdir, sub, fn[:-4] + '.jpg'), quality=90)
        n += 1
json.dump({'batch': 'U1 (art-ui worker)', 'style': 'gold monoline lacquer icons, plum lacquer inlay, rose-pink accent; currencies as gold-rimmed gems', 'picks': manifest, 'candidates_dir': 'candidates/', 'candidate_count': n}, open(os.path.join(OUT, 'picks.json'), 'w'), indent=1, ensure_ascii=False)
# contact sheet
def sheet(items, f, cols, cell):
    rows = (len(items)+cols-1)//cols; sh = Image.new('RGB', (cols*cell, rows*(cell+16)), (38,20,32)); d = ImageDraw.Draw(sh)
    for i, m in enumerate(items):
        im = Image.open(os.path.join(OUT, m['file'])).convert('RGBA'); bg = Image.new('RGBA', im.size, PLUM+(255,)); bg.alpha_composite(im); im = bg.convert('RGB'); im.thumbnail((cell-6, cell-6))
        x, y = (i % cols)*cell, (i//cols)*(cell+16); sh.paste(im, (x+3, y+16)); d.text((x+3, y+2), m['name'][:30], fill=(255,220,150))
    sh.save(f, quality=88)
ic = [m for m in manifest if m['group'] not in ('covers', 'ornaments')]; orn = [m for m in manifest if m['group'] == 'ornaments']; cv = [m for m in manifest if m['group'] == 'covers']
sheet(ic, os.path.join(OUT, 'contact_sheet_icons.jpg'), 12, 150); sheet(orn, os.path.join(OUT, 'contact_sheet_ornaments.jpg'), 6, 200); sheet(cv, os.path.join(OUT, 'contact_sheet_covers.jpg'), 4, 330)
sheet(manifest, os.path.join(OUT, 'contact_sheet.jpg'), 14, 128)
print(len(manifest), 'picks', n, 'candidates')
