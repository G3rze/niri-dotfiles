-- Autocmds are automatically loaded on the VeryLazy event
-- Default autocmds that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/autocmds.lua
--
-- Add any additional autocmds here
-- with `vim.api.nvim_create_autocmd`
--
-- Or remove existing autocmds by their group name (which is prefixed with `lazyvim_` for the defaults)
-- e.g. vim.api.nvim_del_augroup_by_name("lazyvim_wrap_spell")

-- Map UI-only plugin filetypes to existing Tree-sitter parsers.
-- This avoids repeated "parser/<ft>.* not found" noise for virtual buffers.
if vim.treesitter and vim.treesitter.language and vim.treesitter.language.register then
  local ts_lang_map = {
    markdown = {
      "noice",
      "snacks_notif",
      "blink-cmp-documentation",
      "snacks_picker_input",
      "snacks_picker_list",
    },
    lua = {
      "snacks_layout_box",
      "blink-cmp-menu",
    },
  }

  for parser, filetypes in pairs(ts_lang_map) do
    for _, ft in ipairs(filetypes) do
      pcall(vim.treesitter.language.register, parser, ft)
    end
  end
end

-- Autosave on insert leave and text change
-- vim.api.nvim_create_autocmd({ "InsertLeave", "TextChanged" }, {
--   pattern = { "*" },
--   command = "silent! wall",
--   nested = true,
-- })
