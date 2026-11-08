"""Composite recorded native UI controls. Never route or repair a graph edge."""
from functools import lru_cache
import math
from pathlib import Path
import re

from PIL import Image, ImageDraw, ImageFont

ROOT = Path(__file__).resolve().parents[2]


def children(node):
    return node.get('children') or []


def descendants(node):
    yield node
    for child in children(node):
        yield from descendants(child)


def dimensions(node, parent_size):
    size = node['size']
    w = parent_size[0] if isinstance(size['x'], str) else size['x']
    h = parent_size[1] if isinstance(size['y'], str) else size['y']
    if node['tag'] == 'Stack':
        items = [c for c in children(node) if not c.get('hidden')]
        sizes = [dimensions(c, (w,h)) for c in items]
        pad = float(node['attrs'].get('Padding', 0))
        if node['attrs'].get('StackGrowth') == 'Right':
            w = sum(v[0] for v in sizes) + max(0,len(sizes)-1)*pad
            h = max((v[1] for v in sizes), default=0)
        else:
            h = sum(v[1] for v in sizes) + max(0,len(sizes)-1)*pad
            w = max((v[0] for v in sizes), default=0)
    return w,h


def rect(node, parent):
    px,py,pw,ph = parent
    w,h = dimensions(node,(pw,ph))
    ox,oy = node['offset']['x'],node['offset']['y']
    anchor = node['attrs'].get('Anchor','L,T').replace('.',',').split(',')
    side = node['attrs'].get('AnchorSide','I,I').replace('.',',').upper().split(',')
    ax,ay = [v.upper() for v in anchor]
    x = px+ox if ax=='L' else px+(pw-w)/2+ox if ax=='C' else px+pw-w-ox
    y = py+oy if ay=='T' else py+(ph-h)/2+oy if ay=='C' else py+ph-h-oy
    if side[0]=='O' and ax=='L': x=px-w-ox
    if side[0]=='O' and ax=='R': x=px+pw+ox
    if side[1]=='O' and ay=='T': y=py-h-oy
    if side[1]=='O' and ay=='B': y=py+ph+oy
    return (x,y,w,h)


def walk(node, parent, visible=True):
    r=rect(node,parent)
    visible = visible and not node.get('hidden', False) and node['tag']!='ShowOnMouseOver'
    yield node,r,visible
    cursor=0
    for c in children(node):
        cp=r
        if node['tag']=='Stack' and not c.get('hidden'):
            w,h=dimensions(c,r[2:])
            if node['attrs'].get('StackGrowth')=='Right':
                # A stack allocates each visible child a slot, rather than
                # anchoring every child to the same parent origin.
                cp=(r[0]+cursor,r[1],w,r[3]);cursor+=w+float(node['attrs'].get('Padding',0))
            else:
                cp=(r[0],r[1]+cursor,r[2],h);cursor+=h+float(node['attrs'].get('Padding',0))
        yield from walk(c,cp,visible)


@lru_cache(None)
def font(size, filename=None):
    candidates=[filename,'/System/Library/Fonts/Supplemental/Arial.ttf',
                '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf']
    for path in candidates:
        if path and Path(path).exists():return ImageFont.truetype(str(path),round(size))
    return ImageFont.load_default(size=round(size))


class Textures:
    def __init__(self, assets=None):
        self.paths={};self.missing=set();self.reconstructed=set()
        for base in (Path(assets) if assets else None, ROOT/'mod'):
            if base and base.exists():
                for p in base.rglob('*'):
                    if p.suffix.lower() in ('.dds','.png','.tga'):
                        self.paths[p.name.lower()]=p

    @lru_cache(None)
    def open(self,name):
        key=Path(name.replace('\\','/')).name.lower()
        if key in self.paths:return Image.open(self.paths[key]).convert('RGBA')
        self.missing.add(name);return None

    def sprite(self,node,size):
        name=node.get('texture') or ''
        image=self.open(name)
        if image is not None:
            uv=node.get('textureOffset',{})
            x,y=round(uv.get('x',0)),round(uv.get('y',0))
            # Native SetTextureOffset samples this rectangle. Do not resize a
            # corner to bridge a gap between other controls.
            return image.crop((x,y,x+size[0],y+size[1]))
        return None


