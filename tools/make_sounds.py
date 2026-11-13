"""Synthesises Brasswick's sound effects into audio/*.wav.

Every sound is generated from noise and sine waves, so the game ships with no
recorded audio. They are simple placeholders: to use a recording instead,
replace the .wav of the same name (mono or stereo, any sample rate).

Usage (needs only Python 3):
  python tools/make_sounds.py
"""
import math
import os
import random
import struct
import wave

RATE = 22050
OUT = os.path.join(os.path.dirname(os.path.abspath(__file__)), "..", "audio")
rng = random.Random(1869)


def silence(seconds):
    return [0.0] * int(RATE * seconds)


def noise(seconds):
    return [rng.uniform(-1.0, 1.0) for _ in range(int(RATE * seconds))]


def low_pass(samples, cutoff):
    """One-pole low-pass filter."""
    a = 1.0 - math.exp(-2.0 * math.pi * cutoff / RATE)
    out, y = [], 0.0
    for x in samples:
        y += a * (x - y)
        out.append(y)
    return out


def high_pass(samples, cutoff):
    low = low_pass(samples, cutoff)
    return [x - l for x, l in zip(samples, low)]


def band(samples, low, high):
    return high_pass(low_pass(samples, high), low)


def tone(freq, seconds, phase=0.0):
    return [math.sin(2.0 * math.pi * freq * i / RATE + phase) for i in range(int(RATE * seconds))]


def decay(samples, half_life):
    """Exponential fade: the level halves every `half_life` seconds."""
    k = math.log(2.0) / (half_life * RATE)
    return [x * math.exp(-k * i) for i, x in enumerate(samples)]


def fade(samples, fade_in=0.005, fade_out=0.02):
    n, a, b = len(samples), int(RATE * fade_in), int(RATE * fade_out)
    out = list(samples)
    for i in range(min(a, n)):
        out[i] *= i / a
    for i in range(min(b, n)):
        out[n - 1 - i] *= i / b
    return out


def gain(samples, amount):
    return [x * amount for x in samples]


def mix(*layers):
    out = [0.0] * max(len(layer) for layer in layers)
    for layer in layers:
        for i, x in enumerate(layer):
            out[i] += x
    return out


def at(samples, seconds):
    """Delay a layer by `seconds`, for use inside mix()."""
    return silence(seconds) + samples


def normalise(samples, peak=0.85):
    top = max(abs(x) for x in samples) or 1.0
    return [x * peak / top for x in samples]


def make_loop(samples, seconds, cross=0.6):
    """Cut `samples` to a seamless loop of `seconds`, cross-fading its end
    into its start. Needs at least `seconds + cross` of material."""
    n, f = int(RATE * seconds), int(RATE * cross)
    out = samples[:n]
    for i in range(f):
        t = i / f
        out[i] = samples[i] * t + samples[n + i] * (1.0 - t)
    return out


def save(name, samples, peak=0.85):
    samples = normalise(samples, peak)
    os.makedirs(OUT, exist_ok=True)
    path = os.path.join(OUT, name + ".wav")
    with wave.open(path, "wb") as f:
        f.setnchannels(1)
        f.setsampwidth(2)
        f.setframerate(RATE)
        f.writeframes(b"".join(struct.pack("<h", int(max(-1.0, min(1.0, x)) * 32767)) for x in samples))
    print("%-16s %5.2f s" % (name + ".wav", len(samples) / RATE))


def swell(samples, cycles, depth, seconds, phase=0.0):
    """Slow rise and fall in level, a whole number of `cycles` per loop."""
    return [x * (1.0 - depth + depth * (0.5 + 0.5 * math.sin(2.0 * math.pi * cycles * i / (RATE * seconds) + phase)))
            for i, x in enumerate(samples)]


def hit(freq, seconds=0.12, half_life=0.03):
    """A dull knock: a short thump with a burst of noise on top."""
    return mix(decay(tone(freq, seconds), half_life),
               gain(decay(band(noise(seconds), 800, 4000), half_life * 0.5), 0.6))


def clank(seconds=0.5, pitch=1.0):
    """Metal on metal: a few sine partials that do not line up."""
    parts = [(830, 1.0, 0.09), (1270, 0.7, 0.07), (2130, 0.5, 0.05), (3410, 0.3, 0.03)]
    return mix(*[gain(decay(tone(f * pitch, seconds), h), a) for f, a, h in parts],
               gain(decay(band(noise(0.03), 2000, 8000), 0.008), 0.8))


