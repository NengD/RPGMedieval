# -*- coding: utf-8 -*-
"""Génère les effets sonores du jeu (synthèse, aucune ressource externe) dans assets/sounds/*.wav.
Chaque son existe en 3 variantes (nom_1, nom_2, nom_3) pour éviter la répétition. Mono, 22 050 Hz, 16 bits.
  python tools/make_sounds.py <dossier_sortie>
"""
import sys, os, math, random, struct, wave

SR = 22050
OUT = sys.argv[1] if len(sys.argv) > 1 else "assets/sounds"
os.makedirs(OUT, exist_ok=True)


def n_samples(sec):
    return int(sec * SR)


def noise(n, rnd):
    return [rnd.uniform(-1, 1) for _ in range(n)]


def lowpass(x, cutoff):
    a = min(1.0, 2 * math.pi * cutoff / SR)
    y, s = [], 0.0
    for v in x:
        s += a * (v - s)
        y.append(s)
    return y


def highpass(x, cutoff):
    lp = lowpass(x, cutoff)
    return [v - l for v, l in zip(x, lp)]


def bandpass(x, lo, hi):
    return lowpass(highpass(x, lo), hi)


def env_exp(n, decay_sec, attack_sec=0.002):
    out = []
    na = max(1, int(attack_sec * SR))
    for i in range(n):
        a = min(1.0, i / na)
        out.append(a * math.exp(-i / (decay_sec * SR)))
    return out


def sine(n, f, phase=0.0, vib=0.0, vib_f=6.0):
    return [math.sin(2 * math.pi * f * i / SR + phase + vib * math.sin(2 * math.pi * vib_f * i / SR)) for i in range(n)]


def mul(a, b):
    return [x * y for x, y in zip(a, b)]


def add(*sigs):
    n = max(len(s) for s in sigs)
    out = [0.0] * n
    for s in sigs:
        for i, v in enumerate(s):
            out[i] += v
    return out


def scale(x, g):
    return [v * g for v in x]


def pad(x, n):
    return x + [0.0] * (n - len(x)) if len(x) < n else x[:n]


def normalize(x, peak=0.8):
    m = max(abs(v) for v in x) or 1.0
    return [v * peak / m for v in x]


def fade(x, ms=8):
    k = int(ms / 1000 * SR)
    for i in range(min(k, len(x))):
        g = i / k
        x[i] *= g
        x[-1 - i] *= g
    return x


