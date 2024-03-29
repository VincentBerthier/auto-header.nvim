-- File: lua/auto-header/init.lua
-- Project: auto-header.nvim
-- Creation date: ven. 13 janv. 2023 02:26:25
-- Author: Vincent Berthier
-- -----
-- Last modified: sam. 19 août 2023 11:29:12
-- Modified By: Vincent Berthier
-- -----
-- Copyright (c) 2023 <Vincent Berthier>
--
-- Permission is hereby granted, free of charge, to any person obtaining a copy
-- of this software and associated documentation files (the "Software"), to deal
-- in the Software without restriction, including without limitation the rights
-- to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
-- copies of the Software, and to permit persons to whom the Software is
-- furnished to do so, subject to the following conditions:
--
-- The above copyright notice and this permission notice shall be included in all
-- copies or substantial portions of the Software.
--
-- THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
-- IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
-- FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
-- AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
-- LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
-- OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
-- SOFTWARE.

local plenary_status, Path = pcall(require, "plenary.path")
if not plenary_status then
	vim.notify("Couldn’t load plenary: disabling auto-header", "ERROR", { title = "Auto-Header" })
	return
end

local licenses = require("auto-header.licenses")
local utils = require("auto-header.utility")

local M = {
	setup_called = false,
	init_root = "",
	licenses = licenses,
}

M.config = {
	create = false,
	update = true,
	languages = { "cpp", "python", "bash", "rust", "lua" },
	licenses = licenses,
	key = nil,
	templates = {
		{
			language = "*",
			prefix = "auto",
			block = "-",
			block_length = 0,
			before = {},
			after = { "" },
			template = {
				"File: #file_relative_path",
				"Project: #project_name",
				"Creation date: #date_now",
				"Author: #author_name <#author_mail>",
				"-----",
				"Last modified: #date_now",
				"Modified By: #author_name",
				"-----",
				licenses.MIT,
			},
			track_change = {
				"File: ",
				"Last modified: ",
				"Modified By: ",
				"Copyright ",
			},
		},
	},
	projects = {},
}