def paint_pipe(layer,node,r,textures):
    x,y,w,h=r;w=max(1,round(w));h=max(1,round(h));name=node.get('texture','')
    exact=textures.sprite(node,(w,h))
    if exact is not None:
        layer.alpha_composite(exact,(round(x),round(y)));return
    textures.reconstructed.add(name)
    # Only the appearance of the three missing stock sprites is reconstructed.
    # Their actual rectangles/offsets/order are emitted by the original Lua.
    # The atlas has a 12px displacement of its horizontal stroke from center.
    # Each primitive is clipped to its own native image control.
    s=3;im=Image.new('RGBA',(w*s,h*s));d=ImageDraw.Draw(im)
    def line(points):
        pts=[(round(a*s),round(b*s)) for a,b in points]
        d.line(pts,fill=(111,91,47,180),width=4*s)
        d.line(pts,fill=(244,222,165,255),width=max(1,round(1.4*s)))
    if name.endswith('TechBranchH.dds'):
        line([(0,9),(w,9)])
    elif name.endswith('TechBranchV.dds'):
        line([(4,0),(4,h)])
    elif name.endswith('TechBranches.dds'):
        uv=node.get('textureOffset',{});right=uv.get('x',0)==72;bottom=uv.get('y',0)==72
        vx=16 if right else 4
        hy=24 if bottom else 9
        edge=0 if right else w
        radius=12
        # Quarter-circle stencil of the four native atlas cells. No graph
        # knowledge is available here, so disconnected ends remain disconnected.
        if bottom:
            points=[(vx,0),(vx,hy-radius)]
            for i in range(1,17):
                a=i*math.pi/32
                px=vx-radius+radius*math.cos(a) if right else vx+radius-radius*math.cos(a)
                points.append((px,hy-radius+radius*math.sin(a)))
            points.append((edge,hy))
        else:
            points=[(edge,hy)]
            for i in range(17):
                a=i*math.pi/32
                px=vx-radius+radius*math.sin(a) if right else vx+radius-radius*math.sin(a)
                points.append((px,hy+radius-radius*math.cos(a)))
            points.append((vx,h))
        line(points)
    else:
        raise ValueError('Unknown pipe texture: '+name)
    layer.alpha_composite(im.resize((w,h),Image.Resampling.LANCZOS),(round(x),round(y)))


def icon(layer,node,r,textures,title=''):
    x,y,w,h=r;size=(max(1,round(w)),max(1,round(h)))
    sprite=textures.sprite(node,size)
    if sprite is not None:
        layer.alpha_composite(sprite,(round(x),round(y)));return
    # Missing stock art is visibly a placeholder; custom portraits are read
    # directly from the same DDS atlases shipped in the mod.
    d=ImageDraw.Draw(layer);pad=5 if w>=60 else 6
    box=(x+pad,y+pad,x+w-pad,y+h-pad)
    d.ellipse(box,fill='#223e48',outline='#bca565',width=2)
    generic=(node.get('icon') or {}).get('atlas')=='GENERIC_FUNC_ATLAS'
    if generic:
        cx,cy=x+w/2,y+h/2
        pts=[]
        for k in range(16):
            a=k*math.pi/8-math.pi/2;rr=w*(0.31 if k%2==0 else 0.14)
            pts.append((cx+math.cos(a)*rr,cy+math.sin(a)*rr))
        d.polygon(pts,fill='#dddccc');return
    mark=re.sub(r'\[.*?\]','',title or '?')[:1]
    f=font(26 if w>=60 else 19)
    d.text((x+w/2,y+h/2),mark,fill='#e7ddba',font=f,anchor='mm')


