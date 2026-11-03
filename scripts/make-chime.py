#!/usr/bin/env python3
"""フタを閉じたときに鳴らす優しいチャイムを生成する。

システム標準のアラート音は「警告」として強すぎるため、
減衰の長いベル系の二音を合成する。
    python3 scripts/make-chime.py Resources/LidWarning.wav
"""
import math
import struct
import sys
import wave

RATE = 44100
PEAK = 0.30          # 控えめに。警告であって驚かせたくない。
DURATION = 1.30

# G5 → C6。上行の完全四度で、詰問的でなく「気づかせる」響きにする。
NOTES = [
    (783.99, 0.00),
    (1046.50, 0.17),
]


def bell(t: float) -> float:
    """t 秒時点の振幅。基音に倍音を薄く足してベルらしくする。"""
    total = 0.0
    for freq, onset in NOTES:
        age = t - onset
        if age < 0:
            continue
        # 立ち上がり 10ms、以降は指数減衰
        attack = min(1.0, age / 0.010)
        decay = math.exp(-age / 0.42)
        env = attack * decay
        total += env * (
            math.sin(2 * math.pi * freq * age)
            + 0.30 * math.sin(2 * math.pi * freq * 2 * age)
            + 0.10 * math.sin(2 * math.pi * freq * 3 * age)
        )
    return total


def main() -> None:
    out = sys.argv[1] if len(sys.argv) > 1 else "LidWarning.wav"
    frames = int(RATE * DURATION)
    raw = [bell(i / RATE) for i in range(frames)]

    peak = max(abs(v) for v in raw) or 1.0
    scale = PEAK / peak

    data = bytearray()
    for i, v in enumerate(raw):
        # 末尾 30ms はゼロへ落としてプチノイズを防ぐ
        tail = frames - i
        if tail < RATE * 0.030:
            v *= tail / (RATE * 0.030)
        data += struct.pack("<h", int(max(-1.0, min(1.0, v * scale)) * 32767))

    with wave.open(out, "wb") as w:
        w.setnchannels(1)
        w.setsampwidth(2)
        w.setframerate(RATE)
        w.writeframes(bytes(data))
    print(f"wrote {out} ({len(data)} bytes, {DURATION}s)")


if __name__ == "__main__":
    main()
