#!/usr/bin/env python3
"""Procedural retro sci-fi texture generator for bounty-hunt.
Run locally:  python3 tools/texture_gen.py
Outputs to:   art/textures_generated/
Requires:     pip install pillow
"""
import os, random, math
from PIL import Image, ImageDraw

OUT = os.path.join(os.path.dirname(__file__), "..", "art", "textures_generated")
SIZE = 256

PALETTE = [
    (24,26,32),(38,42,50),(54,60,70),(72,80,92),(94,104,116),
    (118,128,140),(145,154,164),(170,178,186),
    (60,72,76),(80,96,98),
    (96,66,48),(128,84,52),(70,50,40),
    (210,170,60),(180,140,40),
    (20,20,24),(235,238,240),
]

def quantize_dither(img):
    pimg = Image.new('P', (1,1))
    flat = []
    for c in PALETTE: flat += list(c)
    flat += [0,0,0] * (256 - len(PALETTE))
    pimg.putpalette(flat)
    return img.convert('RGB').quantize(palette=pimg, dither=Image.FLOYDSTEINBERG).convert('RGB')

def noise_overlay(img, amount=10):
    px = img.load()
    for y in range(img.height):
        for x in range(img.width):
            n = random.randint(-amount, amount)
            r,g,b = px[x,y][:3]
            px[x,y] = (max(0,min(255,r+n)), max(0,min(255,g+n)), max(0,min(255,b+n)))
    return img

