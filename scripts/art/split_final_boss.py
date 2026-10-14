# Splits the owner's final-boss Tripo file (one mesh, three figures that do not touch) into three .glb models by
# connected pieces, cut at two z planes no piece crosses (v0.8.0 FINAL_BOSS.md). Writes only to the output folder.
# Usage: python3 -I scripts/art/split_final_boss.py unprocessed_images/final_boss/final_boss_raw.glb <out_dir>
# Output names: final_boss_phase1 = the small Nemesis, phase2 = the Prism, phase3 = the Colossus (by position in the file).
import json,struct,sys
import numpy as np
from PIL import Image, ImageDraw
src,out=sys.argv[1],sys.argv[2]
b=open(src,'rb').read()
n=struct.unpack('<I',b[12:16])[0]; j=json.loads(b[20:20+n]); binlen=struct.unpack('<I',b[20+n:24+n])[0]; bin_=b[28+n:28+n+binlen]
def acc(i):
    a=j['accessors'][i]; bv=j['bufferViews'][a['bufferView']]
    dt={5126:np.float32,5125:np.uint32,5123:np.uint16}[a['componentType']]
    k={'SCALAR':1,'VEC2':2,'VEC3':3,'VEC4':4}[a['type']]
    o=bv.get('byteOffset',0)+a.get('byteOffset',0)
    arr=np.frombuffer(bin_,dt,a['count']*k,o)
    return arr.reshape(-1,k) if k>1 else arr
prim=j['meshes'][0]['primitives'][0]; at=prim['attributes']
P=acc(at['POSITION']); I=acc(prim['indices']).reshape(-1,3).astype(np.int64)
extra={k:acc(v) for k,v in at.items() if k!='POSITION'}
print('attributes',list(at))
key=np.round(P,5); _,inv=np.unique(key,axis=0,return_inverse=True); inv=inv.ravel()
par=np.arange(inv.max()+1)
def f(x):
    r=x
    while par[r]!=r: r=par[r]
    while par[x]!=r: par[x],x=r,par[x]
    return r
for t in inv[I]:
    for u,v in ((t[0],t[1]),(t[1],t[2])):
        ru,rv=f(u),f(v)
        if ru!=rv: par[ru]=rv
root=np.array([f(x) for x in inv])
CUTS=[-0.31,0.135]
group=np.zeros(len(P),int)
for r in np.unique(root):
    m=root==r; zc=P[m,2].mean()
    group[m]=0 if zc<CUTS[0] else (1 if zc<CUTS[1] else 2)
    lo,hi=P[m,2].min(),P[m,2].max()
    if (lo<CUTS[0]<hi) or (lo<CUTS[1]<hi): print('component straddles a cut:',m.sum(),'verts z',round(lo,3),round(hi,3))
img=j['images'][0]; ibv=j['bufferViews'][img['bufferView']]; imgbytes=bin_[ibv.get('byteOffset',0):ibv.get('byteOffset',0)+ibv['byteLength']]
def pad(x,c=b'\0'): return x+c*((4-len(x)%4)%4)
for g in range(3):
    tri=I[(group[I[:,0]]==g)]
    used=np.unique(tri); remap=-np.ones(len(P),np.int64); remap[used]=np.arange(len(used))
    pos=P[used].copy(); c=(pos.min(0)+pos.max(0))/2; pos[:,0]-=c[0]; pos[:,2]-=c[2]; pos[:,1]-=pos[:,1].min()
    attrs={'POSITION':pos.astype(np.float32)}; attrs.update({k:v[used].astype(v.dtype) for k,v in extra.items()})
    idx=remap[tri].astype(np.uint32).ravel()
    blob=b''; views=[]; accs=[]; amap={}
    for k,v in attrs.items():
        data=np.ascontiguousarray(v).tobytes(); views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data),'target':34962}); blob=pad(blob+data)
        a={'bufferView':len(views)-1,'componentType':5126,'count':len(v),'type':{2:'VEC2',3:'VEC3',4:'VEC4'}[v.shape[1]]}
        if k=='POSITION': a['min']=v.min(0).tolist(); a['max']=v.max(0).tolist()
        accs.append(a); amap[k]=len(accs)-1
    data=idx.tobytes(); views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(data),'target':34963}); blob=pad(blob+data)
    accs.append({'bufferView':len(views)-1,'componentType':5125,'count':len(idx),'type':'SCALAR'})
    views.append({'buffer':0,'byteOffset':len(blob),'byteLength':len(imgbytes)}); blob=pad(blob+imgbytes)
    name=f'final_boss_phase{g+1}'
    gj={'asset':{'version':'2.0','generator':'zero-depth split.py (from the owner tripo3d file)'},'scene':0,'scenes':[{'nodes':[0]}],
        'nodes':[{'name':name,'mesh':0}],'meshes':[{'name':name,'primitives':[{'attributes':amap,'indices':len(accs)-1,'material':0}]}],
        'materials':j['materials'],'textures':j['textures'],'samplers':j.get('samplers',[]) or [{}],
        'images':[{'name':img.get('name'),'mimeType':img['mimeType'],'bufferView':len(views)-1}],
        'accessors':accs,'bufferViews':views,'buffers':[{'byteLength':len(blob)}]}
    if not j.get('samplers'):
        for t in gj['textures']: t.pop('sampler',None)
        gj.pop('samplers')
    js=pad(json.dumps(gj).encode(),b' ')
    glb=b'glTF'+struct.pack('<II',2,12+8+len(js)+8+len(blob))+struct.pack('<I',len(js))+b'JSON'+js+struct.pack('<I',len(blob))+b'BIN\0'+blob
    open(f'{out}/{name}.glb','wb').write(glb)
    print(name,'verts',len(used),'tris',len(tri),'size (x,y,z)',np.round(pos.max(0)-pos.min(0),3).tolist())
# preview: side view z vs y, coloured by group
W,H=1500,520; im=Image.new('RGB',(W,H),(30,30,34)); d=ImageDraw.Draw(im)
col=[(230,90,70),(90,200,120),(90,140,240)]
zs=(P[:,2]+0.52)/1.04*W; ys=H-20-(P[:,1]+0.17)/0.34*(H-40)
for g in range(3):
    m=group==g
    for x,y in zip(zs[m][::2],ys[m][::2]): d.point((x,y),fill=col[g])
for c in CUTS: x=(c+0.52)/1.04*W; d.line((x,0,x,H),fill=(255,255,255))
im.save(f'{out}/split_preview.png')
