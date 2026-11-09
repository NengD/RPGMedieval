# -*- coding: utf-8 -*-
"""Télécharge des textures PBR Poly Haven (CC0) en 1k : couleur, normale OpenGL, ARM (occlusion / rugosité / métal).
Usage : python tools/fetch_polyhaven.py <dossier_sortie> id[:nom_local] ...
"""
import sys, os, json, urllib.request

opener = urllib.request.build_opener()
opener.addheaders = [("User-Agent", "curl/8.0")]   # polyhaven refuse l'agent par défaut de Python
urllib.request.install_opener(opener)
out = sys.argv[1]
for spec in sys.argv[2:]:
    pid, _, local = spec.partition(":")
    local = local or pid
    info = json.load(urllib.request.urlopen("https://api.polyhaven.com/files/" + pid))
    folder = os.path.join(out, local)
    os.makedirs(folder, exist_ok=True)
    for key, name in (("Diffuse", "diff"), ("nor_gl", "nor_gl"), ("arm", "arm"), ("Rough", "rough")):
        entry = info.get(key, {}).get("1k", {}).get("jpg")
        if not entry:
            print(pid, key, "absent")
            continue
        path = os.path.join(folder, name + ".jpg")
        urllib.request.urlretrieve(entry["url"], path)
        print(pid, key, "->", path, os.path.getsize(path) // 1024, "Ko")