def vstreaks(draw, x0, y0, x1, y1, base, count=40, dark=18):
    for _ in range(count):
        sx = random.randint(x0, x1-1)
        ln = random.randint((y1-y0)//6, (y1-y0)//2)
        sy = random.randint(y0, max(y0, y1-ln))
        d = random.randint(6, dark)
        draw.line([(sx,sy),(sx,sy+ln)], fill=(max(0,base[0]-d),max(0,base[1]-d),max(0,base[2]-d)), width=1)

def metal_panel():
    img = Image.new('RGB', (SIZE,SIZE), (72,80,92))
    d = ImageDraw.Draw(img)
    for py in range(2):
        for px_ in range(2):
            x0,y0 = px_*128, py*128
            x1,y1 = x0+128, y0+128
            shade = random.randint(-8,8)
            base = (72+shade,80+shade,92+shade)
            d.rectangle([x0,y0,x1-1,y1-1], fill=base)
            d.line([(x0,y0),(x1-1,y0)], fill=(110,120,132), width=2)
            d.line([(x0,y0),(x0,y1-1)], fill=(100,110,122), width=2)
            d.line([(x0,y1-2),(x1-1,y1-2)], fill=(40,44,52), width=3)
            d.line([(x1-2,y0),(x1-2,y1-1)], fill=(46,50,58), width=3)
            for rx,ry in [(x0+10,y0+10),(x1-12,y0+10),(x0+10,y1-12),(x1-12,y1-12)]:
                d.ellipse([rx-3,ry-3,rx+3,ry+3], fill=(50,56,66))
                d.ellipse([rx-3,ry-3,rx+2,ry+2], fill=(125,134,146))
                d.ellipse([rx-1,ry-1,rx+2,ry+2], fill=(60,66,76))
            vstreaks(d, x0+4, y0+4, x1-4, y1-4, base, count=25)
            if random.random() < 0.6:
                cx,cy = random.randint(x0+20,x1-20), random.randint(y0+20,y1-20)
                for _ in range(60):
                    ox,oy = int(random.gauss(0,8)), int(random.gauss(0,8))
                    c = random.choice([(96,66,48),(70,50,40),(128,84,52)])
                    if x0<cx+ox<x1 and y0<cy+oy<y1:
                        d.point((cx+ox,cy+oy), fill=c)
    noise_overlay(img, 7)
    return quantize_dither(img)

def hazard_strip():
    img = Image.new('RGB', (SIZE,64), (38,42,50))
    d = ImageDraw.Draw(img)
    for i in range(-64, SIZE+64, 32):
        d.polygon([(i,0),(i+16,0),(i+16-32,64),(i-32,64)], fill=(210,170,60))
    for _ in range(220):
        x,y = random.randint(0,SIZE-1), random.randint(0,63)
        if random.random()<0.5:
            d.point((x,y), fill=(38,42,50))
        else:
            d.line([(x,y),(x+random.randint(2,6),y)], fill=(54,60,70))
    d.line([(0,0),(SIZE,0)], fill=(20,20,24), width=2)
    d.line([(0,62),(SIZE,62)], fill=(20,20,24), width=2)
    noise_overlay(img, 9)
    return quantize_dither(img)

def _crack(d, x, y, angle, length, depth=0):
    """Branching random-walk crack: jagged, directional, with taper."""
    for i in range(length):
        angle += random.gauss(0, 0.28)
        x += math.cos(angle); y += math.sin(angle)
        xi, yi = int(x) % SIZE, int(y) % SIZE
        d.point((xi, yi), fill=(40,46,56))
        if i % 3 == 0:  # thicken near origin
            d.point(((xi+1)%SIZE, yi), fill=(48,54,64))
        if depth < 2 and random.random() < 0.025:
            _crack(d, x, y, angle + random.choice([-1,1])*random.uniform(0.5,1.1),
                   max(8, length//3), depth+1)

def concrete():
    img = Image.new('RGB', (SIZE,SIZE), (94,104,116))
    d = ImageDraw.Draw(img)
    # bold blotches (oil stains, water marks)
    for _ in range(10):
        cx,cy = random.randint(0,SIZE), random.randint(0,SIZE)
        rad = random.randint(24,80)
        sh = random.randint(-26,-10) if random.random()<0.75 else random.randint(4,10)
        for _ in range(rad*22):
            a = random.random()*math.tau
            r = abs(random.gauss(0, rad/2.0))
            x,y = int(cx+math.cos(a)*r)%SIZE, int(cy+math.sin(a)*r)%SIZE
            p = img.getpixel((x,y))
            img.putpixel((x,y),(max(0,min(255,p[0]+sh)),max(0,min(255,p[1]+sh)),max(0,min(255,p[2]+sh))))
    # branching cracks from edges/joints
    for _ in range(4):
        edge = random.choice(['t','b','l','r'])
        if edge=='t': x,y,a = random.randint(0,SIZE),0, math.pi/2
        elif edge=='b': x,y,a = random.randint(0,SIZE),SIZE-1, -math.pi/2
        elif edge=='l': x,y,a = 0,random.randint(0,SIZE), 0.0
        else: x,y,a = SIZE-1,random.randint(0,SIZE), math.pi
        _crack(d, x, y, a + random.gauss(0,0.4), random.randint(60,140))
    # expansion joints
    d.line([(0,128),(SIZE,128)], fill=(54,60,70), width=2)
    d.line([(128,0),(128,SIZE)], fill=(54,60,70), width=2)
    d.line([(0,129),(SIZE,129)], fill=(110,118,128), width=1)
    d.line([(129,0),(129,SIZE)], fill=(110,118,128), width=1)
    noise_overlay(img, 8)
    return quantize_dither(img)

def vent():
    img = Image.new('RGB', (128,128), (54,60,70))
    d = ImageDraw.Draw(img)
    d.rectangle([0,0,127,127], outline=(90,98,110), width=4)
    d.rectangle([2,2,125,125], outline=(30,34,42), width=2)
    for y in range(12, 116, 10):
        d.rectangle([10,y,118,y+5], fill=(20,22,28))
        d.line([(10,y),(118,y)], fill=(96,104,116), width=1)
    for sx,sy in [(7,7),(120,7),(7,120),(120,120)]:
        d.ellipse([sx-3,sy-3,sx+3,sy+3], fill=(110,118,130))
        d.line([(sx-2,sy-2),(sx+2,sy+2)], fill=(36,40,48))
    noise_overlay(img, 6)
    return quantize_dither(img)

if __name__ == "__main__":
    os.makedirs(OUT, exist_ok=True)
    random.seed(77)
    metal_panel().save(os.path.join(OUT, "T_MetalPanel_256.png"))
    hazard_strip().save(os.path.join(OUT, "T_HazardStrip_256x64.png"))
    concrete().save(os.path.join(OUT, "T_ConcreteGrime_256.png"))
    vent().save(os.path.join(OUT, "T_VentGrille_128.png"))
    print("Wrote 4 textures to", os.path.abspath(OUT))
