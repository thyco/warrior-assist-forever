#!/usr/bin/env python3
"""Create the tintable white shield-corner triangle used by the stance icon."""

from pathlib import Path


SIZE = 64
SAMPLES = 4
DESTINATION = Path(__file__).resolve().parents[1] / "WarriorAssistForever/Media/ShieldCorner.tga"


def main():
    header = bytearray(18)
    header[2] = 2
    header[12:14] = SIZE.to_bytes(2, "little")
    header[14:16] = SIZE.to_bytes(2, "little")
    header[16] = 32
    header[17] = 0x28

    pixels = bytearray()
    for y in range(SIZE):
        for x in range(SIZE):
            covered = sum(
                x + (sample_x + 0.5) / SAMPLES
                + y + (sample_y + 0.5) / SAMPLES < SIZE
                for sample_y in range(SAMPLES)
                for sample_x in range(SAMPLES)
            )
            alpha = round(255 * covered / (SAMPLES * SAMPLES))
            pixels.extend((255, 255, 255, alpha))

    DESTINATION.write_bytes(header + pixels)
    print(f"Generated {DESTINATION}")


if __name__ == "__main__":
    main()
