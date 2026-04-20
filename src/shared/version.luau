--!strict
--!native
-- USAGE: lightreflector/shared/version.luau
-- Version for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: Copyright 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

--[=[
	Private: Converts version to string

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]

const HttpService: HttpService = game:GetService("HttpService")
const RunService: RunService = game:GetService("RunService")
const CodebergTags: string = "https://codeberg.org/api/v1/repos/project-roadwork/light-reflector/tags"
const version: Version = table.freeze({major = 2, minor = 1, patch = 0, pre_release = "beta", build = 0, metadata = ""}) :: Version

--[=[
	Private: Converts version to string

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _versionToString(v: Version): string
	local str: string = `{v.major}.{v.minor}.{v.patch}`
	if v.pre_release and v.pre_release ~= "" then
		str = str .. `-{v.pre_release}`
	end
	if v.build and v.build >= 0 then
		str = str .. `.{v.build}`
	end
	if v.metadata and v.metadata ~= "" then
		str = str .. `+{v.metadata}`
	end
	return str
end

--[=[
	Public: Checks for the latest version

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function checkVersion()
	if not RunService:IsServer() then
		warn("You must run checkVersion from the server! Aborting...")
		return
	end

	task.defer(function()
		const function fetch(url: string)
			const success: boolean, result: string = pcall(HttpService.GetAsync, HttpService, url)

			if not success then
				return nil
			end

			const ok: boolean, data: any = pcall(HttpService.JSONDecode, HttpService, result)

			return ok and data or nil
		end

		const function normalizeVersion(v: string): string
			v = string.gsub(v, "^%s+", "")
			v = string.gsub(v, "%s+$", "")

			if string.match(v, "^[vV]%d") then
				v = string.sub(v, 2)
			end

			return v
		end

		const tags: {any}? = fetch(CodebergTags)
		if not tags or not tags[1] then
			return
		end

		const rawLatest: any = tags[1].name
		if typeof(rawLatest) ~= "string" then
			return
		end

		const latestVersion = normalizeVersion(rawLatest)
		const currentVersion = normalizeVersion(_versionToString(version))

		if latestVersion ~= currentVersion then
			warn(
				("LightReflector: New version available! Current: %s | Latest: %s"):format(
					currentVersion,
					latestVersion
				)
			)
		end
	end)
end

-- Types
export type Version = {
	major: number,
	minor: number,
	patch: number,
	pre_release: string,
	build: number,
	metadata: string,
}

-- Return variables and API
return table.freeze({
	name = "version",
	_VERSION = _versionToString(version),
	checkVersion = checkVersion,
})
