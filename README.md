# if.lsp

A unified LSP UI layer for Neovim — hover, diagnostics, code actions, signature help, inlay hints, and scope breadcrumbs in one place.

## Install

### lazy.nvim

```lua
{
  "if-then-nvim/if.lsp",
  main = "if.lsp",
  dependencies = { "nvim-tree/nvim-web-devicons" },
  event = "LspAttach",
  opts = {},
}
```

See [config.lua](lua/if/lsp/config.lua) for all default values.

### Requirements

- Neovim >= 0.11 (`client:request`, `vim.diagnostic.jump`, `vim.hl`)
- LSP client configured

## Usage

After `setup()`, a global `IfLsp` table is registered. All modules are lazy-loaded on first access.

```lua
IfLsp.hover()
IfLsp.definition()
IfLsp.code_action()
IfLsp.signature_help()

IfLsp.diagnostic.goto_next()
IfLsp.diagnostic.goto_prev()
IfLsp.diagnostic.open_float()

IfLsp.inlay_hint.toggle()
IfLsp.inlay_hint.enable(bufnr)
IfLsp.inlay_hint.disable(bufnr)

IfLsp.scope.toggle()
IfLsp.scope.get_data(bufnr)
IfLsp.scope.get_location(bufnr)
IfLsp.scope.is_available(bufnr)

-- require style works identically
local iflsp = require("if.lsp")
iflsp.hover()
```

### Commands

```
:IfLsp                  " hover (default)
:IfLsp hover
:IfLsp definition
:IfLsp code_action
:IfLsp signature_help
:IfLsp inlay_hint       " toggle
:IfLsp scope            " toggle
```

### Keymaps example

```lua
vim.keymap.set("n", "K", function() IfLsp.hover() end)
vim.keymap.set("n", "gd", function() IfLsp.definition() end)
vim.keymap.set("n", "<leader>ca", function() IfLsp.code_action() end)
vim.keymap.set("n", "]d", function() IfLsp.diagnostic.goto_next() end)
vim.keymap.set("n", "[d", function() IfLsp.diagnostic.goto_prev() end)
```

## API

| Function | Description |
| --- | --- |
| `IfLsp.setup(opts)` | Initialize with optional config |
| `IfLsp.hover()` | Show hover info, focus if already open |
| `IfLsp.definition()` | Go to definition with beacon effect |
| `IfLsp.code_action()` | Show code actions with diff preview |
| `IfLsp.signature_help()` | Show signature help popup |
| `IfLsp.diagnostic.goto_next()` | Jump to next diagnostic with float |
| `IfLsp.diagnostic.goto_prev()` | Jump to previous diagnostic with float |
| `IfLsp.diagnostic.open_float()` | Open diagnostic float at cursor |
| `IfLsp.inlay_hint.enable(bufnr)` | Enable inlay hints |
| `IfLsp.inlay_hint.disable(bufnr)` | Disable inlay hints |
| `IfLsp.inlay_hint.toggle(bufnr)` | Toggle inlay hints |
| `IfLsp.scope.toggle()` | Toggle scope breadcrumbs |
| `IfLsp.scope.get_data(bufnr)` | Get scope data for buffer |
| `IfLsp.scope.get_location(bufnr)` | Get current scope location string |
| `IfLsp.scope.is_available(bufnr)` | Check if scope is available |

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
| `IfLspNormal` | `NormalFloat` |
| `IfLspBorder` | `FloatBorder` |
| `IfLspTitle` | `Title` |
| `IfLspBeacon` | `Search` |
| `IfLspActionNumber` | `Number` |
| `IfLspDiffAdd` | `DiffAdd` |
| `IfLspDiffDelete` | `DiffDelete` |
| `IfLspDiffHunk` | `Comment` |
| `IfLspHoverKind` | `Function` |
| `IfLspHoverKindAlias` | `Special` |
| `IfLspHoverKindFunction` | `Function` |
| `IfLspHoverKindProperty` | `@property` |
| `IfLspHoverKindVariable` | `@variable` |
| `IfLspHoverKindType` | `Type` |
| `IfLspHoverKindEnum` | `Constant` |
| `IfLspHoverKindModule` | `@module` |

## Hover Kind Icons

LSP hover responses often include a kind prefix like `(alias)`, `(method)`, `(function)`, etc. IfLsp parses these and displays a matching icon in the sign column with kind-specific highlighting.

By default the prefix text is concealed (icon only). Set `show_kind_prefix = true` to keep the text visible.

```lua
require("if.lsp").setup({
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
| `alias` | 󰌹 | `IfLspHoverKindAlias` |
| `function` / `method` / `constructor` | 󰊕 | `IfLspHoverKindFunction` |
| `property` / `index` | 󰜢 | `IfLspHoverKindProperty` |
| `variable` / `parameter` / `const` / `let` | 󰀫 | `IfLspHoverKindVariable` |
| `class` / `interface` / `type alias` / `type` | 󰠱 | `IfLspHoverKindType` |
| `enum` / `enum member` | 󰕘 | `IfLspHoverKindEnum` |
| `namespace` / `module` | 󰅩 | `IfLspHoverKindModule` |
| `import` | 󰋺 | `IfLspHoverKindModule` |
| `export` | 󰈕 | `IfLspHoverKindModule` |

## Custom Tag Parsers

Icons for doc comment tags in hover. jsdoc, doxygen, and python parsers are built-in.

```lua
require("if.lsp").setup({
  parsers = {
    ["@mycustomtag"] = { icon = "!", hl = "Special" },
  },
})
```

## License

MIT
