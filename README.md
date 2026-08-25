# glose.nvim

A unified LSP UI layer for Neovim — hover, diagnostics, code actions, signature help, inlay hints, and scope breadcrumbs in one place.

`glose` is French for a *gloss* — the note medieval scribes wrote in the margin
and between the lines of a difficult text.

## Install

### lazy.nvim

```lua
{
  "if-then-end/glose.nvim",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "LspAttach",
  opts = {},
}
```

See [config.lua](lua/glose/config.lua) for all default values.

### Requirements

- Neovim >= 0.11 (`client:request`, `vim.diagnostic.jump`, `vim.hl`)
- LSP client configured

## Usage

After `setup()`, a global `Glose` table is registered. All modules are lazy-loaded on first access.

```lua
Glose.hover()
Glose.definition()
Glose.code_action()
Glose.signature_help()

Glose.diagnostic.goto_next()
Glose.diagnostic.goto_prev()
Glose.diagnostic.open_float()

Glose.inlay_hint.toggle()
Glose.inlay_hint.enable(bufnr)
Glose.inlay_hint.disable(bufnr)

Glose.scope.toggle()
Glose.scope.get_data(bufnr)
Glose.scope.get_location(bufnr)
Glose.scope.is_available(bufnr)

-- require style works identically
local glose = require("glose")
glose.hover()
```

### Commands

```
:Glose                  " hover (default)
:Glose hover
:Glose definition
:Glose code_action
:Glose signature_help
:Glose inlay_hint       " toggle
:Glose scope            " toggle
```

### Keymaps example

```lua
vim.keymap.set("n", "K", function() Glose.hover() end)
vim.keymap.set("n", "gd", function() Glose.definition() end)
vim.keymap.set("n", "<leader>ca", function() Glose.code_action() end)
vim.keymap.set("n", "]d", function() Glose.diagnostic.goto_next() end)
vim.keymap.set("n", "[d", function() Glose.diagnostic.goto_prev() end)
```

## API

| Function | Description |
| --- | --- |
| `Glose.setup(opts)` | Initialize with optional config |
| `Glose.hover()` | Show hover info, focus if already open |
| `Glose.definition()` | Go to definition with beacon effect |
| `Glose.code_action()` | Show code actions with diff preview |
| `Glose.signature_help()` | Show signature help popup |
| `Glose.diagnostic.goto_next()` | Jump to next diagnostic with float |
| `Glose.diagnostic.goto_prev()` | Jump to previous diagnostic with float |
| `Glose.diagnostic.open_float()` | Open diagnostic float at cursor |
| `Glose.inlay_hint.enable(bufnr)` | Enable inlay hints |
| `Glose.inlay_hint.disable(bufnr)` | Disable inlay hints |
| `Glose.inlay_hint.toggle(bufnr)` | Toggle inlay hints |
| `Glose.scope.toggle()` | Toggle scope breadcrumbs |
| `Glose.scope.get_data(bufnr)` | Get scope data for buffer |
| `Glose.scope.get_location(bufnr)` | Get current scope location string |
| `Glose.scope.is_available(bufnr)` | Check if scope is available |

## Development

```sh
make test     # plenary suite
make lint     # stylua --check + selene
make format   # stylua
make check    # lint + test
```

## Highlights

All groups link to built-in highlights by default. Override via the `highlights` option.

| Group | Default Link |
| --- | --- |
| `GloseNormal` | `NormalFloat` |
| `GloseBorder` | `FloatBorder` |
| `GloseTitle` | `Title` |
| `GloseBeacon` | `Search` |
| `GloseActionNumber` | `Number` |
| `GloseDiffAdd` | `DiffAdd` |
| `GloseDiffDelete` | `DiffDelete` |
| `GloseDiffHunk` | `Comment` |
| `GloseHoverKind` | `Function` |
| `GloseHoverKindAlias` | `Special` |
| `GloseHoverKindFunction` | `Function` |
| `GloseHoverKindProperty` | `@property` |
| `GloseHoverKindVariable` | `@variable` |
| `GloseHoverKindType` | `Type` |
| `GloseHoverKindEnum` | `Constant` |
| `GloseHoverKindModule` | `@module` |

## Hover Kind Icons

LSP hover responses often include a kind prefix like `(alias)`, `(method)`, `(function)`, etc. Glose parses these and displays a matching icon in the sign column with kind-specific highlighting.

By default the prefix text is concealed (icon only). Set `show_kind_prefix = true` to keep the text visible.

```lua
require("glose").setup({
  hover = {
    show_kind_prefix = false, -- true to show "(alias)" text alongside the icon
  },
  glyph = {
    hover_kind = {
      alias = "A", -- override any kind icon
    },
  },
})
```

Default kind mappings:

| Kind | Icon | Highlight |
| --- | --- | --- |
| `alias` | 󰌹 | `GloseHoverKindAlias` |
| `function` / `method` / `constructor` | 󰊕 | `GloseHoverKindFunction` |
| `property` / `index` | 󰜢 | `GloseHoverKindProperty` |
| `variable` / `parameter` / `const` / `let` | 󰀫 | `GloseHoverKindVariable` |
| `class` / `interface` / `type alias` / `type` | 󰠱 | `GloseHoverKindType` |
| `enum` / `enum member` | 󰕘 | `GloseHoverKindEnum` |
| `namespace` / `module` | 󰅩 | `GloseHoverKindModule` |
| `import` | 󰋺 | `GloseHoverKindModule` |
| `export` | 󰈕 | `GloseHoverKindModule` |

## Custom Tag Parsers

Icons for doc comment tags in hover. jsdoc, doxygen, and python parsers are built-in.

```lua
require("glose").setup({
  parsers = {
    ["@mycustomtag"] = { icon = "!", hl = "Special" },
  },
})
```

## License

MIT