def save(name, x, peak=0.8):
    x = fade(normalize(x, peak))
    with wave.open(os.path.join(OUT, name + ".wav"), "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(SR)
        w.writeframes(b"".join(struct.pack("<h", int(max(-1, min(1, v)) * 32767)) for v in x))


def metal_hit(rnd, f0, decay, size=1.0):
    n = n_samples(decay * 5)
    partials = [1.0, 2.76, 5.40, 8.93, 13.3]
    sig = [0.0] * n
    for k, p in enumerate(partials):
        f = f0 * p * rnd.uniform(0.98, 1.02)
        sig = add(sig, scale(mul(sine(n, f, rnd.uniform(0, 6)), env_exp(n, decay / (1 + 0.7 * k))), 1.0 / (1 + 0.6 * k)))
    tick = scale(mul(highpass(noise(n, rnd), 2500), env_exp(n, 0.012, 0.0005)), 0.9 * size)
    return add(sig, tick)


def rnd_for(name, v):
    return random.Random(hash((name, v)) & 0xFFFFFFFF if False else (sum(ord(c) for c in name) * 131 + v * 977))


def make(name, fn, variants=3, peak=0.8):
    for v in range(1, variants + 1):
        save("%s_%d" % (name, v), fn(rnd_for(name, v)), peak)


# ---------------------------------------------------------------- combat
def acier(r):
    return metal_hit(r, r.uniform(700, 1050), 0.09)


def parade(r):
    return add(metal_hit(r, r.uniform(1100, 1500), 0.12, 1.2), scale(mul(lowpass(noise(n_samples(0.5), r), 400), env_exp(n_samples(0.5), 0.05)), 0.6))


def parade_parfaite(r):
    n = n_samples(0.9)
    base = metal_hit(r, r.uniform(1300, 1700), 0.25, 1.3)
    shimmer = [0.0] * n
    for f in (2900, 4100, 5600, 7300):
        shimmer = add(shimmer, scale(mul(sine(n, f * r.uniform(0.99, 1.01), vib=0.4, vib_f=5), env_exp(n, 0.32)), 0.25))
    return add(pad(base, n), shimmer)


def mailles(r):
    n = n_samples(0.35)
    out = [0.0] * n
    for _ in range(26):
        t = int(r.uniform(0, 0.18) * SR)
        f = r.uniform(3500, 7500)
        tick = scale(mul(sine(n_samples(0.04), f, r.uniform(0, 6)), env_exp(n_samples(0.04), 0.008, 0.0005)), r.uniform(0.2, 0.7))
        for i, v in enumerate(tick):
            if t + i < n:
                out[t + i] += v
    return add(out, scale(mul(bandpass(noise(n, r), 1500, 6000), env_exp(n, 0.08)), 0.5))


def bois(r):
    n = n_samples(0.35)
    f = r.uniform(110, 170)
    return add(scale(mul(sine(n, f, 0, vib=0.1), env_exp(n, 0.09)), 1.0), scale(mul(lowpass(noise(n, r), 1800), env_exp(n, 0.04)), 0.9))


def chair(r):
    n = n_samples(0.3)
    return add(scale(mul(sine(n, r.uniform(65, 90)), env_exp(n, 0.1)), 1.0), scale(mul(lowpass(noise(n, r), 700), env_exp(n, 0.06)), 1.2))


def whoosh(r):
    n = n_samples(0.32)
    x = bandpass(noise(n, r), 600, 3000)
    e = [math.sin(math.pi * i / n) ** 2 for i in range(n)]
    return mul(x, e)


# ---------------------------------------------------------------- pas
def pas_pave(r):
    n = n_samples(0.22)
    return add(scale(mul(highpass(noise(n, r), 1200), env_exp(n, 0.012, 0.0005)), 0.8), scale(mul(sine(n, r.uniform(110, 150)), env_exp(n, 0.05)), 0.9))


def pas_plaques(r):
    n = n_samples(0.45)
    jingle = scale(metal_hit(r, r.uniform(1800, 2600), 0.05, 0.5), 0.55)
    return add(pad(pas_pave(r), n), pad(jingle, n), scale(mul(bandpass(noise(n, r), 800, 4000), env_exp(n, 0.1)), 0.5))


def pas_mailles(r):
    n = n_samples(0.4)
    return add(pad(pas_pave(r), n), pad(scale(mailles(r), 0.6), n))


def pas_cuir(r):
    n = n_samples(0.2)
    return add(scale(mul(lowpass(noise(n, r), 1500), env_exp(n, 0.02)), 0.8), scale(mul(sine(n, r.uniform(90, 120)), env_exp(n, 0.05)), 0.8))


# ---------------------------------------------------------------- tir
def arc(r):
    n = n_samples(0.5)
    twang = mul(sine(n, r.uniform(180, 240), vib=1.2, vib_f=22), env_exp(n, 0.12, 0.001))
    return add(twang, scale(mul(highpass(noise(n, r), 2000), env_exp(n, 0.03, 0.0005)), 0.6), scale(whoosh_n(r, n, 0.3), 0.5))


def whoosh_n(r, n, dur):
    m = n_samples(dur)
    x = bandpass(noise(m, r), 1000, 4000)
    return pad(mul(x, [math.sin(math.pi * i / m) ** 2 for i in range(m)]), n)


def arbalete(r):
    n = n_samples(0.45)
    thunk = mul(sine(n, r.uniform(70, 95)), env_exp(n, 0.1, 0.001))
    snap = mul(highpass(noise(n, r), 1500), env_exp(n, 0.02, 0.0005))
    twang = mul(sine(n, r.uniform(380, 460), vib=0.6, vib_f=30), env_exp(n, 0.1))
    return add(thunk, scale(snap, 0.9), scale(twang, 0.5))


def fleche_plantee(r):
    n = n_samples(0.5)
    thud = add(scale(mul(sine(n, r.uniform(120, 160)), env_exp(n, 0.06, 0.001)), 1.0), scale(mul(lowpass(noise(n, r), 1500), env_exp(n, 0.03)), 0.7))
    quiver = scale(mul(sine(n, r.uniform(520, 640), vib=2.0, vib_f=40), env_exp(n, 0.22)), 0.35)
    return add(thud, quiver)


# ---------------------------------------------------------------- voix
def souffle(r):
    n = n_samples(0.35)
    x = bandpass(noise(n, r), 500, 2500)
    e = [math.sin(math.pi * i / n) ** 1.5 for i in range(n)]
    return mul(x, e)


def voix(f0, dur, r, rough=0.2, formants=((700, 1.0), (1200, 0.7), (2600, 0.3))):
    n = n_samples(dur)
    src = []
    ph = 0.0
    for i in range(n):
        t = i / n
        f = f0 * (1.0 + 0.25 * (0.5 - t)) * (1 + 0.01 * math.sin(i * 0.03))
        ph += f / SR
        src.append((ph % 1.0) * 2 - 1 + rough * r.uniform(-1, 1))
    out = [0.0] * n
    for fc, g in formants:
        out = add(out, scale(bandpass(src, fc * 0.8, fc * 1.25), g))
    e = [min(1.0, i / (0.03 * SR)) * math.exp(-3.0 * i / n) for i in range(n)]
    return mul(out, e)


def effort(r):
    return voix(r.uniform(105, 135), 0.28, r, 0.4, ((600, 1.0), (1000, 0.6), (2400, 0.2)))


def cri(r):
    return voix(r.uniform(150, 190), 0.45, r, 0.25, ((750, 1.0), (1300, 0.7), (2700, 0.3)))


# ---------------------------------------------------------------- ambiance et musique (boucles)
def loop_fade(x, ms=400):
    k = int(ms / 1000 * SR)
    n = len(x)
    out = x[:n - k]
    for i in range(k):
        g = i / k
        out[i] = out[i] * g + x[n - k + i] * (1 - g)
    return out


def vent(r):
    n = n_samples(8.0)
    base = lowpass(noise(n, r), 380)
    gust = lowpass(noise(n, r), 0.35)
    gmax = max(abs(v) for v in gust) or 1
    sig = [b * (0.55 + 0.45 * (g / gmax)) for b, g in zip(base, gust)]
    return loop_fade(sig)


def drone(r):
    n = n_samples(10.0)
    out = [0.0] * n
    for f, g in ((55.0, 1.0), (82.4, 0.6), (110.0, 0.5), (164.8, 0.25), (220.0, 0.12)):
        slow = [0.6 + 0.4 * math.sin(2 * math.pi * (0.07 + 0.02 * g) * i / SR + g) for i in range(n)]
        out = add(out, scale(mul(sine(n, f * r.uniform(0.997, 1.003)), slow), g))
    return loop_fade(out)


make("acier", acier)
make("parade", parade)
make("parade_parfaite", parade_parfaite)
make("mailles", mailles)
make("bois", bois)
make("chair", chair)
make("elan", whoosh, peak=0.6)
make("pas_pave", pas_pave, peak=0.5)
make("pas_plaques", pas_plaques, peak=0.6)
make("pas_mailles", pas_mailles, peak=0.55)
make("pas_cuir", pas_cuir, peak=0.45)
make("arc", arc)
make("arbalete", arbalete)
make("fleche_plantee", fleche_plantee)
make("effort", effort, peak=0.6)
make("cri", cri, peak=0.7)
make("vent", vent, variants=1, peak=0.5)
make("drone", drone, variants=1, peak=0.45)
print("sons générés :", len(os.listdir(OUT)))
