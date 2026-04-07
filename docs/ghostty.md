# Ghostty

Ghostty is a fast, native terminal emulator focused on correctness and performance. It supports font fallback, GPU rendering, and modern terminal features out of the box.

## Installation

Ghostty is installed as a macOS cask via the Brewfile:

```ruby
cask "ghostty"
```

The installer (`install.sh`) symlinks the configuration file into place:

```
config/ghostty/config  -->  ~/.config/ghostty/config
```

## Font configuration

The config uses a two-font strategy -- a plain coding font as the primary, with a symbols-only Nerd Font as a fallback for icons and glyphs:

```
font-family = Fira Code
font-family = Symbols Nerd Font Mono
font-size = 13
```

Ghostty evaluates `font-family` lines in order. The first entry (`Fira Code`) is the primary font used for all standard text. The second entry (`Symbols Nerd Font Mono`) is the fallback, used only when a glyph is missing from the primary font -- typically Nerd Font icons used by tools like starship, eza, and nvim plugins.

This avoids the need for patched "Nerd Font" variants (e.g., "FiraCode Nerd Font"). Patched fonts bundle thousands of extra glyphs into the main font file, which can cause rendering quirks and makes font updates harder to track. The fallback approach keeps each font clean and single-purpose.

Both fonts are installed via the Brewfile:

| Cask | Purpose |
|------|---------|
| `font-fira-code` | Primary coding font with programming ligatures |
| `font-symbols-only-nerd-font` | Icon/glyph fallback for all terminals |

## Customizing

Edit `config/ghostty/config` directly. Ghostty uses a simple `key = value` format with no nesting. Changes take effect when you open a new Ghostty window or reload the config.

Common additions:

```
# Change the color scheme
theme = catppuccin-mocha

# Adjust cursor style
cursor-style = block
cursor-style-blink = false

# Window padding
window-padding-x = 8
window-padding-y = 8

# Key bindings
keybind = super+t=new_tab
```

To swap the primary font, replace the first `font-family` line. Keep the `Symbols Nerd Font Mono` fallback line so that icon glyphs continue to render correctly.

Run `ghostty +list-themes` to see available built-in themes, or `ghostty +list-keybinds` to see current key bindings. Full configuration reference is available at [ghostty.org/docs/config](https://ghostty.org/docs/config).
