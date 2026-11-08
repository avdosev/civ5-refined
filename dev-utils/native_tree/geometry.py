"""Attribute and inspect emitted sprites; never invent a connector path."""
import base64
from collections import defaultdict
import io
import math

from PIL import Image,ImageDraw,ImageChops

from .render import Textures,paint_pipe,rect


def key(parent,child):return parent+'>'+child


def inspect(scene,meta,assets=None):
    cards={c['id']:c for c in meta['cards']}
    edges={key(e['PrereqTech'],e['TechType']):dict(parent=e['PrereqTech'],child=e['TechType']) for e in scene['edges']}
    textures=Textures(assets);images={};sprites={};by_edge=defaultdict(list)
    raw=[i['roots'][0] for i in scene['instances'] if i['template']=='TechPipeInstance']
    pipes=[]
    for c in raw:
        r=rect(c,(0,0,meta['width'],meta['height']))
        uv=c.get('textureOffset') or {};origin=c.get('origin') or {}
        sig=(c['texture'],round(r[2]),round(r[3]),uv.get('x',0),uv.get('y',0))
        if sig not in images:
            im=Image.new('RGBA',(max(1,sig[1]),max(1,sig[2])))
            paint_pipe(im,c,(0,0,r[2],r[3]),textures)
            images[sig]=im
            buf=io.BytesIO();im.save(buf,format='PNG')
            sprites[str(len(sprites))]='data:image/png;base64,'+base64.b64encode(buf.getvalue()).decode()
        sprite=str(list(images).index(sig))
        uses=[];side=None
        if origin.get('kind')=='edge':
            uses=[key(origin['parent'],origin['child'])]
        elif origin.get('kind')=='adapter':
            owner=origin['node'];cr=cards[owner]['rect']
            side='right' if r[0]>=cr[0]+cr[2]-3 else 'left'
            for ek,e in edges.items():
                p,ch=cards[e['parent']],cards[e['child']]
                if side=='right' and e['parent']==owner:
                    dy=ch['grid'][1]-p['grid'][1]
                    if c['texture'].endswith('TechBranchH.dds') or (uv.get('y')==0 and dy>0) or (uv.get('y')==72 and dy<0):uses.append(ek)
                if side=='left' and e['child']==owner:
                    dy=p['grid'][1]-ch['grid'][1]
                    if c['texture'].endswith('TechBranchH.dds') or (uv.get('y')==0 and dy>0) or (uv.get('y')==72 and dy<0):uses.append(ek)
        pipe=dict(rect=r,texture=c['texture'],uv=uv,serial=c['serial'],origin=origin,side=side,uses=uses,sprite=sprite)
        pipes.append(pipe)
        for ek in uses:by_edge[ek].append((pipe,images[sig]))
    issues=[]
    # Compare actual sprite ink, not the whole (mostly transparent) image box.
    for pipe in pipes:
        x,y,w,h=pipe['rect'];im=images[next(s for i,s in enumerate(images) if str(i)==pipe['sprite'])]
        allowed={v for ek in pipe['uses'] for v in (edges[ek]['parent'],edges[ek]['child'])}
        for cid,card in cards.items():
            if cid in allowed:continue
            cx,cy,cw,ch=card['rect']
            box=(max(round(x),math.ceil(cx+3)),max(round(y),math.ceil(cy+3)),min(round(x+w),math.floor(cx+cw-3)),min(round(y+h),math.floor(cy+ch-3)))
            if box[2]<=box[0] or box[3]<=box[1]:continue
            crop=im.getchannel('A').crop((box[0]-round(x),box[1]-round(y),box[2]-round(x),box[3]-round(y)))
            pixels=sum(crop.histogram()[128:])
            if pixels>=3:
                issues.append(dict(kind='wire_through_card',card=cid,serial=pipe['serial'],edges=pipe['uses'],pixels=pixels,rect=box))
    # Connectivity of the sprite union for each logical edge. Unlike the old
    # graph checker, this retains native missing pieces and card occlusion.
    for ek,e in edges.items():
        ps=by_edge[ek];p,ch=cards[e['parent']],cards[e['child']]
        if not ps:
            issues.append(dict(kind='missing_path',edge=ek));continue
        left=math.floor(min(v['rect'][0] for v,_ in ps))-2
        top=math.floor(min(v['rect'][1] for v,_ in ps))-2
        right=math.ceil(max(v['rect'][0]+v['rect'][2] for v,_ in ps))+2
        bottom=math.ceil(max(v['rect'][1]+v['rect'][3] for v,_ in ps))+2
        mask=Image.new('L',(right-left,bottom-top))
        for v,im in ps:
            pos=(round(v['rect'][0])-left,round(v['rect'][1])-top)
            layer=Image.new('L',mask.size);layer.paste(im.getchannel('A'),pos)
            mask=ImageChops.lighter(mask,layer)
        mask=mask.point(lambda a:255 if a>=64 else 0)
        draw=ImageDraw.Draw(mask)
        for cid,c in cards.items():
            if cid in (e['parent'],e['child']):continue
            x,y,w,h=c['rect']
            if x+w<left or x>right or y+h<top or y>bottom:continue
            draw.rectangle((round(x-left),round(y-top),round(x+w-left),round(y+h-top)),fill=0)
        def port(x,y):
            x,y=round(x-left),round(y-top)
            for radius in range(7):
                for dx in range(-radius,radius+1):
                    for dy in range(-radius,radius+1):
                        xx,yy=x+dx,y+dy
                        if 0<=xx<mask.width and 0<=yy<mask.height and mask.getpixel((xx,yy))==255:return xx,yy
            return None
        pr,cr=p['rect'],ch['rect']
        a=port(pr[0]+pr[2]+5,pr[1]+pr[3]/2);b=port(cr[0]-5,cr[1]+cr[3]/2)
        if a and b:
            ImageDraw.floodfill(mask,a,128)
        if not a or not b or mask.getpixel(b)!=128:
            issues.append(dict(kind='disconnected_path',edge=ek,parent=e['parent'],child=e['child']))
    meta.update(pipes=pipes,pipe_sprites=sprites,edges=list(edges.values()),issues=issues)
    return meta
