--!native
--!strict
-- USAGE: lightreflector/shared/logs.luau
-- Log ids and URL for the Light Reflector debugger.

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
    SPDX-FileCopyrightText: 2025 Axiom & Contributors

	SPDX-License-Identifier: MPL-2.0 AND MIT

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

return {
	Ids = {
		FatalInit = "Init errored: %s",
		MassFatalInit = "Mass fatal init errored: %s",
		Fatal = "Fatal error: %s",
		AlreadyStarting = "[INIT] Light Reflector is already starting",
		InvalidType = "Expected type %s; got '%s'",
		InvalidInstance = "Expected type %s; got '%s'",
		Info = "Info: %s",
		Warning = "Warning: %s",
		Distortion = "Warning: %s",
		InitWarning = "Init warning: %s",
		RunContext = "[INIT] Invalid RunContext: %s",
	},
	URL = "https://codeberg.org/project-roadwork/light-reflector/src/branch/main/docs/standalone/012_issues.md",
}
