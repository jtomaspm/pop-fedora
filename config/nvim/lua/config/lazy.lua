-- [[ Install `lazy.nvim` plugin manager ]]
--    See `:help lazy.nvim.txt` or https://github.com/folke/lazy.nvim for more info
local lazypath = vim.fn.stdpath("data") .. "/lazy/lazy.nvim"
if not (vim.uv or vim.loop).fs_stat(lazypath) then
	local lazyrepo = "https://github.com/folke/lazy.nvim.git"
	local out = vim.fn.system({ "git", "clone", "--filter=blob:none", "--branch=stable", lazyrepo, lazypath })
	if vim.v.shell_error ~= 0 then
		error("Error cloning lazy.nvim:\n" .. out)
	end
end

---@type vim.Option
local rtp = vim.opt.rtp
rtp:prepend(lazypath)

-- [[ Configure and install plugins ]]
--
--  To check the current status of your plugins, run
--    :Lazy
--
--  You can press `?` in this menu for help. Use `:q` to close the window
--
--  To update plugins you can run
--    :Lazy update
--
-- NOTE: Here is where you install your plugins.
require("lazy").setup({
	require("config.plugins.onedark"), -- Colorscheme
	require("config.plugins.highlight-colors"), -- Colors #AA0022

	require("config.plugins.guess-indent"), -- Detect tabstop and shiftwidth automatically
	require("config.plugins.git-signs"), -- Adds git related signs to the gutter, as well as utilities for managing changes
	-- require("config.plugins.which-key"), -- Useful plugin to show you pending keybinds.
	require("config.plugins.telescope"), -- Fuzzy Finder (files, lsp, etc)

	require("config.plugins.lazy-dev"), -- `lazydev` configures Lua LSP for your Neovim config, runtime and plugins
	require("config.plugins.lsp-config"), -- Main LSP Configuration
	require("config.plugins.conform"), -- Autoformat
	require("config.plugins.blink"), -- Autocompletion

	require("config.plugins.todo-comments"), -- Highlight todo, notes, etc in comments
	require("config.plugins.mini"), -- Collection of various small independent plugins/modules
	require("config.plugins.treesitter"), -- Highlight, edit, and navigate code
	require("config.plugins.dap"), -- Debugger
	require("config.plugins.dap-ui"), -- Debugger UI
	-- require("config.plugins.rustacean"), -- Rust
	-- require("config.plugins.rust"), -- Rust format on save
	-- require("config.plugins.crates"), -- Rust crates
}, {
	ui = {
		-- If you are using a Nerd Font: set icons to an empty table which will use the
		-- default lazy.nvim defined Nerd Font icons, otherwise define a unicode icons table
		icons = vim.g.have_nerd_font and {} or {
			cmd = "⌘",
			config = "🛠",
			event = "📅",
			ft = "📂",
			init = "⚙",
			keys = "🗝",
			plugin = "🔌",
			runtime = "💻",
			require = "🌙",
			source = "📄",
			start = "🚀",
			task = "📌",
			lazy = "💤 ",
		},
	},
})

-- The line beneath this is called `modeline`. See `:help modeline`
-- vim: ts=2 sts=2 sw=2 et