def render(scene,output,assets=None,font_path=None,columns=None):
    textures=Textures(assets)
    # The real EraStack sizes, not ideal era ranges derived from our graph.
    eras=[i for i in scene['instances'] if i['template']=='EraBlockInstance']
    world_width=sum(i['roots'][0]['size']['x'] for i in eras)
    frame_height=round(max(i['roots'][0]['size']['y'] for i in eras))
    image=Image.new('RGBA',(math.ceil(world_width),frame_height),'#141a1b')
    d=ImageDraw.Draw(image)
    x=0
    era_rows=[]
    for instance in eras:
        root=instance['roots'][0];w=root['size']['x']
        d.rectangle((x,0,x+w,frame_height),fill='#191e20' if len(era_rows)%2 else '#171b1d')
        d.line((x,0,x,frame_height),fill='#77745c',width=1)
        d.line((x,0,x+w,0),fill='#d1bd7f',width=2)
        d.line((x,19,x+w,19),fill='#d1bd7f',width=1)
        labels=[c for c in descendants(root) if c.get('id')=='FutureLabel']
        label=labels[0].get('text','') if labels else ''
        d.text((x+w/2,10),label,font=font(16,font_path),fill='#eee5c6',anchor='mm')
        era_rows.append(dict(name=label,x=x,width=w));x+=w
    for instance in scene['instances']:
        if instance['template']=='TechPipeInstance':
            root=instance['roots'][0]
            paint_pipe(image,root,rect(root,(0,0,world_width,frame_height)),textures)
    techs={t['ID']:t for t in scene['technologies']}
    cards=[]
    for instance in scene['instances']:
        if instance['template']!='TechButtonInstance':continue
        root=instance['roots'][0];r=rect(root,(0,0,world_width,frame_height));x,y,w,h=r
        tid=root.get('firstVoid1',root.get('void1'));tech=techs[tid]
        title=scene['localization'].get(tech['Description'],tech['Type'])
        controls=list(walk(root,(0,0,world_width,frame_height)))
        # Skin is recreated because the proprietary Grid9 style textures are
        # not distributed with this repo. Root and child geometry stays native.
        states=[c.get('id') for c,_,visible in controls if visible and c.get('id') in
                ('AlreadyResearched','CurrentlyResearching','Available','Unavailable','Locked','FreeTech')]
        fill='#51451b' if 'AlreadyResearched' in states else '#061011'
        d.rounded_rectangle((x-2,y-2,x+w+2,y+h+2),radius=8,fill=fill,outline='#d7c383',width=1)
        d.rounded_rectangle((x+1,y+1,x+w-1,y+10),radius=5,fill='#14323a')
        pictures=[]
        label=''
        for node,nr,visible in controls:
            if not visible:continue
            nid=node.get('id','') or ''
            if nid=='TechPortrait' or re.fullmatch('B[1-5]',nid):
                icon(image,node,nr,textures,title if nid=='TechPortrait' else node.get('tooltip',''))
                pictures.append(dict(id=nid,rect=nr,texture=node.get('texture'),
                                     uv=node.get('textureOffset'),tooltip=node.get('tooltip','')))
            elif node['tag']=='Image' and node.get('texture') and nr[2]>0 and nr[3]>0:
                # Original portrait frames etc. retain XML z-order when those
                # files are supplied; hover-only children remain hidden.
                sprite=textures.sprite(node,(max(1,round(nr[2])),max(1,round(nr[3]))))
                if sprite is not None:image.alpha_composite(sprite,(round(nr[0]),round(nr[1])))
            elif nid.endswith('TechName'):
                label=node.get('text','')
                size=re.search(r'(\d+)$',node['attrs'].get('Font','16'))
                d.text((nr[0],nr[1]),label,font=font(int(size[1]) if size else 16,font_path),fill='#efe8c8')
        cards.append(dict(id=tech['Type'],name=title,label=label,rect=r,icons=pictures,
                          grid=[tech['GridX'],tech['GridY']],states=states,help=root.get('tooltip','')))
    d.line((0,frame_height-1,world_width,frame_height-1),fill='#d1bd7f',width=2)
    output=Path(output);output.parent.mkdir(parents=True,exist_ok=True)
    if columns:
        lo,hi=columns
        image=image.crop((lo*366,0,min(image.width,hi*366+64),frame_height))
    image.save(output)
    return dict(width=world_width,height=frame_height,cards=cards,eras=era_rows,
                reconstructed_textures=sorted(textures.reconstructed),
                missing_art=sorted(textures.missing),image=str(output))
