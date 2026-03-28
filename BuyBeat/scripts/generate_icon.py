#!/usr/bin/env python3
"""Generate BuyBeat app icon — green palette with a music note."""

from PIL import Image, ImageDraw, ImageFont
import math, os

SIZE = 1024
CENTER = SIZE // 2

def make_icon():
    img = Image.new('RGBA', (SIZE, SIZE), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # ── Background: rounded square with gradient-like green
    # We'll draw a circle-cornered rect with a radial-ish solid green
    bg_color = (16, 185, 85)       # #10B955  (main green)
    dark_bg  = (10, 140, 64)       # darker edge
    
    # Draw rounded rectangle background
    corner_r = SIZE // 5  # ~200px radius corners (Android adaptive icon compatible)
    draw.rounded_rectangle(
        [(0, 0), (SIZE - 1, SIZE - 1)],
        radius=corner_r,
        fill=bg_color,
    )

    # Subtle darker circle at bottom-right for depth
    for r in range(SIZE // 2, 0, -1):
        alpha = int(40 * (1 - r / (SIZE // 2)))
        ox, oy = CENTER + SIZE // 6, CENTER + SIZE // 6
        draw.ellipse(
            [ox - r, oy - r, ox + r, oy + r],
            fill=(0, 0, 0, alpha),
        )

    # ── Music note (♪) — draw geometrically for crispness
    # Eighth note: vertical stem + filled oval note head + flag

    note_color = (255, 255, 255)  # white
    shadow_color = (0, 0, 0, 60)

    # Note head (oval) — bottom-left area of center
    head_cx = CENTER - 60
    head_cy = CENTER + 200
    head_rx = 110  # horizontal radius
    head_ry = 85   # vertical radius
    head_angle = -25  # tilt degrees

    # Draw shadow first
    _draw_note(draw, head_cx + 8, head_cy + 8, head_rx, head_ry, head_angle,
               shadow_color, SIZE)
    # Draw note
    _draw_note(draw, head_cx, head_cy, head_rx, head_ry, head_angle,
               note_color, SIZE)

    return img


def _draw_note(draw, head_cx, head_cy, head_rx, head_ry, head_angle, color, SIZE):
    """Draw an eighth note (♪) shape."""

    # Note head (tilted ellipse)
    # We'll draw with a polygon approximation
    pts = []
    for deg in range(360):
        rad = math.radians(deg)
        x = head_rx * math.cos(rad)
        y = head_ry * math.sin(rad)
        # Rotate
        a = math.radians(head_angle)
        rx = x * math.cos(a) - y * math.sin(a)
        ry = x * math.sin(a) + y * math.cos(a)
        pts.append((head_cx + rx, head_cy + ry))
    draw.polygon(pts, fill=color)

    # Stem — vertical line from right side of head going up
    stem_x = head_cx + head_rx * math.cos(math.radians(head_angle)) * 0.75
    stem_bottom = head_cy - head_ry * 0.3
    stem_top = head_cy - 420
    stem_width = 28

    draw.rectangle(
        [stem_x - stem_width // 2, stem_top,
         stem_x + stem_width // 2, stem_bottom],
        fill=color,
    )

    # Flag — curved shape from top of stem going right and down
    flag_pts = []
    top_x = stem_x + stem_width // 2
    top_y = stem_top

    # Bezier-like curve with polygon approximation
    for t in [i / 40 for i in range(41)]:
        # Control points for a nice flag curve
        p0 = (top_x, top_y)
        p1 = (top_x + 160, top_y + 40)
        p2 = (top_x + 120, top_y + 200)
        p3 = (top_x + 20, top_y + 260)

        # Cubic bezier
        x = ((1-t)**3 * p0[0] + 3*(1-t)**2*t * p1[0] +
             3*(1-t)*t**2 * p2[0] + t**3 * p3[0])
        y = ((1-t)**3 * p0[1] + 3*(1-t)**2*t * p1[1] +
             3*(1-t)*t**2 * p2[1] + t**3 * p3[1])
        flag_pts.append((x, y))

    # Add thickness to flag by creating inner curve
    inner_pts = []
    for t in [i / 40 for i in range(41)]:
        p0 = (top_x, top_y + 45)
        p1 = (top_x + 120, top_y + 80)
        p2 = (top_x + 90, top_y + 220)
        p3 = (top_x + 10, top_y + 270)

        x = ((1-t)**3 * p0[0] + 3*(1-t)**2*t * p1[0] +
             3*(1-t)*t**2 * p2[0] + t**3 * p3[0])
        y = ((1-t)**3 * p0[1] + 3*(1-t)**2*t * p1[1] +
             3*(1-t)*t**2 * p2[1] + t**3 * p3[1])
        inner_pts.append((x, y))

    flag_shape = flag_pts + list(reversed(inner_pts))
    if len(flag_shape) > 2:
        draw.polygon(flag_shape, fill=color)


if __name__ == '__main__':
    icon = make_icon()

    base = os.path.dirname(os.path.abspath(__file__))
    project = os.path.dirname(base)

    # Save the 1024x1024 source
    icon_dir = os.path.join(project, 'assets', 'icon')
    os.makedirs(icon_dir, exist_ok=True)
    src_path = os.path.join(icon_dir, 'icon.png')
    icon.save(src_path, 'PNG')
    print(f'Saved {src_path}')

    # Generate Android mipmap sizes
    android_sizes = {
        'mipmap-mdpi': 48,
        'mipmap-hdpi': 72,
        'mipmap-xhdpi': 96,
        'mipmap-xxhdpi': 144,
        'mipmap-xxxhdpi': 192,
    }
    res_dir = os.path.join(project, 'android', 'app', 'src', 'main', 'res')
    for folder, size in android_sizes.items():
        out_dir = os.path.join(res_dir, folder)
        os.makedirs(out_dir, exist_ok=True)
        resized = icon.resize((size, size), Image.LANCZOS)
        out_path = os.path.join(out_dir, 'ic_launcher.png')
        resized.save(out_path, 'PNG')
        print(f'Saved {out_path} ({size}x{size})')

    # iOS icon (no transparency, no rounded corners — iOS adds them)
    ios_icon = Image.new('RGB', (1024, 1024), (16, 185, 85))
    ios_draw = ImageDraw.Draw(ios_icon)
    # Paste the note from the RGBA icon onto solid green
    ios_icon.paste(icon, (0, 0), icon)
    ios_dir = os.path.join(project, 'ios', 'Runner', 'Assets.xcassets',
                           'AppIcon.appiconset')
    if os.path.isdir(ios_dir):
        ios_path = os.path.join(ios_dir, 'Icon-App-1024x1024@1x.png')
        ios_icon.save(ios_path, 'PNG')
        print(f'Saved {ios_path}')
        # Also common iOS sizes
        for name, s in [('Icon-App-20x20@1x.png', 20),
                        ('Icon-App-20x20@2x.png', 40),
                        ('Icon-App-20x20@3x.png', 60),
                        ('Icon-App-29x29@1x.png', 29),
                        ('Icon-App-29x29@2x.png', 58),
                        ('Icon-App-29x29@3x.png', 87),
                        ('Icon-App-40x40@1x.png', 40),
                        ('Icon-App-40x40@2x.png', 80),
                        ('Icon-App-40x40@3x.png', 120),
                        ('Icon-App-60x60@2x.png', 120),
                        ('Icon-App-60x60@3x.png', 180),
                        ('Icon-App-76x76@1x.png', 76),
                        ('Icon-App-76x76@2x.png', 152),
                        ('Icon-App-83.5x83.5@2x.png', 167)]:
            ios_icon.resize((s, s), Image.LANCZOS).save(
                os.path.join(ios_dir, name), 'PNG')

    # Web favicon
    web_dir = os.path.join(project, 'web', 'icons')
    os.makedirs(web_dir, exist_ok=True)
    icon.resize((192, 192), Image.LANCZOS).save(
        os.path.join(web_dir, 'Icon-192.png'), 'PNG')
    icon.resize((512, 512), Image.LANCZOS).save(
        os.path.join(web_dir, 'Icon-512.png'), 'PNG')
    icon.resize((16, 16), Image.LANCZOS).save(
        os.path.join(project, 'web', 'favicon.png'), 'PNG')
    print('Saved web icons')

    print('\nDone! App icon generated for Android, iOS, and Web.')
