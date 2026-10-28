
import math
import os
import struct
import wave

os.makedirs("assets", exist_ok=True)

sample_rate = 44100
duration = 0.035
frequency = 1800
samples_count = int(sample_rate * duration)

with wave.open("assets/click.wav", "wb") as wav:
    wav.setnchannels(1)
    wav.setsampwidth(2)
    wav.setframerate(sample_rate)

    samples = []
    for i in range(samples_count):
        t = i / sample_rate
        envelope = math.exp(-100 * t)
        value = int(
            20000 * envelope *
            math.sin(2 * math.pi * frequency * t)
        )
        samples.append(struct.pack("<h", value))

    wav.writeframes(b"".join(samples))

print("assets/click.wav gerado em PCM 16-bit mono.")
