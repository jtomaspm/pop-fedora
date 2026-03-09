return {
	"mfussenegger/nvim-dap",
	config = function()
		local dap, dapui = require("dap"), require("dapui")
		dap.listeners.before.attach.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.launch.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_terminated.dapui_config = function()
			dapui.open()
		end
		dap.listeners.before.event_exited.dapui_config = function()
			dapui.open()
		end

		-- Keybinds
		vim.keymap.set("n", "<leader>di", "<cmd>lua require'dap'.step_into()<CR>", { desc = "Debugger step into" })
		vim.keymap.set("n", "<leader>do", "<cmd>lua require'dap'.step_over()<CR>", { desc = "Debugger step over" })
		vim.keymap.set("n", "<leader>du", "<cmd>lua require'dap'.step_out()<CR>", { desc = "Debugger step out" })
		vim.keymap.set("n", "<leader>dp", "<cmd>lua require'dap'.continue()<CR>", { desc = "Debugger continue" })
		vim.keymap.set(
			"n",
			"<leader>d+",
			"<cmd>lua require'dap'.toggle_breakpoint()<CR>",
			{ desc = "Debugger toggle breakpoint" }
		)
		vim.keymap.set("n", "<leader>de", "<cmd>lua require'dap'.terminate()<CR>", { desc = "Debugger terminate" })
		vim.keymap.set("n", "<leader>dr", "<cmd>lua require'dap'.run_last()<CR>", { desc = "Debugger run last" })

		vim.keymap.set("n", "<leader>dt", "<cmd>lua vim.cmd('RustLsp testables')<CR>", { desc = "Debugger testables" })
	end,
}
