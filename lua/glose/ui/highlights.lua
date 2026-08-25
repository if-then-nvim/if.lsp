local M = {}

local color = require "glose.ui.color"

local type_hl_sources = {
  number = { "@number", "Number" },
  string = { "@string", "String" },
  boolean = { "@boolean", "Boolean" },
  null = { "@constant.builtin", "Constant" },
  undefined = { "@constant.builtin", "Constant" },
  unknown = { "DiagnosticWarn", "@type" },
  never = { "DiagnosticError", "@constant.builtin" },
  array = { "@type", "Type" },
  object = { "@type", "Type" },
  ["function"] = { "@function", "Function" },
  promise = { "@type", "Type" },
}

local function resolve_hl_fg(sources, fallback)
  for _, name in ipairs(sources) do
    local fg = color.get_hl_color(name, "fg")
    if fg then
      return fg
    end
  end
  return fallback
end

local kind_hl_sources = {
  [1] = { "@text", "String" },
  [2] = { "@module", "@namespace", "Include" },
  [3] = { "@module", "@namespace", "Include" },
  [4] = { "@module", "Include" },
  [5] = { "@type", "Type" },
  [6] = { "@property", "@field", "Identifier" },
  [7] = { "@variable", "Identifier" },
  [8] = { "@constant", "Constant" },
  [9] = { "@type", "Type" },
  [10] = { "@function", "Function" },
  [11] = { "@constructor", "Special" },
  [12] = { "@function.method", "@method", "Function" },
  [13] = { "@type", "Type" },
  [14] = { "@type.qualifier", "StorageClass" },
  [15] = { "@type", "Type" },
  [16] = { "@function", "Function" },
  [17] = { "@number", "Number" },
  [18] = { "@string", "String" },
  [19] = { "@boolean", "Boolean" },
  [20] = { "@type", "Type" },
  [21] = { "@type", "Type" },
  [22] = { "@constant.builtin", "Constant" },
  [23] = { "@variable", "Identifier" },
  [24] = { "@keyword", "Keyword" },
  [25] = { "@constructor", "Special" },
  [26] = { "@type.parameter", "@type", "Type" },
}

local function create_scope_highlights()
  local normal_bg = color.get_hl_color("Normal", "bg") or "#1e1e2e"
  local cfg = require("glose.config").get()
  local user_overrides = cfg.highlights or {}
  local style = (cfg.scope and cfg.scope.biscuit and cfg.scope.biscuit.style) or "muted"

  local comment_fg = color.get_hl_color("Comment", "fg") or "#6c7086"
  local muted_bg = color.blend(comment_fg, normal_bg, 0.12)

  local function biscuit_opts(fg)
    if style == "fg" then
      return { fg = fg }
    elseif style == "tinted" then
      return { fg = fg, bg = color.blend(fg, normal_bg, 0.08) }
    else
      return { fg = fg, bg = muted_bg }
    end
  end

  for kind = 1, 26 do
    local sources = kind_hl_sources[kind] or { "@type", "Type" }
    local kind_fg = resolve_hl_fg(sources, "#89b4fa")

    local kind_name = "GloseScopeKind_" .. kind
    if not user_overrides[kind_name] then
      vim.api.nvim_set_hl(0, kind_name, { fg = kind_fg })
    end

    local bis_name = "GloseScopeBiscuit_" .. kind
    if not user_overrides[bis_name] then
      vim.api.nvim_set_hl(0, bis_name, biscuit_opts(kind_fg))
    end
  end

  local kw_fg = resolve_hl_fg({ "@keyword", "Keyword" }, "#cba6f7")
  if not user_overrides["GloseScopeBiscuitKeyword"] then
    vim.api.nvim_set_hl(0, "GloseScopeBiscuitKeyword", biscuit_opts(kw_fg))
  end

  if not user_overrides["GloseScopeText"] then
    vim.api.nvim_set_hl(0, "GloseScopeText", { link = "Normal" })
  end
  if not user_overrides["GloseScopeSeparator"] then
    vim.api.nvim_set_hl(0, "GloseScopeSeparator", { link = "Comment" })
  end
end