-----------------------------------------------------
--           Projects configuration                --
-----------------------------------------------------
local function make_git_conf(path)
	local split_path = utils.split_string(path:absolute(), path.path.sep)
	return {
		root = path,
		data = {
			project_name = split_path[#split_path],
			cp_holders = utils.get_user_name(),
			author_mail = utils.get_user_mail(),
		},
	}
end

local function get_folder_conf(path)
	for _, project in ipairs(M.config.projects) do
		if Path:new(project.root):normalize() == path:normalize() then
			return vim.deepcopy(project)
		end
	end
	if path:joinpath(".git/"):exists() then
		return make_git_conf(path)
	end
	return nil
end

local function get_project_conf()
	-- get the current filename
	local path = Path:new(vim.api.nvim_buf_get_name(0))
	local parents = path:parents()
	-- get the configuration for the current project
	local conf = nil
	for _, parent in pairs(parents) do
		conf = get_folder_conf(Path:new(parent))
		if conf ~= nil then
			return conf
		end
	end
	return conf
end

local function update_configuration(conf)
	local data = conf.data
	if not data.author_name then
		data.author_name = utils.get_user_name()
	end
	if not data.author_mail then
		data.author_mail = utils.get_user_mail()
	end
	local path = Path:new(vim.api.nvim_buf_get_name(0))
	data.file_relative_path = path:make_relative(data.root)
	data.date_now = os.date()
	data.cp_year = os.date("%Y")
	conf.data = data
	return conf
end

-----------------------------------------------------
--               Handle the templates              --
-----------------------------------------------------
-- The template for the header is determined by the buffer’s filetype
local function get_template()
	local type = vim.bo.filetype
	local default = nil
	for _, template in ipairs(M.config.templates) do
		if template.language == type then
			return vim.deepcopy(template)
		elseif template.language == "*" then
			default = vim.deepcopy(template)
		end
	end
	return default
end

local function update_auto_template(temp)
	-- If the template’s prefix string is auto, get the comment string from the filetype
	local template = vim.deepcopy(temp)
	if template.prefix == "auto" then
		local prefix = vim.api.nvim_buf_get_option(0, "commentstring")
		prefix = string.gsub(prefix, "%%s", "@")
		local split = utils.split_string(prefix, "@")
		if #split == 1 then
			template.prefix = string.gsub(prefix, "@", "")
		else
			table.insert(template.before, split[1])
			table.insert(template.after, 1, split[2])
			template.prefix = string.rep(" ", split[1]:len())
		end
	end
	return template
end

local function fill_template(template, conf, block_len)
	local res = {}
	for _, line in ipairs(template) do
		for k, v in pairs(conf.data) do
			if v ~= nil then
				line = string.gsub(line, "#" .. k, v)
			end
		end
		for _, updated in ipairs(utils.wrap_text(line, block_len)) do
			table.insert(res, updated)
		end
	end
	return res
end

-----------------------------------------------------
--               Make the headers                  --
-----------------------------------------------------
local function set_header(text, bufr)
	-- get the current bufr
	bufr = bufr or 0
	vim.api.nvim_buf_set_lines(bufr, 0, 0, false, text)
end

local function update_header(text, template, current)
	local tracks = template.track_change

	for i, line in ipairs(tracks) do
		tracks[i] = template.prefix .. line
	end

	-- for each line we want to update, look for their new values
	-- and replace the current header values with the new ones
	for i, line in ipairs(current) do
		-- is it a line we want to track?
		local track = ""
		local j = 0
		while track == "" and j < #tracks do
			j = j + 1
			if line:sub(0, tracks[j]:len()) == tracks[j] then
				track = tracks[j]
			end
		end
		if track ~= "" then -- this is not a line we want to track, keep the old one
			-- find the line with the right start in the new header
			for _, updated in ipairs(text) do
				if updated:sub(0, track:len()) == track then
					current[i] = updated
				end
			end
		end
	end
	-- Replace the header
	vim.api.nvim_buf_set_lines(0, 0, #current, false, current)
end

local function make_header(template, conf)
	local reserved = string.len(template.prefix)
	local block_line = ""
	if template.block_length > 0 and template.block ~= "" then
		block_line = string.rep(template.block, template.block_length)
		if string.len(template.block) == 1 then
			template.block = string.rep(template.block, 2)
		end
		reserved = reserved + string.len(template.block) + 1
	elseif template.block_length == 0 then
		template.block = ""
		template.block_length = 100
	end

	-- Update the default configuration with data from the current project’s
	conf = update_configuration(conf)
	-- fill the template data with the configuration values
	template.template = fill_template(template.template, conf, template.block_length - reserved)
	-- Make the header
	local header = {}

	for _, line in ipairs(template.before) do
		table.insert(header, line)
	end
	if block_line ~= "" then
		table.insert(header, block_line)
	end

	for _, line in ipairs(template.template) do
		line = template.prefix .. line
		if template.block ~= "" then
			line = utils.pad_text(line, template.block_length)
			line = string.sub(line, 0, template.block_length - string.len(template.block)) .. template.block
		end
		table.insert(header, line)
	end

	if block_line ~= "" then
		table.insert(header, block_line)
	end
	return header
end

function M.add_or_update_header(update_only)
	update_only = update_only or false
	-- Check that the current filetype is one we want to have a header on
	local type = vim.bo.filetype
	if not (utils.contains(M.config.languages, "*") or utils.contains(M.config.languages, type)) then
		return
	end

	-- Get the project’s configuration, if there’s none abort
	local conf = get_project_conf()
	if not conf then
		return
	end

	-- Get the current file’s template, if there’s none, abort
	local template = get_template()
	if not template then
		return
	end
	if conf.template ~= nil then
		template.template = conf.template
	end

	-- Update the template if necessary
	template = update_auto_template(template)
	-- Get the buffer’s first line
	local header = make_header(template, conf)

	-- if the header is empty for some reason, there’s nothing more to do
	if #header == 0 then
		return
	end

	local current = utils.find_header(template.block, template.prefix, #template.before)
	if #current == #template.before then
		if update_only then
			return
		end
		-- add the 'after' part of the header only now, otherwise it messes up detection
		for _, line in ipairs(template.after) do
			table.insert(header, line)
		end
		set_header(header)
		vim.notify("Header has been added at the top of the file", "INFO", { title = "Auto-Header" })
	elseif #current ~= #header then
		return
	else
		update_header(header, template, current)
		vim.notify("Header has been updated at the top of the file", "DEBUG", { title = "Auto-Header" })
	end
end

-- This function is called by the auto save if either config.create or config.update is true
-- Otherwise headers creation / updates can only be explicitely requested
function M.on_save()
	-- Get the project’s configuration, if there’s none abort
	local conf = get_project_conf()
	if not conf then
		return
	end

	local create = conf.create
	if create == nil then
		create = M.config.create
	end

	local update = conf.update
	if update == nil then
		update = M.config.update
	end
	if not create and not update then
		return
	end

	local file_exists = Path:new(vim.api.nvim_buf_get_name(0)):exists()
	if not file_exists and not create then
		return
	end
	M.add_or_update_header(not create)
end

--------------------------------------------------------
--             User configuration                     --
--------------------------------------------------------
function M.setup(user_opts)
	M.config = vim.tbl_extend("force", M.config, user_opts or {})
	-- Automatically set headers or update them
	if M.config.create or M.config.update then
		vim.api.nvim_create_autocmd("BufWritePre", { command = "lua require('auto-header').on_save()" })
	end

	if M.config.key ~= nil then
		local opts = { noremap = true }
		vim.api.nvim_set_keymap("n", M.config.key, "<cmd>lua require('auto-header').add_or_update_header()<CR>", opts)
	end
end

-- Auto add header on save
vim.cmd([[autocmd BufWritePre * lua require("auto-header").on_save()]])

return M
