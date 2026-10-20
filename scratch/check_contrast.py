def srgb_to_linear(c):
    if c <= 0.04045:
        return c / 12.92
    else:
        return ((c + 0.055) / 1.055) ** 2.4

def relative_luminance(r, g, b):
    r_lin = srgb_to_linear(r)
    g_lin = srgb_to_linear(g)
    b_lin = srgb_to_linear(b)
    return 0.2126 * r_lin + 0.7152 * g_lin + 0.0722 * b_lin

def composite(fg_rgb, fg_alpha, bg_rgb):
    return tuple(fg_alpha * c + (1.0 - fg_alpha) * bg_c for c, bg_c in zip(fg_rgb, bg_rgb))

def contrast_ratio(rgb1, rgb2):
    l1 = relative_luminance(*rgb1)
    l2 = relative_luminance(*rgb2)
    lighter = max(l1, l2)
    darker = min(l1, l2)
    return (lighter + 0.05) / (darker + 0.05)

# Current tokens
tokens = {
    "textPrimary": ((1.0, 1.0, 1.0), 1.0),
    "textSecondary": ((1.0, 1.0, 1.0), 0.80),
    "textTertiary": ((1.0, 1.0, 1.0), 0.60),
    "accent": ((0.18, 0.52, 0.98), 1.0),
    "alertAmber": ((0.96, 0.65, 0.14), 1.0),
    "rainBlue": ((0.35, 0.65, 1.0), 1.0),
    "rainBlueLight": ((0.55, 0.85, 1.0), 1.0),
}

# Backgrounds
backgrounds = {
    "bgGradient.start": (0.18, 0.42, 0.82),
    "bgGradient.end": (0.05, 0.19, 0.50),
    "cardSolid": (0.08, 0.16, 0.32),
    "clearDay.darkest": (0.05, 0.20, 0.50),
    "clearDay.lightest": (0.16, 0.38, 0.66),
    "partlyCloudy.darkest": (0.06, 0.18, 0.44),
    "partlyCloudy.lightest": (0.18, 0.36, 0.60),
    "rain.darkest": (0.10, 0.18, 0.30),
    "rain.lightest": (0.35, 0.42, 0.50),
    "snow.darkest": (0.18, 0.27, 0.42),
    "snow.lightest": (0.65, 0.72, 0.80),
    "fog/cloudy.darkest": (0.14, 0.18, 0.25),
    "fog/cloudy.lightest": (0.50, 0.54, 0.60),
    "night.darkest": (0.03, 0.04, 0.11),
    "night.lightest": (0.10, 0.15, 0.28),
}

print(f"{'Token':<16} | {'Background':<22} | {'Contrast Ratio':<15} | {'4.5:1 (Body)':<13} | {'3.0:1 (Large/Icon)'}")
print("-" * 80)

failures_body = []
failures_large = []

for t_name, (fg_rgb, fg_a) in tokens.items():
    for bg_name, bg_rgb in backgrounds.items():
        comp_rgb = composite(fg_rgb, fg_a, bg_rgb)
        cr = contrast_ratio(comp_rgb, bg_rgb)
        pass_45 = cr >= 4.5
        pass_30 = cr >= 3.0
        if not pass_45:
            failures_body.append((t_name, bg_name, cr))
        if not pass_30:
            failures_large.append((t_name, bg_name, cr))
        if not pass_45:
            print(f"{t_name:<16} | {bg_name:<22} | {cr:6.2f}:1         | {'FAIL' if not pass_45 else 'PASS':<13} | {'FAIL' if not pass_30 else 'PASS'}")

print("\nTotal 4.5:1 failures:", len(failures_body))
print("Total 3.0:1 failures:", len(failures_large))
