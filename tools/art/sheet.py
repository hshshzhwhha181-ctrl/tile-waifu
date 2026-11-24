import sys,glob
from PIL import Image,ImageDraw
out=sys.argv[1]; fs=sys.argv[2:]; W=200; cols=6
rows=(len(fs)+cols-1)//cols
s=Image.new('RGB',(cols*W,rows*(W+16)),(52,46,52)); d=ImageDraw.Draw(s)
for i,f in enumerate(fs):
    im=Image.open(f).convert('RGBA'); im.thumbnail((W-8,W-8)); x,y=(i%cols)*W,(i//cols)*(W+16)
    s.paste(im,(x+4,y+4),im); d.text((x+3,y+W),f.split('/')[-1][:30],fill=(255,255,255))
s.save(out)
