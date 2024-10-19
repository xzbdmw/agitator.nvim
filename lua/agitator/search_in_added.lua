local pickers = require("telescope.pickers")
local finders = require("telescope.finders")
local conf = require("telescope.config").values
local action_state = require("telescope.actions.state")
local action_set = require("telescope.actions.set")
local make_entry = require("telescope.make_entry")
local entry_display = require("telescope.pickers.entry_display")

local function search_in_added_add_untracked(lines_with_numbers, opts)
	local Path = require("plenary.path")
	vim.fn.jobstart("git ls-files . --exclude-standard --others", {
		on_stdout = vim.schedule_wrap(function(j, output)
			for _, untracked_fname in ipairs(output) do
				if untracked_fname ~= "" then
					local path = Path.new(vim.fn.getcwd() .. "/" .. untracked_fname)
					local contents = path:read()
					local cur_line = 1
					for line in contents:gmatch("([^\n]*)\n?") do
						table.insert(
							lines_with_numbers,
							vim.fn.getcwd() .. "/" .. untracked_fname .. ":" .. cur_line .. ":" .. 1 .. ":" .. line
						)
						cur_line = cur_line + 1
					end
				end
			end
		end),
		on_exit = vim.schedule_wrap(function(j, output)
			pickers
				.new(opts, {
					prompt_title = vim.g.Base_commit_msg ~= "" and vim.g.Base_commit_msg or "Git Diff",
					finder = finders.new_table({
						results = lines_with_numbers,
						entry_maker = opts.entry_maker or make_entry.gen_from_vimgrep(opts),
					}),
					sorter = conf.generic_sorter(opts),
					previewer = conf.grep_previewer(opts),
				})
				:find()
		end),
	})
end

local function search_in_added(opts)
	local opts = opts or {}
	local lines_with_numbers = {}
	local cur_file = nil
	local cur_line = nil
	local command
	if vim.g.Base_commit ~= "" then
		command = "git diff-index -U0 " .. vim.g.Base_commit
	else
		command = "git diff-index -U0 HEAD"
	end
	vim.fn.jobstart(command, {
		on_stdout = vim.schedule_wrap(function(j, output)
			for _, line in ipairs(output) do
				if string.match(line, "^%+%+%+") then
					-- new file
					cur_file = string.sub(line, 6, -1)
				elseif string.match(line, "^@@ -") then
					-- hunk
					local match = string.gmatch(line, "%+(%d+)")()
					if match == nil then
						goto continue
					end
					cur_line = tonumber(match)
				elseif string.match(line, "^%+") then
					local hit = string.find(cur_file, "lazy-lock", nil, true)
					if hit == nil then
						table.insert(
							lines_with_numbers,
							vim.fn.getcwd()
								.. "/"
								.. cur_file
								.. ":"
								.. cur_line
								.. ":"
								.. 1
								.. ":"
								.. string.sub(line, 2, -1)
						)
					end
					-- added line
					cur_line = cur_line + 1
				end
				::continue::
			end
		end),
		on_exit = vim.schedule_wrap(function(j, output)
			search_in_added_add_untracked(lines_with_numbers, opts)
		end),
	})
end

return {
	search_in_added = search_in_added,
}