def wind_loop():
    seconds = 10.0
    raw = noise(seconds + 1.0)
    low = swell(band(raw, 120, 500), 2, 0.6, seconds)
    high = swell(band(noise(seconds + 1.0), 500, 1400), 3, 0.8, seconds, 1.3)
    return make_loop(mix(low, gain(high, 0.5)), seconds)


def city_loop():
    seconds = 8.0
    total = seconds + 1.0
    # A whole number of cycles per loop keeps the hum seamless.
    hum = mix(tone(55.0, total), gain(tone(110.0, total, 0.7), 0.5), gain(tone(82.5, total, 1.9), 0.3))
    hum = swell(hum, 4, 0.35, seconds)
    murmur = gain(swell(band(noise(total), 200, 900), 3, 0.5, seconds, 0.8), 0.5)
    layers = [hum, murmur]
    for when, pitch in ((1.3, 0.8), (4.1, 1.1), (6.2, 0.7)):
        layers.append(at(gain(low_pass(clank(0.4, pitch), 1800), 0.25), when))
    chuff = gain(decay(band(noise(0.25), 300, 1500), 0.06), 0.35)
    for beat in range(16):
        layers.append(at(chuff, 0.7 + beat * 0.5))
    return make_loop(mix(*layers), seconds)


def build():
    knocks = [at(hit(190 + 25 * i), 0.16 * i) for i in range(3)]
    thud = at(mix(decay(tone(70, 0.4), 0.07), gain(decay(low_pass(noise(0.4), 400), 0.06), 0.7)), 0.5)
    return fade(mix(*knocks, thud))


def road():
    return fade(decay(band(noise(0.16), 600, 3500), 0.035))


def demolish():
    rumble = decay(low_pass(noise(1.0), 220), 0.22)
    crack = gain(decay(band(noise(0.2), 900, 5000), 0.03), 0.8)
    debris = [at(gain(decay(band(noise(0.08), 500, 3000), 0.02), 0.4), 0.2 + 0.11 * i) for i in range(5)]
    return fade(mix(rumble, crack, *debris), fade_out=0.1)


def repair():
    return fade(mix(clank(0.45), at(clank(0.45, 1.12), 0.2), at(gain(clank(0.5, 0.94), 0.8), 0.42)))


def click():
    return fade(decay(mix(tone(1400, 0.04), gain(band(noise(0.04), 2000, 7000), 0.5)), 0.008), 0.001, 0.005)


def error():
    buzz = mix(tone(140, 0.18), gain(tone(210, 0.18), 0.5), gain(tone(283, 0.18), 0.3))
    return fade(buzz, 0.005, 0.04)


def day_bell():
    parts = [(660, 1.0, 0.35), (1320, 0.5, 0.25), (1985, 0.3, 0.15), (2640, 0.15, 0.1)]
    return fade(mix(*[gain(decay(tone(f, 1.6), h), a) for f, a, h in parts]), fade_out=0.2)


def event():
    def whistle(freq, seconds):
        body = mix(tone(freq, seconds), gain(tone(freq * 2.01, seconds), 0.4), gain(tone(freq * 3.02, seconds), 0.2))
        breath = gain(band(noise(seconds), 1500, 6000), 0.25)
        return fade(mix(body, breath), 0.04, 0.12)
    return mix(whistle(523, 0.45), at(whistle(659, 0.7), 0.5))


def breakdown():
    clunk = mix(decay(tone(95, 0.3), 0.05), gain(clank(0.3, 0.6), 0.6))
    hiss = at(fade(decay(band(noise(1.1), 2500, 9000), 0.3), 0.08, 0.3), 0.15)
    return mix(clunk, gain(hiss, 0.6))


def game_over():
    layers = []
    for i, freq in enumerate((392, 330, 262, 196)):
        note = mix(tone(freq, 0.9), gain(tone(freq * 2, 0.9), 0.3))
        layers.append(at(fade(decay(note, 0.3), 0.02, 0.2), 0.45 * i))
    return mix(*layers)


if __name__ == "__main__":
    save("wind_loop", wind_loop(), 0.7)
    save("city_loop", city_loop(), 0.7)
    save("build", build())
    save("road", road(), 0.6)
    save("demolish", demolish())
    save("repair", repair(), 0.7)
    save("click", click(), 0.5)
    save("error", error(), 0.5)
    save("day_bell", day_bell(), 0.6)
    save("event", event(), 0.7)
    save("breakdown", breakdown(), 0.8)
    save("game_over", game_over(), 0.8)
