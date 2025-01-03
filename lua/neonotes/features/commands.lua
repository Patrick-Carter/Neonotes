local generator = require("neonotes.features.generator")

local M = {}

function M.create_commands()
	vim.api.nvim_create_user_command("Neonotes", function(params)
		M.command_parser(params.fargs)
	end, {
		nargs = "*",
		desc = "Main entry point for Neonotes commands",
	})
end

-- For convenience, we’ll parse subcommands like:
-- :Neonotes add-todo description... -t tag -p status
-- :Neonotes toggle-todo <identifier>

function M.command_parser(args)
	-- `args` is a table of strings from the command line
	local subcommand = args[1]

	if subcommand == "add-todo" then
		-- call add_todo function
		-- e.g., parse the rest of args
		M.add_checkbox(args, "## ", "TODOs")
	elseif subcommand == "toggle" then
		-- call toggle_todo function
		M.toggle_checkbox(args, "Item")
	elseif subcommand == "add-blocker" then
		M.add_checkbox(args, "## ", "Blockers")
	else
		-- fallback or error message
		print("Neonotes: unknown subcommand")
	end
end

function M.add_checkbox(args, matcher, tagName)
	-- Example: args = { "add-todo", "Finish", "writing", "docs", "-t", "docs", "-p", "high" }

	-- Remove the first element "add-todo"
	table.remove(args, 1)

	local description = {}
	local tag = "general"
	local priority = "medium"

	local i = 1
	while i <= #args do
		if args[i] == "-t" and args[i + 1] then
			tag = args[i + 1]
			i = i + 2
		elseif args[i] == "-p" and args[i + 1] then
			priority = args[i + 1]
			i = i + 2
		else
			-- Accumulate this piece of the description
			table.insert(description, args[i])
			i = i + 1
		end
	end

	local descriptionStr = table.concat(description, " ")

	local file_path = generator.get_or_create_daily_file()
	local lines = {}

	-- Read the file lines
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end

	-- Insert a new line under #TODOs
	for idx, line in ipairs(lines) do
		if line:match("^" .. matcher .. tagName) then
			-- Insert after #TODOs
			table.insert(
				lines,
				idx + 1,
				string.format("- [ ] %s (tag: %s, priority: %s)", descriptionStr, tag, priority)
			)
			break
		end
	end

	-- Write lines back
	local fp = io.open(file_path, "w")

	if fp == nil then
		print("file does not exist")
		return
	end

	for _, line_out in ipairs(lines) do
		fp:write(line_out .. "\n")
	end
	fp:close()

	print("Neonotes: added " .. tagName .. " " .. descriptionStr)
end

function M.toggle_checkbox(args, tagName)
	-- Example usage: :Neonotes toggle-todo "docs"
	-- or            :Neonotes toggle-todo "writing docs"
	table.remove(args, 1) -- remove "toggle-todo"
	local query = table.concat(args, " ")

	local file_path = generator.get_or_create_daily_file()
	local lines = {}
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end

	-- We'll do a naive search for the query in each line.
	for idx, line in ipairs(lines) do
		-- We only care if line is a TODO line:
		-- e.g., "- [ ] Finish writing docs (tag: docs, status: open)"
		if line:match("^%- %[.-%]") and line:find(query) then
			-- Toggle [ ] <-> [x] for the checkbox
			if line:find("%- %[%s%]") then
				line = line:gsub("%- %[%s%]", "- [x]")
				print(string.format("Neonotes: marked %s as complete -> %s", tagName, query))
			else
				line = line:gsub("%- %[x%]", "- [ ]")
				print(string.format("Neonotes: marked %s as open -> %s", tagName, query))
			end

			lines[idx] = line
			break
		end
	end

	-- Write lines back
	local fp = io.open(file_path, "w")

	if fp == nil then
		print("file does not exist")
		return
	end

	for _, line_out in ipairs(lines) do
		fp:write(line_out .. "\n")
	end
	fp:close()
end

return M
