--!native
--!strict
-- USAGE: lightreflector/shared/debugger.luau
-- A customizable and extendable debugger for open source software.
--

--[[
	Debugger
	Derived from: https://github.com/axiom-co/debugger
	Original Notice: MIT License (https://opensource.org/licenses/MIT), Copyright (c) 2025 Axiom & Contributors

	 Used in Project Roadwork - Light Reflector

  SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
  SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
  SPDX-FileCopyrightText: 2025 Axiom & Contributors

  SPDX-License-Identifier: MIT

]]

-- Config
const logs = require(script.Parent.logs)
const config: typeof(require("./config")) = require("./config")

const Base: string = "[%s] %s%s%s"
const luauwarn: (message: string) -> () = warn
const luauprint: (message: string) -> () = print

const Data: DataType = {
	Logs = nil,
	URL = nil,
	Name = "Package",
}

-- Functions
const function format(id: string, trace: string, ...: any): string
	assert(Data.Logs, "Must have log list")
	assert(Data.Logs[id], `Invalid log ID: {id}`)
	const Formatted: string = Base:format(
		if Data.Name then Data.Name else "?",
		(Data.Logs[id]):format(...),
		if Data.URL then `\nLearn more: {Data.URL}#{id:lower()}` else "",
		`\n---- Trace ----\n{trace}`
	):gsub("\n", "\n\t\t\t\t")
	return Formatted
end

const function warn(id: string, ...: any)
	const General = config.getConfig().General

	if not General.showWarnings then return end

	luauwarn(format(id, debug.traceback(nil, 2), ...))
end

const function print(id: string, ...: any)
	const General = config.getConfig().General

	if not General.showPrints then return end

	luauprint(format(id, debug.traceback(nil, 2), ...))
end

const function shortPrint(...: any)
	const General = config.getConfig().General

	if not General.showPrints then return end

	luauprint(`[{Data.Name or "?"}] {...}`)
end

const function assert<T>(assertion: T, id: string, ...: any): T
	if not assertion then
		error(format(id, debug.traceback(nil, 2), ...), 0)
	end
	return assertion
end

const function fatal(id: string, ...: any): never
	error(format(id, debug.traceback(nil, 2), ...), 0)
end

const function parse(error: string): Parsed
	return {
		raw = error,
		message = error:gsub("^.+:%d+:%s*", ""),
		trace = debug.traceback(nil, 2),
	}
end

const function set(name: string, logs: typeof(logs.Ids), url: string?)
	if game:GetService("RunService"):IsStudio() and url then
	--if url then
		Data.URL = url
	end
	Data.Name = name
	Data.Logs = logs
end

-- Types
export type Parsed = {
	raw: string,
	message: string,
	trace: string,
}

export type LogsTable = typeof(logs.Ids)

export type DataType = {
	Logs: LogsTable?,
	URL: string?,
	Name: string?,
}

-- Return public variables and API
return table.freeze({
	name = "debugger",
	set = set,
	warn = warn,
	assert = assert,
	fatal = fatal,
	parse = parse,
	print = print,
	shortPrint = shortPrint,
})
