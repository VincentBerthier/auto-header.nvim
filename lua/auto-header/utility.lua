-- File: lua/auto-header/utility.lua
-- Project: #project_name
-- Creation date: ven. 13 janv. 2023 03:26:25
-- Author: Vincent Berthier
-- -----
-- Last modified: lun. 23 janv. 2023 22:25:47
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

local M = {}

function M.contains(array, value)
	local found = false
	local i = 1
	while i <= #array and not found do
		found = array[i] == value
		i = i + 1
	end
	return found
end

function M.get_user_name()
	local name = os.getenv("USER")
	local git_data = vim.fn.systemlist("git config user.name")
	if #git_data == 1 then
		name = git_data[1]
	end
	return name
end

function M.get_user_mail()
	local mail = ""
	local git_data = vim.fn.systemlist("git config user.email")
	if #git_data == 1 then
		mail = git_data[1]
	end
	return mail
end

function M.find_header(block, prefix, header_len)
	local res = {}
	local bufr_text = vim.api.nvim_buf_get_lines(0, 0, -1, false)
	local i = 1
	while i <= header_len do
		table.insert(res, bufr_text[i])
		i = i + 1
	end
	if block ~= "" and bufr_text[i]:match("^" .. block) then
		table.insert(res, bufr_text[i])
		i = i + 1
	end
	while i < #bufr_text and (bufr_text[i]:match("^" .. prefix) or bufr_text[i] == prefix:gsub("%s+", "")) do
		table.insert(res, bufr_text[i])
		i = i + 1
	end
	return res
end

function M.wrap_text(str, len)
	if string.len(str) <= len then
		return { str }
	end
	local res = {}
	local line = ""
	str = string.gsub(str, "\n", " <CR> ")
	for s in string.gmatch(str, "%S+") do
		if s == "<CR>" or string.len(line .. " " .. s) >= len then
			table.insert(res, line)
			line = ""
		end
		if s ~= "<CR>" then
			if line ~= "" then
				line = line .. " " .. s
			else
				line = s
			end
		end
	end
	if line ~= "" then
		table.insert(res, line)
	end
	return res
end

function M.pad_text(str, len)
	if string.len(str) > len then
		return str
	end
	return str .. string.rep(" ", len - string.len(str))
end

function M.copy(obj, seen)
	if type(obj) ~= "table" then
		return obj
	end
	if seen and seen[obj] then
		return seen[obj]
	end
	local s = seen or {}
	local res = setmetatable({}, getmetatable(obj))
	s[obj] = res
	for k, v in pairs(obj) do
		res[M.copy(k, s)] = M.copy(v, s)
	end
	return res
end

-- Taken from https://stackoverflow.com/questions/1426954/split-string-in-lua
function M.split_string(inputstr, sep)
	if sep == nil then
		sep = "%s"
	end
	local t = {}
	for str in string.gmatch(inputstr, "([^" .. sep .. "]+)") do
		table.insert(t, str)
	end
	return t
end

return M
