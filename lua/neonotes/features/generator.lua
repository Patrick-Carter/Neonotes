local M = {}

function M.init(opts)
	M.notes_dir = opts.notes_dir
	M.max_days_back = opts.max_days_back
end

local function parse_index(str)
	local idx = str:match("^__(%d+)__")
	return idx and tonumber(idx) or 0
end

local function strip_prefix(str)
	local stripped = str:match("^__%d+__%s*(.*)")
	return stripped or str
end

local function get_daily_file_path(base_dir, date_table, generate_path)
	if generate_path == nil then
		generate_path = true
	end

	local year = string.format("%04d", date_table.year)
	local month = string.format("%02d", date_table.month)
	local day = string.format("%02d", date_table.day)

	local dir_path = table.concat({ base_dir, year, month }, "/")

	-- Ensure directory exists
	if generate_path == true then
		vim.fn.mkdir(dir_path, "p")
	end

	local file_path = dir_path .. "/" .. day .. ".md"
	return file_path
end

function M.get_or_create_daily_file()
	local date_table = os.date("*t") -- e.g. {year=2025, month=1, day=2, ...}
	local file_path = get_daily_file_path(M.notes_dir, date_table)

	if vim.fn.filereadable(file_path) == 0 then
		local fp = io.open(file_path, "w")
		if fp then
			fp:write(
				"# Developer Report " .. date_table.year .. "-" .. date_table.month .. "-" .. date_table.day .. "\n\n"
			)
			fp:write("## Progress\n\n")
			fp:write("## TODOs\n\n")
			fp:write("## Blockers\n\n")
			fp:write("## Persistent Notes\n\n")
			fp:close()
		end
	end

	return file_path
end

function M.handle_daily_rollover(date_override)
	local current_date = date_override or os.date("*t")

	local max_days_back = M.max_days_back

	local found_path = nil
	local rewind_date = nil

	for days_back = 1, max_days_back do
		local rewind_sec = os.time(current_date) - (24 * 60 * 60 * days_back)
		rewind_date = os.date("*t", rewind_sec)

		local rewind_path = get_daily_file_path(M.notes_dir, rewind_date, false)

		if vim.fn.filereadable(rewind_path) == 1 then
			found_path = rewind_path
			break
		end
	end
	local today_path = get_daily_file_path(M.notes_dir, current_date)

	if not found_path then
		M.get_or_create_daily_file()
		return
	end

	local yesterday_path = get_daily_file_path(M.notes_dir, rewind_date, false)

	if vim.fn.filereadable(yesterday_path) == 1 and vim.fn.filereadable(today_path) == 0 then
		M.get_or_create_daily_file()

		local yesterday_lines = {}
		for line in io.lines(yesterday_path) do
			table.insert(yesterday_lines, line)
		end

		local completed_items = {}
		local other_items = {}
		local current_tag = ""

		for i, line in ipairs(yesterday_lines) do
			if line:match("^## ") and not line:match("^## Progress") then
				current_tag = "__" .. i .. "__ " .. line
				other_items[current_tag] = {}
			elseif line:match("^%- %[x%]") then
				table.insert(completed_items, line)
			elseif current_tag ~= "" then
				table.insert(other_items[current_tag], line)
			end
		end

		local today_lines = {}
		local title = "# Developer Report "
			.. current_date.year
			.. "-"
			.. current_date.month
			.. "-"
			.. current_date.day
			.. "\n\n"

		table.insert(today_lines, title)
		table.insert(today_lines, "## Progress\n")

		for _, item in ipairs(completed_items) do
			table.insert(today_lines, item .. "\n")
		end
		table.insert(today_lines, "\n")

		local keys = {}
		for k, _ in pairs(other_items) do
			table.insert(keys, k)
		end

		table.sort(keys, function(a, b)
			return parse_index(a) < parse_index(b)
		end)

		for _, k in ipairs(keys) do
			local line = strip_prefix(k)
			if not line:match("\n$") then
				line = line .. "\n"
			end
			table.insert(today_lines, line)

			for _, linej in ipairs(other_items[k]) do
				if not linej:match("\n$") then
					linej = linej .. "\n"
				end
				table.insert(today_lines, linej)
			end

			if today_lines[#today_lines] ~= "\n" then
				table.insert(today_lines, "\n")
			end
		end

		local fp = io.open(today_path, "w")

		if fp == nil then
			print("file does not exist")
			return
		end

		for _, line_out in ipairs(today_lines) do
			fp:write(line_out)
		end
		fp:close()
	end
end

return M
