"""Writes icons.css next to this file: one CSS custom property per icon (24 px grid, mask image).
Stand-in icons for the previews; the live UI uses one tinted sprite sheet.  Run: py -3 make_icons.py"""
import os, urllib.parse

S = "fill='none' stroke='#000' stroke-width='2.4' stroke-linecap='square' stroke-linejoin='miter'"
F = "fill='#000' fill-rule='evenodd'"
ICONS = {
    "car": f"<path {F} d='M5 6h14l3 6v7h-4v-2H6v2H2v-7zM6.6 8.5L5.2 12h13.6l-1.4-3.5z'/>",
    "garage": f"<path {F} d='M2 10l10-7 10 7v11H2zM7 12.5h10v2H7zM7 16.5h10V21H7z'/>",
    "flag": f"<path {S} d='M5 3v19'/><path {F} d='M6 4h14v10H6zM10.7 4v5h4.6V4zM15.3 9v5H20V9zM6 9h4.7v5H6z'/>",
    "wrench": f"<path {F} d='M15 3a6 6 0 0 0-5.6 8.1L3 17.5 6.5 21l6.4-6.4A6 6 0 0 0 21 9l-.3-1.6-3.4 3.4-3-.7-.7-3 3.4-3.4L15.5 3z'/>",
    "sliders": f"<path {S} d='M3 7h18M3 17h18'/><path {F} d='M6 3.5h4v7H6zM14 13.5h4v7h-4z'/>",
    "exit": f"<path {S} d='M10 4H4v16h6M10 12h10M16 8l4 4-4 4'/>",
    "back": f"<path {S} d='M9 5L4 10l5 5M5 10h9a5 5 0 0 1 0 10h-4'/>",
    "wheel": f"<circle {S} cx='12' cy='12' r='9'/><circle {F} cx='12' cy='12' r='2.6'/><path {S} d='M4 10.5h5.5M14.5 10.5H20M12 15v5.5'/>",
    "pin": f"<path {F} d='M12 22s7-7.4 7-12.4A7 7 0 0 0 5 9.6C5 14.6 12 22 12 22zM12 6.8a2.8 2.8 0 1 0 0 5.6 2.8 2.8 0 0 0 0-5.6z'/>",
    "route": f"<path {S} d='M5 20V9a3.5 3.5 0 0 1 7 0v6a3.5 3.5 0 0 0 7 0V4'/>",
    "trophy": f"<path {F} d='M7 3h10v6a5 5 0 0 1-10 0zM10.8 14h2.4v4h-2.4zM7.5 19h9v2.5h-9z'/><path {S} d='M7 5H3.5v1.5A4 4 0 0 0 7 10.5M17 5h3.5v1.5a4 4 0 0 1-3.5 4'/>",
    "tick": f"<path fill='none' stroke='#000' stroke-width='3.4' stroke-linecap='square' d='M4 12.5l5.5 5.5L20 6.5'/>",
    "loop": f"<path {S} d='M19.5 9A8 8 0 0 0 5 8M4.5 15A8 8 0 0 0 19 16M19.5 3.5V9H14M4.5 20.5V15H10'/>",
    "gamepad": f"<path {F} d='M6 6h12a5 5 0 0 1 5 5v3.5a3.5 3.5 0 0 1-6.6 1.5h-8.8A3.5 3.5 0 0 1 1 14.5V11a5 5 0 0 1 5-5zM6.8 8.8v1.7H5.1v2h1.7v1.7h2v-1.7h1.7v-2H8.8V8.8zM15 9.4h2.2v2.2H15zM17.6 12h2.2v2.2h-2.2z'/>",
    "upgrade": f"<path {F} d='M12 2.5l8 8h-5V15H9v-4.5H4zM9 17h6v2H9zM9 20.5h6v1.5H9z'/>",
    "brush": f"<path {F} d='M20.5 2.5l1.5 1.5-9.5 10.5-3-3zM8 12.8l3.4 3.4c-.5 3-3 5-8.4 5 2-1.5 2-3 2.5-5 .4-1.6 1.2-2.7 2.5-3.4z'/>",
    "laps": f"<path {S} d='M7 6.5h10a5.5 5.5 0 0 1 0 11H7a5.5 5.5 0 0 1 0-11z'/><path {F} d='M11 3.5l5 3-5 3z'/>",
    "checkpoint": f"<path {S} d='M5 21V4M19 21V4M5 5h14M5 10h14'/>",
    "players": f"<circle {F} cx='8' cy='7.5' r='3.7'/><path {F} d='M1.5 21v-2a6.5 6.5 0 0 1 13 0v2z'/><circle {F} cx='17.3' cy='9' r='3'/><path {F} d='M16.3 21h6.2v-1.5a5.3 5.3 0 0 0-7.4-4.9 8.4 8.4 0 0 1 1.2 4.4z'/>",
    "person": f"<circle {F} cx='12' cy='7.5' r='4'/><path {F} d='M4.5 21.5v-2a7.5 7.5 0 0 1 15 0v2z'/>",
    "lock": f"<path {F} d='M5 10h14v11H5zM11 13.5v4h2v-4z'/><path {S} d='M8 10V7a4 4 0 0 1 8 0v3'/>",
    "coin": f"<circle {S} cx='12' cy='12' r='9.3'/><path fill='none' stroke='#000' stroke-width='2' d='M15 9c-.5-1-1.6-1.6-3-1.6-1.7 0-2.9.9-2.9 2.2 0 3 6 1.7 6 4.8 0 1.4-1.3 2.4-3.1 2.4-1.5 0-2.7-.6-3.2-1.7M12 5.6v12.8'/>",
    "plus": f"<path fill='none' stroke='#000' stroke-width='3.4' d='M12 4v16M4 12h16'/>",
    "minus": f"<path fill='none' stroke='#000' stroke-width='3.4' d='M4 12h16'/>",
    "map": f"<path {S} d='M3 6l6-2 6 2 6-2v14l-6 2-6-2-6 2zM9 4v14M15 6v14'/>",
    "close": f"<path fill='none' stroke='#000' stroke-width='3.2' d='M5 5l14 14M19 5L5 19'/>",
    "clock": f"<circle {S} cx='12' cy='12' r='9'/><path {S} d='M12 7v5.5l3.5 2'/>",
    "warn": f"<path {F} d='M12 2.5L23 21H1zM10.8 9v6h2.4V9zM10.8 16.5V19h2.4v-2.5z'/>",
    "up": f"<path {F} d='M12 5l8.5 13h-17z'/>",
    "down": f"<path {F} d='M12 19L3.5 6h17z'/>",
    "star": f"<path {F} d='M12 2l3 7 7.5.6-5.7 5 1.8 7.4L12 18l-6.6 4 1.8-7.4-5.7-5L9 9z'/>",
    "bolt": f"<path {F} d='M13.5 2L4 14h6l-1.5 8L19 9.5h-6z'/>",
    "box": f"<path {S} d='M3 7.5l9-4 9 4v9l-9 4-9-4zM3 7.5l9 4 9-4M12 11.5v9'/>",
    "target": f"<circle {S} cx='12' cy='12' r='9'/><circle {S} cx='12' cy='12' r='4.5'/><circle {F} cx='12' cy='12' r='1.6'/>",
    "right": f"<path {S} d='M4 12h15M13 6l6 6-6 6'/>",
    "left": f"<path {S} d='M20 12H5M11 6l-6 6 6 6'/>",
    "info": f"<circle {S} cx='12' cy='12' r='9.3'/><path {F} d='M10.8 10.5h2.4V18h-2.4zM10.8 6.5h2.4V9h-2.4z'/>",
    "eye": f"<path {S} d='M2 12c2.5-4.5 6-6.5 10-6.5S19.5 7.5 22 12c-2.5 4.5-6 6.5-10 6.5S4.5 16.5 2 12z'/><circle {F} cx='12' cy='12' r='3'/>",
    "desk": f"<path {F} d='M2 6h20v3H2zM4 10h2.5v10H4zM17.5 10H20v10h-2.5zM9 11h6v5H9z'/>",
    "swap": f"<path {S} d='M4 8h15M15 4l4 4-4 4M20 16H5M9 12l-4 4 4 4'/>",
    "cart": f"<path {S} d='M2 4h3l2.5 11h11L21 7H6.5'/><circle {F} cx='9' cy='19.5' r='1.8'/><circle {F} cx='17' cy='19.5' r='1.8'/>",
    "dot": f"<circle {F} cx='12' cy='12' r='6'/>",
    "diamond": f"<path {F} d='M12 2l8 10-8 10-8-10z'/>",
    "nav": f"<path {F} d='M12 2l8 19-8-5-8 5z'/>",
    "hand": f"<path {F} d='M9 2.5h3V11h1V5h3v6h1V7.5h3V16a6 6 0 0 1-6 6h-2.5A6.5 6.5 0 0 1 5 16.5L3 11l2.5-1.2L9 14z'/>",
    "undo": f"<path {S} d='M8 5L4 9l4 4M5 9h9a5 5 0 0 1 0 10H8'/>",
}

def main():
    out = ["/* generated by make_icons.py - do not edit */", ":root{"]
    for name, body in ICONS.items():
        svg = f"<svg xmlns='http://www.w3.org/2000/svg' viewBox='0 0 24 24'>{body}</svg>"
        out.append(f"  --i-{name}:url(\"data:image/svg+xml,{urllib.parse.quote(svg, safe=chr(39)+' =/:')}\");")
    out.append("}")
    for name in ICONS:
        out.append(f".ic.{name}{{--i:var(--i-{name})}}")
    path = os.path.join(os.path.dirname(os.path.abspath(__file__)), "icons.css")
    with open(path, "w", encoding="utf-8", newline="\n") as f:
        f.write("\n".join(out) + "\n")
    print("wrote", path, len(ICONS), "icons")

if __name__ == "__main__":
    main()
