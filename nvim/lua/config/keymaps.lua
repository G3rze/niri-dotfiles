-- Keymaps are automatically loaded on the VeryLazy event
-- Default keymaps that are always set: https://github.com/LazyVim/LazyVim/blob/main/lua/lazyvim/config/keymaps.lua
-- Add any additional keymaps here

-- C++ Template keymaps are now handled in the plugin file

-- Tabs: Ctrl+Left/Ctrl+Right
vim.keymap.set("n", "<C-Left>", "<cmd>tabprevious<cr>", { desc = "Previous Tab" })
vim.keymap.set("n", "<C-Right>", "<cmd>tabnext<cr>", { desc = "Next Tab" })

-- Explorer-like buffers: Shift+Arrows for tree navigation
local explorer_fts = {
  "neo-tree",
  "netrw",
  "oil",
  "snacks_explorer",
}

vim.api.nvim_create_autocmd("FileType", {
  pattern = explorer_fts,
  callback = function(ev)
    local opts = { buffer = ev.buf, silent = true }
    vim.keymap.set("n", "<S-Up>", "k", opts)
    vim.keymap.set("n", "<S-Down>", "j", opts)
    vim.keymap.set("n", "<S-Left>", "h", opts)
    vim.keymap.set("n", "<S-Right>", "l", opts)
  end,
})
