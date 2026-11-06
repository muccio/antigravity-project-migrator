import os
import subprocess
import math
from PIL import Image, ImageDraw

def create_app_icon():
    size = 1024
    img = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    draw = ImageDraw.Draw(img)

    # 1. Base squircle / rounded rect with padding
    padding = 80
    rect = [padding, padding, size - padding, size - padding]
    corner_radius = 200

    # Draw gradient background by vertical slices inside rounded rect mask
    mask = Image.new("L", (size, size), 0)
    mask_draw = ImageDraw.Draw(mask)
    mask_draw.rounded_rectangle(rect, radius=corner_radius, fill=255)

    bg = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    bg_draw = ImageDraw.Draw(bg)
    for y in range(padding, size - padding):
        factor = (y - padding) / float(size - 2 * padding)
        # Gradient from deep royal indigo (26, 20, 56) to dark cyan navy (15, 32, 67)
        r = int(24 * (1 - factor) + 12 * factor)
        g = int(22 * (1 - factor) + 40 * factor)
        b = int(58 * (1 - factor) + 90 * factor)
        bg_draw.line([(padding, y), (size - padding, y)], fill=(r, g, b, 255))

    img.paste(bg, (0, 0), mask)

    # 2. Add subtle inner border
    draw.rounded_rectangle(rect, radius=corner_radius, outline=(255, 255, 255, 40), width=4)

    # 3. Antigravity Orbit / Ring
    center_x, center_y = size // 2, size // 2 - 20
    orbit_radius_x = 340
    orbit_radius_y = 120
    orbit_box = [center_x - orbit_radius_x, center_y - orbit_radius_y, center_x + orbit_radius_x, center_y + orbit_radius_y]
    
    # Outer glowing orbit
    draw.arc(orbit_box, start=-30, end=210, fill=(138, 92, 246, 180), width=18)
    draw.arc(orbit_box, start=150, end=330, fill=(56, 189, 248, 220), width=18)

    # 4. External SSD / Drive Representation in the center
    drive_w = 400
    drive_h = 240
    dx1 = center_x - drive_w // 2
    dy1 = center_y - drive_h // 2
    dx2 = center_x + drive_w // 2
    dy2 = center_y + drive_h // 2

    # Drive shadow
    shadow = Image.new("RGBA", (size, size), (0, 0, 0, 0))
    shadow_draw = ImageDraw.Draw(shadow)
    shadow_draw.rounded_rectangle([dx1 + 10, dy1 + 25, dx2 + 10, dy2 + 25], radius=32, fill=(0, 0, 0, 100))
    img = Image.alpha_composite(img, shadow)
    draw = ImageDraw.Draw(img)

    # Drive body (Metallic dark gray / blue)
    draw.rounded_rectangle([dx1, dy1, dx2, dy2], radius=32, fill=(30, 41, 59, 255), outline=(99, 102, 241, 200), width=6)

    # Drive front ridge / connector detail
    draw.rounded_rectangle([dx1 + 30, dy1 + 35, dx2 - 30, dy1 + 75], radius=12, fill=(15, 23, 42, 255))
    
    # Glowing status LED
    draw.ellipse([dx2 - 70, dy1 + 45, dx2 - 50, dy1 + 65], fill=(34, 197, 94, 255)) # Green LED

    # Center Antigravity logo / Sparkle / Link
    # Double transfer arrow / Link icon
    draw.arc([center_x - 70, dy1 + 95, center_x + 70, dy1 + 195], start=45, end=225, fill=(56, 189, 248, 255), width=12)
    draw.polygon([(center_x - 65, dy1 + 160), (center_x - 85, dy1 + 195), (center_x - 45, dy1 + 195)], fill=(56, 189, 248, 255))

    draw.arc([center_x - 70, dy1 + 95, center_x + 70, dy1 + 195], start=225, end=405, fill=(168, 85, 247, 255), width=12)
    draw.polygon([(center_x + 65, dy1 + 130), (center_x + 85, dy1 + 95), (center_x + 45, dy1 + 95)], fill=(168, 85, 247, 255))

    # Center floating particle
    draw.ellipse([center_x - 14, dy1 + 135, center_x + 14, dy1 + 163], fill=(255, 255, 255, 255))

    # Small planet/satellite orbiting
    sat_x = center_x + int(orbit_radius_x * math.cos(math.radians(-25)))
    sat_y = center_y + int(orbit_radius_y * math.sin(math.radians(-25)))
    draw.ellipse([sat_x - 22, sat_y - 22, sat_x + 22, sat_y + 22], fill=(56, 189, 248, 255), outline=(255, 255, 255, 200), width=4)

    # 5. Output iconset
    iconset_dir = "AppIcon.iconset"
    os.makedirs(iconset_dir, exist_ok=True)

    sizes = [
        (16, "icon_16x16.png"),
        (32, "icon_16x16@2x.png"),
        (32, "icon_32x32.png"),
        (64, "icon_32x32@2x.png"),
        (128, "icon_128x128.png"),
        (256, "icon_128x128@2x.png"),
        (256, "icon_256x256.png"),
        (512, "icon_256x256@2x.png"),
        (512, "icon_512x512.png"),
        (1024, "icon_512x512@2x.png")
    ]

    for s, name in sizes:
        resized = img.resize((s, s), Image.Resampling.LANCZOS)
        resized.save(os.path.join(iconset_dir, name))

    # Convert to icns
    subprocess.run(["iconutil", "-c", "icns", iconset_dir, "-o", "src/Resources/AppIcon.icns"], check=True)
    print("AppIcon.icns generated successfully!")

if __name__ == "__main__":
    create_app_icon()
