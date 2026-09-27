#!/usr/bin/env python3
"""Renders a preview image of the generated levels from `layout.json`.

This is *not* a Godot screenshot (the sandbox used to build the project has no
GPU and no OpenGL/Vulkan drivers, so the engine can only run headless). It
draws the exact brick/paddle/ball positions that the engine's own
`LevelGen` + `Boot` constants produced:

    godot --headless --path . --script res://tools/dump_level_layout.gd > layout.json
    python3 tools/render_level_preview.py layout.json preview_levels.png

Pure standard library: a tiny PNG writer plus rectangle rasterisation.
"""

from __future__ import annotations

import colorsys
import json
import struct
import sys
import zlib

SCALE = 0.42          # per-level canvas downscale
COLS = 3              # levels per row in the montage
PAD = 10


class Canvas:
    def __init__(self, width: int, height: int) -> None:
        self.w = width
        self.h = height
        self.px = bytearray(width * height * 3)

    def blend(self, x: int, y: int, color: tuple[float, float, float], alpha: float = 1.0) -> None:
        if x < 0 or y < 0 or x >= self.w or y >= self.h or alpha <= 0.0:
            return
        i = (y * self.w + x) * 3
        for c in range(3):
            base = self.px[i + c] / 255.0
            self.px[i + c] = int(max(0.0, min(1.0, base * (1.0 - alpha) + color[c] * alpha)) * 255)

    def rect(self, x: float, y: float, w: float, h: float, color, alpha: float = 1.0) -> None:
        x0, y0 = int(round(x)), int(round(y))
        x1, y1 = int(round(x + w)), int(round(y + h))
        for yy in range(max(y0, 0), min(y1, self.h)):
            for xx in range(max(x0, 0), min(x1, self.w)):
                self.blend(xx, yy, color, alpha)

    def hline(self, x0: float, x1: float, y: float, color, thickness: float = 1.0, alpha: float = 1.0) -> None:
        self.rect(x0, y - thickness * 0.5, x1 - x0, thickness, color, alpha)

    def vline(self, x: float, y0: float, y1: float, color, thickness: float = 1.0, alpha: float = 1.0) -> None:
        self.rect(x - thickness * 0.5, y0, thickness, y1 - y0, color, alpha)

    def save_png(self, path: str) -> None:
        raw = bytearray()
        for y in range(self.h):
            raw.append(0)
            raw += self.px[y * self.w * 3:(y + 1) * self.w * 3]

        def chunk(tag: bytes, data: bytes) -> bytes:
            return (struct.pack(">I", len(data)) + tag + data
                    + struct.pack(">I", zlib.crc32(tag + data) & 0xFFFFFFFF))

        header = struct.pack(">IIBBBBB", self.w, self.h, 8, 2, 0, 0, 0)
        png = (b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", header)
               + chunk(b"IDAT", zlib.compress(bytes(raw), 6)) + chunk(b"IEND", b""))
        with open(path, "wb") as handle:
            handle.write(png)


# 5x7 bitmap digits so the montage can be labelled without a font dependency.
DIGITS = {
    "0": ["01110", "10001", "10011", "10101", "11001", "10001", "01110"],
    "1": ["00100", "01100", "00100", "00100", "00100", "00100", "01110"],
    "2": ["01110", "10001", "00001", "00010", "00100", "01000", "11111"],
    "3": ["11110", "00001", "00001", "01110", "00001", "00001", "11110"],
    "4": ["00010", "00110", "01010", "10010", "11111", "00010", "00010"],
    "5": ["11111", "10000", "11110", "00001", "00001", "10001", "01110"],
    "6": ["00110", "01000", "10000", "11110", "10001", "10001", "01110"],
    "7": ["11111", "00001", "00010", "00100", "01000", "01000", "01000"],
    "8": ["01110", "10001", "10001", "01110", "10001", "10001", "01110"],
    "9": ["01110", "10001", "10001", "01111", "00001", "00010", "01100"],
}


def draw_number(canvas: Canvas, x: float, y: float, number: int, color, pixel: int = 2) -> None:
    for index, char in enumerate(str(number)):
        pattern = DIGITS.get(char, DIGITS["0"])
        for row, line in enumerate(pattern):
            for col, bit in enumerate(line):
                if bit == "1":
                    canvas.rect(x + (index * 6 + col) * pixel, y + row * pixel, pixel, pixel, color)


