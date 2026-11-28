#!/usr/bin/env python3
"""art-ui worker: prompt builder for the UI kit in the owner's lacquer-and-gold mock-up style.
Reads design/art_batches/UI_U1_ui_kit.json object descriptions, wraps them in the owner-UI style tail."""
import json, re, sys
ICON = ("Mobile gacha game UI icon of {what}. Elegant thin gold line-art icon: uniform monoline gold stroke with rounded caps, "
        "one soft rose-pink accent on a single detail, a faint warm glow, a subtle dark plum lacquer inlay inside the outline, "
        "nothing else. Single centered object filling about 70 percent of the frame, generous padding, simple silhouette that reads at 48 px. "
        "{bg} Crisp vector-like edges. No text, no letters, no numerals, no logos, no watermark.")
CUR = ("Mobile gacha game currency icon: {what}. Gold-rimmed lacquer-and-gem style with thin gold outline, rich jewel colour fill, soft painterly highlight, "
       "tiny rose-pink accent sparkle. Single centered object filling about 70 percent of the frame, simple strong silhouette that reads at 48 px. "
       "{bg} No text, no letters, no numerals, no logos, no watermark.")
SMALL = ("Mobile gacha game UI ornament: {what}. Dark plum lacquer with thin gold hairline trim and a faint rose-pink accent, matching an elegant lacquer-and-gold interface. "
         "Single centered object, generous padding, crisp clean edges, front view, flat. {bg} No text, no letters, no numerals, no logos, no watermark.")
def what(task):
    p=task['prompt']; i=p.find('. flat lacquer')
    s=p[:i] if i>0 else p
    return s.replace('Mobile game UI icon: ','').replace('Game UI element: ','')
BG_T='Isolated on a fully transparent background.'
BG_D='Flat near-black plum lacquer background.'
def build(task, transparent=True):
    bg=BG_T if transparent else BG_D
    w=what(task); k=task['kind']
    if k=='mode_cover': return task['prompt']
    if task['id'].startswith('U1.icon_cur_'): return CUR.format(what=w,bg=bg)
    if k=='icon': return ICON.format(what=w,bg=bg)
    return SMALL.format(what=w,bg=bg)
if __name__=='__main__':
    d=json.load(open('design/art_batches/UI_U1_ui_kit.json'))
    t={x['id'][3:]:x for x in d['tasks']}
    for n in sys.argv[1:]: print(n,build(t[n]),sep='\n')
