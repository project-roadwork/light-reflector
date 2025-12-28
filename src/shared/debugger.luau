--!native
-- USAGE: lightreflector/shared/debugger.luau
-- A customizable and extendable debugger for open source software.
-- Derived from: https://github.com/axiom-co/debugger

--[[

  Dual licensed under the Mozilla Public License 2.0 and the MIT License. You may choose either license.
  Copyright (c) 2025 Project Roadwork

]]

-- Original Notice: MIT License | Copyright (c) 2025 Axiom & Contributors

-- Variables

local Base = "[%s] %s%s%s"
local luauwarn = warn
local luauprint = print
local Data = {
	Logs = nil,
	URL = nil,
	Name = "Package",
}

local Configuration = require("./config")

-- Functions

local function format(id: string, trace: string, ...: any): string
	assert(Data.Logs, "Must have log list")
	assert(Data.Logs[id], `Invalid log ID: {id}`)
	local Formatted = Base:format(
		if Data.Name then Data.Name else "?",
		(Data.Logs[id] :: string):format(...),
		if Data.URL then `\nLearn more: {Data.URL}#{id:lower()}` else "",
		`\n---- Trace ----\n{trace}`
	):gsub("\n", "\n\t\t\t\t")
	return Formatted
end

local function warn(id: string, ...: any)
	if not Configuration.ShowWarnings then return end

	luauwarn(format(id, debug.traceback(nil, 2), ...))
end

local function print(id: string, ...: any)
	if not Configuration.ShowPrints then return end

	luauprint(format(id, debug.traceback(nil, 2), ...))
end

local function assert<T>(assertion: T, id: string, ...: any): T
	if not assertion then
		error(format(id, debug.traceback(nil, 2), ...), 0)
	end
	return assertion
end

local function fatal(id: string, ...: any): never
	error(format(id, debug.traceback(nil, 2), ...), 0)
end

local function parse(error: string): Parsed
	return {
		raw = error,
		message = error:gsub("^.+:%d+:%s*", ""),
		trace = debug.traceback(nil, 2),
	}
end

local function set(name: string, logs: {[string]: string}, url: string?)
	if game:GetService("RunService"):IsStudio() and url then
		Data.URL = url :: any
	end
	Data.Name = name :: any
	Data.Logs = logs :: any
end

-- Types

export type Parsed = {
	raw: string,
	message: string,
	trace: string,
}

-- Module

return table.freeze({
	set = set,
	warn = warn,
	assert = assert,
	fatal = fatal,
	parse = parse,
	print = print
})
