# -*- coding: utf-8 -*-
"""Assemble des dossiers d'images (f0000.png…) en vidéos MP4 avec le montage vidéo de Blender (pas de ffmpeg nécessaire).
  blender -b --factory-startup -P tools/blender/frames_to_mp4.py -- <dossier_prev> <dossier_sortie> <fps> <repetitions> nom1 nom2 ...
"""
import sys, os, glob
import bpy
argv = sys.argv[sys.argv.index("--") + 1:]
src, out, fps, reps = argv[0], argv[1], int(argv[2]), int(argv[3])
os.makedirs(out, exist_ok=True)
for name in argv[4:]:
    files = sorted(glob.glob(os.path.join(src, name, "f*.png")))
    if not files:
        print("VIDEO vide :", name)
        continue
    bpy.ops.wm.read_factory_settings(use_empty=True)
    sc = bpy.context.scene
    sc.render.fps = fps
    sc.render.resolution_x = 900
    sc.render.resolution_y = 520
    sc.render.resolution_percentage = 100
    sc.sequence_editor_create()
    ed = sc.sequence_editor
    frame = 1
    for r in range(reps):
        for f in files:
            st = ed.strips.new_image("s%d_%s" % (frame, os.path.basename(f)), f, channel=1, frame_start=frame)
            st.frame_final_duration = 1
            frame += 1
        # petit arrêt entre deux répétitions : on tient la dernière image
        for k in range(max(1, fps // 4)):
            st = ed.strips.new_image("h%d_%d" % (frame, k), files[-1], channel=1, frame_start=frame)
            st.frame_final_duration = 1
            frame += 1
    sc.frame_start = 1
    sc.frame_end = frame - 1
    try:
        sc.render.image_settings.media_type = "VIDEO"   # Blender 5 : le type de média se règle avant le format
    except Exception:
        pass
    sc.render.image_settings.file_format = "FFMPEG"
    sc.render.ffmpeg.format = "MPEG4"
    sc.render.ffmpeg.codec = "H264"
    sc.render.ffmpeg.constant_rate_factor = "MEDIUM"
    sc.render.filepath = os.path.join(out, name + ".mp4")
    sc.render.use_sequencer = True
    bpy.ops.render.render(animation=True)
    print("VIDEO", name, os.path.getsize(os.path.join(out, name + ".mp4")) // 1024, "Ko")