local function create_badge_highlights()
  local normal_bg = color.get_hl_color("Normal", "bg") or "#1e1e2e"
  local comment_fg = color.get_hl_color("Comment", "fg") or "#6c7086"

  local cfg = require("glose.config").get()
  local alpha = cfg.inlay_hint.badge_alpha

  local blue_tint = "#4fc1ff"
  local warm_tint = "#e5c07b"

  local blended_blue_bg = color.blend(blue_tint, normal_bg, alpha)
  local blended_warm_bg = color.blend(warm_tint, normal_bg, alpha)
  local blended_blue_fg = color.blend(blue_tint, comment_fg, 0.4)
  local blended_warm_fg = color.blend(warm_tint, comment_fg, 0.4)

  local badge_groups = {
    GloseInlayType = { fg = blended_blue_fg, bg = blended_blue_bg, italic = true },
    GloseInlayParam = { fg = blended_warm_fg, bg = blended_warm_bg, italic = true },
  }

  for kind, sources in pairs(type_hl_sources) do
    local src_fg = resolve_hl_fg(sources, blue_tint)
    local name = "GloseInlayType_" .. kind
    badge_groups[name] = {
      fg = color.blend(src_fg, comment_fg, 0.4),
      bg = color.blend(src_fg, normal_bg, alpha),
      italic = true,
    }
  end

  local fn_bg = badge_groups["GloseInlayType_function"].bg
  local operator_fg = resolve_hl_fg({ "@operator.tsx", "@operator" }, comment_fg)
  badge_groups["GloseInlayTypeOperator"] = {
    fg = color.blend(operator_fg, fn_bg, 0.7),
    bg = fn_bg,
  }

  for kind, sources in pairs(type_hl_sources) do
    if kind ~= "function" then
      local src_fg = resolve_hl_fg(sources, blue_tint)
      badge_groups["GloseInlayTypeFnRet_" .. kind] = {
        fg = color.blend(src_fg, comment_fg, 0.4),
        bg = fn_bg,
        italic = true,
      }
    end
  end

  local obj_bg = badge_groups["GloseInlayType_object"].bg
  for kind, sources in pairs(type_hl_sources) do
    local src_fg = resolve_hl_fg(sources, blue_tint)
    badge_groups["GloseInlayTypeObjField_" .. kind] = {
      fg = color.blend(src_fg, comment_fg, 0.4),
      bg = obj_bg,
      italic = true,
    }
  end

  badge_groups["GloseInlayTypeObjOperator"] = {
    fg = color.blend(operator_fg, obj_bg, 0.7),
    bg = obj_bg,
  }

  local user_overrides = cfg.highlights or {}

  for name, opts in pairs(badge_groups) do
    if not user_overrides[name] then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end
end

function M.setup()
  local highlights = {
    GloseNormal = { link = "NormalFloat" },
    GloseBorder = { link = "FloatBorder" },
    GloseTitle = { link = "Title" },
    GloseHoverKind = { link = "Function" },
    GloseHoverKindAlias = { link = "Special" },
    GloseHoverKindFunction = { link = "Function" },
    GloseHoverKindProperty = { link = "@property" },
    GloseHoverKindVariable = { link = "@variable" },
    GloseHoverKindType = { link = "Type" },
    GloseHoverKindEnum = { link = "Constant" },
    GloseHoverKindModule = { link = "@module" },
    GloseBeacon = { link = "Search" },
    GloseActionNumber = { link = "Number" },
    GloseDiffAdd = { link = "DiffAdd" },
    GloseDiffAddSign = { link = "Added" },
    GloseDiffDelete = { link = "DiffDelete" },
    GloseDiffDeleteSign = { link = "Removed" },
    GloseDiffHunk = { link = "Comment" },
    GloseDiffFile = { link = "Normal" },
    GloseFooterIcon = { link = "Function" },
    GloseFooterDesc = { link = "Comment" },
    GloseFooterKey = { link = "Function" },
    GloseSignatureActiveParam = { link = "LspSignatureActiveParameter" },
  }

  for name, opts in pairs(highlights) do
    local existing = vim.api.nvim_get_hl(0, { name = name })
    if vim.tbl_isempty(existing) then
      vim.api.nvim_set_hl(0, name, opts)
    end
  end

  local cfg = require("glose.config").get()
  if cfg.highlights then
    for name, opts in pairs(cfg.highlights) do
      vim.api.nvim_set_hl(0, name, opts)
    end
  end

  create_badge_highlights()
  create_scope_highlights()

  vim.api.nvim_create_autocmd("ColorScheme", {
    group = vim.api.nvim_create_augroup("glose_badge_colors", { clear = true }),
    callback = function()
      create_badge_highlights()
      create_scope_highlights()
    end,
  })
end

return M
