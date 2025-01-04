local generator = require("neonotes.features.generator")

local M = {}

function M.create_commands()
	vim.api.nvim_create_user_command("Smn", function(params)
		M.command_parser(params.fargs)
	end, {
		nargs = "*",
		desc = "Main entry point for Neonotes commands",
	})
end

function M.command_parser(args)
	local tag = args[1]
	local command = args[2]

	if tag == "toggle" then
		M.toggle_checkbox(args, "Item")
	elseif command == "cb" then
		M.add_checkbox(args, "## ", tag)
	else
		print("Neonotes: unknown subcommand")
	end
end

function M.add_checkbox(args, matcher, tagName)
	table.remove(args, 1)
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
			table.insert(description, args[i])
			i = i + 1
		end
	end

	local descriptionStr = table.concat(description, " ")

	local file_path = generator.get_or_create_daily_file()
	local lines = {}

	for line in io.lines(file_path) do
		table.insert(lines, line)
	end

	for idx, line in ipairs(lines) do
		if string.lower(line):match("^" .. matcher .. string.lower(tagName)) then
			table.insert(
				lines,
				idx + 2,
				string.format("- [ ] %s (tag: %s, priority: %s)", descriptionStr, tag, priority)
			)
			break
		end
	end

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
	table.remove(args, 1)
	local query = table.concat(args, " ")

	local file_path = generator.get_or_create_daily_file()
	local lines = {}
	for line in io.lines(file_path) do
		table.insert(lines, line)
	end

	-- We'll do a naive search for the query in each line.
	for idx, line in ipairs(lines) do
		if line:match("^%- %[.-%]") and line:find(query) then
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
