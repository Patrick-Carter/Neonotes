local commands = require("neonotes.features.commands")
local generator = require("neonotes.features.generator")

local M = {}

local default_opts = {
	notes_dir = "~/neonotes", -- Default notes directory
	max_days_back = 14,
}

function M.setup(opts)
	M.opts = vim.tbl_extend("force", default_opts, opts or {})
	M.opts.notes_dir = vim.fn.expand(M.opts.notes_dir)

	commands.create_commands()

	generator.init(M.opts)
	generator.handle_daily_rollover()
end

return M
