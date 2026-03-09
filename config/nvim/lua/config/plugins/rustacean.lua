return {
	"mrcjkb/rustaceanvim",
	version = "^5",
	lazy = false,
	config = function()
		local xdg_data_home = os.getenv("XDG_DATA_HOME") or (os.getenv("HOME") .. "/.local/share")
		local codelldb_path = xdg_data_home .. "/nvim/mason/bin/codelldb"
		local liblldb_path = xdg_data_home .. "/nvim/mason/opt/lldb/lib/liblldb.so"
		local cfg = require("rustaceanvim.config")

		vim.g.rustaceanvim = {
			dap = {
				adapter = cfg.get_codelldb_adapter(codelldb_path, liblldb_path),
			},
		}
	end,
}