def hsv(hue: float, sat: float, val: float) -> tuple[float, float, float]:
    return colorsys.hsv_to_rgb(hue % 1.0, sat, val)


def draw_level(canvas: Canvas, level: dict, origin_x: float, origin_y: float, scale: float, arena, brick_size, paddle_y_world: float) -> None:
    # Panel background + arena.
    canvas.rect(origin_x, origin_y, arena[2] * scale, arena[3] * scale, (0.05, 0.06, 0.12))
    canvas.rect(origin_x, origin_y, arena[2] * scale, arena[3] * scale, (0.20, 0.45, 0.70), 0.10)
    frame = (0.35, 0.85, 1.0)
    for i in range(4):
        t = 1.0
        canvas.hline(origin_x + i, origin_x + arena[2] * scale - i, origin_y + i, frame, t, 0.35 - i * 0.06)
        canvas.hline(origin_x + i, origin_x + arena[2] * scale - i, origin_y + arena[3] * scale - i, (1.0, 0.35, 0.55), t, 0.45 - i * 0.06)
        canvas.vline(origin_x + i, origin_y + i, origin_y + arena[3] * scale - i, frame, t, 0.30 - i * 0.06)
        canvas.vline(origin_x + arena[2] * scale - i, origin_y + i, origin_y + arena[3] * scale - i, frame, t, 0.30 - i * 0.06)

    for brick in level["bricks"]:
        px, py = brick["pos"]
        x = origin_x + (px - arena[0]) * scale
        y = origin_y + (py - arena[1]) * scale
        w = brick_size[0] * scale
        h = brick_size[1] * scale
        wear = 0.0 if brick["hp"] <= 1 else min(0.5, (brick["hp"] - 1) * 0.22)
        color = hsv(brick["hue"], 0.72 - wear * 0.5, 1.0 - wear * 0.35)
        canvas.rect(x - 1, y - 1, w + 2, h + 2, color, 0.16)
        canvas.rect(x, y, w, h, color)
        canvas.rect(x, y, w, max(1.0, h * 0.16), tuple(min(1.0, c * 1.5) for c in color), 0.9)

    # Paddle + ball (the ball rests on the paddle before launch).
    paddle_y = origin_y + (paddle_y_world - arena[1]) * scale
    paddle_w = 140.0 * scale
    canvas.rect(origin_x + arena[2] * scale * 0.5 - paddle_w * 0.5, paddle_y, paddle_w, max(2.0, 18.0 * scale), (0.45, 0.95, 1.0))
    ball_x = origin_x + arena[2] * scale * 0.5 + paddle_w * 0.16
    ball_y = paddle_y - 9.0 * scale - 2
    ball_r = max(2.0, 9.0 * scale)
    canvas.rect(ball_x - ball_r, ball_y - ball_r, ball_r * 2, ball_r * 2, (0.92, 0.98, 1.0))


def main() -> None:
    source = sys.argv[1] if len(sys.argv) > 1 else "layout.json"
    target = sys.argv[2] if len(sys.argv) > 2 else "preview_levels.png"

    with open(source, "r", encoding="utf-8") as handle:
        data = json.load(handle)

    arena = data["arena"]
    brick_size = data["brick_size"]
    panel_w = arena[2] * SCALE
    panel_h = arena[3] * SCALE
    levels = data["levels"]
    rows = (len(levels) + COLS - 1) // COLS

    canvas = Canvas(int((panel_w + PAD) * COLS + PAD), int((panel_h + PAD) * rows + PAD))
    canvas.rect(0, 0, canvas.w, canvas.h, (0.02, 0.02, 0.05))

    for index, level in enumerate(levels):
        col = index % COLS
        row = index // COLS
        x = PAD + col * (panel_w + PAD)
        y = PAD + row * (panel_h + PAD)
        draw_level(canvas, level, x, y, SCALE, arena, brick_size, data["paddle_y"])
        draw_number(canvas, x + 8, y + 8, level["level"], (0.95, 0.98, 1.0), 3)

    canvas.save_png(target)
    print(f"{target}: {canvas.w}x{canvas.h}, {len(levels)} levels")


if __name__ == "__main__":
    main()
