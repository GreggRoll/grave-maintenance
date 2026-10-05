#!/usr/bin/env python3
"""Generate small original prototype cues without external asset dependencies."""
import math
import random
import struct
import wave
from pathlib import Path

DEST = Path(__file__).resolve().parents[1] / 'assets/audio'
DEST.mkdir(parents=True, exist_ok=True)
RATE = 22050
random.seed(77)

def write(name, duration, sample):
    frames = bytearray()
    for i in range(int(duration * RATE)):
        t = i / RATE
        envelope = min(1, t * 70) * min(1, (duration-t) * 20)
        value = max(-1, min(1, sample(t) * envelope))
        frames.extend(struct.pack('<h', int(value * 18000)))
    with wave.open(str(DEST / (name + '.wav')), 'wb') as file:
        file.setparams((1, 2, RATE, 0, 'NONE', 'not compressed'))
        file.writeframes(frames)

write('shift', .6, lambda t: math.sin(2*math.pi*(440 if t < .3 else 660)*t)*.35)
write('warning', .8, lambda t: math.sin(2*math.pi*(520 if int(t*8)%2 == 0 else 390)*t)*.35)
write('danger', 1.3, lambda t: (math.sin(2*math.pi*(180+100*math.sin(t*12))*t)+math.sin(2*math.pi*92*t))*.24)
write('death', .7, lambda t: math.sin(2*math.pi*(210-180*t)*t)*.4)
write('work', .45, lambda t: math.sin(2*math.pi*72*t)*.12+(random.random()-.5)*.1)
write('spray', .18, lambda t: (random.random()-.5)*.35)
print('Generated original shift, warning, danger, death and work cues.')
