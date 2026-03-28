from PIL import Image
import os

src = '/home/user/Documents/BuyBeat/BuyBeat/assets/icon/Icon.png'
base = '/home/user/Documents/BuyBeat/BuyBeat'
img = Image.open(src)
print(f"Source: {img.size}, mode={img.mode}")

# ── Android mipmap sizes ──────────────────────────────────────
android_sizes = {
    'mipmap-mdpi': 48,
    'mipmap-hdpi': 72,
    'mipmap-xhdpi': 96,
    'mipmap-xxhdpi': 144,
    'mipmap-xxxhdpi': 192,
}
for folder, size in android_sizes.items():
    path = os.path.join(base, 'android/app/src/main/res', folder, 'ic_launcher.png')
    img.resize((size, size), Image.LANCZOS).save(path, 'PNG')
    print(f'  Android {folder}: {size}x{size}')

# ── assets/icon/icon.png (lowercase – used by pubspec) ────────
img.resize((1024, 1024), Image.LANCZOS).save(
    os.path.join(base, 'assets/icon/icon.png'), 'PNG')
print('  assets/icon/icon.png: 1024x1024')

# ── iOS: flatten RGBA onto white (no transparency allowed) ────
ios_flat = Image.new('RGB', img.size, (255, 255, 255))
if img.mode == 'RGBA':
    ios_flat.paste(img, mask=img.split()[3])
else:
    ios_flat.paste(img)

ios_dir = os.path.join(base, 'ios/Runner/Assets.xcassets/AppIcon.appiconset')
ios_sizes = [
    ('Icon-App-20x20@1x.png', 20),
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
    ('Icon-App-83.5x83.5@2x.png', 167),
    ('Icon-App-1024x1024@1x.png', 1024),
]
for name, size in ios_sizes:
    ios_flat.resize((size, size), Image.LANCZOS).save(
        os.path.join(ios_dir, name), 'PNG')
print(f'  iOS: {len(ios_sizes)} sizes written')

# ── Web icons ─────────────────────────────────────────────────
web_dir = os.path.join(base, 'web/icons')
img.resize((192, 192), Image.LANCZOS).save(
    os.path.join(web_dir, 'Icon-192.png'), 'PNG')
img.resize((512, 512), Image.LANCZOS).save(
    os.path.join(web_dir, 'Icon-512.png'), 'PNG')
img.resize((192, 192), Image.LANCZOS).save(
    os.path.join(web_dir, 'Icon-maskable-192.png'), 'PNG')
img.resize((512, 512), Image.LANCZOS).save(
    os.path.join(web_dir, 'Icon-maskable-512.png'), 'PNG')
img.resize((16, 16), Image.LANCZOS).save(
    os.path.join(base, 'web/favicon.png'), 'PNG')
print('  Web icons: 192, 512, maskable-192, maskable-512, favicon(16)')

print('\nAll icons applied successfully!')
