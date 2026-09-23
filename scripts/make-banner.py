#!/usr/bin/env python3
"""Render the README header banner in both colour schemes.

Static on purpose: a hosted banner service is one more thing that can break the
page, and this never changes. Rerun after editing, then commit both SVGs.
The teal matches the avatar and is the one accent used by every card.
"""
from pathlib import Path

W, H = 1000, 220
NAME = "Joel Vandervalk"
TAGLINE = "I build iOS apps. Some of them even ship."
SUBLINE = "Swift · SwiftUI · TypeScript · Supabase"

# Echoes the avatar's identicon: 5x5, mirrored left to right.
GRID = [
    "01010",
    "00100",
    "11111",
    "10101",
    "01110",
]

THEMES = {
    "dark": dict(bg="0D1117", panel="161B22", stroke="30363D", accent="3DDBB8",
                 text="E6EDF3", muted="8B949E", faint="3DDBB8"),
    "light": dict(bg="FFFFFF", panel="F6F8FA", stroke="D0D7DE", accent="0E9F87",
                  text="1F2328", muted="59636E", faint="0E9F87"),
}

FONT = "-apple-system, BlinkMacSystemFont, 'Segoe UI', Helvetica, Arial, sans-serif"
MONO = "ui-monospace, SFMono-Regular, Menlo, Consolas, monospace"


def render(t: dict) -> str:
    cell, gap = 22, 4
    gx, gy = 70, (H - (5 * cell + 4 * gap)) // 2
    squares = []
    for r, row in enumerate(GRID):
        for c, on in enumerate(row):
            x, y = gx + c * (cell + gap), gy + r * (cell + gap)
            if on == "1":
                squares.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="4" fill="#{t["accent"]}"/>')
            else:
                squares.append(f'<rect x="{x}" y="{y}" width="{cell}" height="{cell}" rx="4" fill="#{t["faint"]}" fill-opacity="0.10"/>')
    tx = 260
    return f'''<svg xmlns="http://www.w3.org/2000/svg" width="{W}" height="{H}" viewBox="0 0 {W} {H}" role="img" aria-label="{NAME}. {TAGLINE}">
  <defs>
    <linearGradient id="glow" x1="0" y1="0" x2="1" y2="0">
      <stop offset="0" stop-color="#{t["accent"]}" stop-opacity="0.9"/>
      <stop offset="1" stop-color="#{t["accent"]}" stop-opacity="0"/>
    </linearGradient>
  </defs>
  <rect x="0.5" y="0.5" width="{W - 1}" height="{H - 1}" rx="14" fill="#{t["panel"]}" stroke="#{t["stroke"]}"/>
  {"".join(squares)}
  <text x="{tx}" y="98" font-family="{FONT}" font-size="46" font-weight="700" fill="#{t["text"]}">{NAME}</text>
  <text x="{tx}" y="138" font-family="{FONT}" font-size="21" fill="#{t["muted"]}">{TAGLINE}</text>
  <text x="{tx}" y="176" font-family="{MONO}" font-size="15" fill="#{t["accent"]}">{SUBLINE}</text>
  <rect x="{tx}" y="112" width="360" height="3" rx="1.5" fill="url(#glow)"/>
</svg>
'''


out = Path(__file__).resolve().parent.parent / "profile"
for name, theme in THEMES.items():
    (out / f"banner-{name}.svg").write_text(render(theme))
    print(f"wrote profile/banner-{name}.svg")
