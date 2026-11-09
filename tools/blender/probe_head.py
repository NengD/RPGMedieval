import bpy, sys
exec(open("E:/_jeu perso/rpgmedieval/tools/blender/make_armor.py", encoding="utf-8").read().split("# ------------------------------------------------------------------ outils bmesh")[0].replace("argv = sys.argv[sys.argv.index(\"--\") + 1:]", "argv = ['E:/_jeu perso/sources_mixamo/base_body.fbx','/tmp/a','/tmp/b']"))
vs=[v.co for v in body.data.vertices]
import collections
reg=[]
for v in body.data.vertices:
    best=None
    for g in v.groups:
        if best is None or g.weight>best[1]: best=(g.group,g.weight)
    reg.append(region_of(GROUPS[best[0]]) if best else "hips")
h=[vs[i] for i in range(len(vs)) if reg[i]=="head"]
print("HEADVERTS",len(h))
for a,n in ((0,"x"),(1,"y"),(2,"z")):
    print("HEAD",n,min(p[a] for p in h),max(p[a] for p in h))
# profil : y du point le plus avant par tranche de z
import math
for z in [1.50,1.55,1.58,1.60,1.62,1.64,1.66,1.68,1.70,1.72,1.74,1.76]:
    sl=[p for p in h if abs(p.z-z)<0.006]
    if sl: print("Z %.2f  x[%.3f,%.3f] y[%.3f,%.3f]"%(z,min(p.x for p in sl),max(p.x for p in sl),min(p.y for p in sl),max(p.y for p in sl)))
