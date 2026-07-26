local M = {}

local function version_parts(path)
	local parts = {}
	for part in vim.fs.basename(path):gmatch("%d+") do
		parts[#parts + 1] = tonumber(part)
	end
	return parts
end

local function newer(left, right)
	local left_parts = version_parts(left)
	local right_parts = version_parts(right)
	for index = 1, math.max(#left_parts, #right_parts) do
		local left_part = left_parts[index] or 0
		local right_part = right_parts[index] or 0
		if left_part ~= right_part then
			return left_part > right_part
		end
	end
	return left > right
end

local function newest(pattern)
	local paths = vim.fn.glob(pattern, false, true)
	table.sort(paths, newer)
	return paths[1]
end

function M.temurin_home(major)
	if vim.fn.has("win32") ~= 1 then
		return nil
	end
	return newest(string.format("C:/Program Files/Eclipse Adoptium/jdk-%d*", major))
end

function M.python_home()
	if vim.fn.has("win32") ~= 1 or not vim.env.LOCALAPPDATA then
		return nil
	end
	return newest(vim.fs.joinpath(vim.env.LOCALAPPDATA, "Programs", "Python", "Python3*"))
end

function M.with_path(paths)
	local entries = {}
	for _, path in ipairs(paths) do
		if path then
			entries[#entries + 1] = path
		end
	end
	entries[#entries + 1] = vim.env.PATH or ""
	return table.concat(entries, ";")
end

return M
