-- USAGE: lightreflector/shared/version.luau
-- Version for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

local version = table.freeze({major = 1, minor = 1, patch = 0, pre_release = "beta", build = -1, metadata = ""})

-- Private: Converts version to string
local function _versionToString(v)
	local str = `{v.major}.{v.minor}.{v.patch}`
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

return _versionToString(version)
