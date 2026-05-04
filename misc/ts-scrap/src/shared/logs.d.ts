// USAGE: lightreflector/shared/logs.luau
// Log ids and URL for the Light Reflector debugger.

/*
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
    SPDX-FileCopyrightText: 2025 Axiom & Contributors

	SPDX-License-Identifier: MPL-2.0 AND MIT

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

*/

interface DebuggerLogs {
  Ids: {
    FatalInit: string;
    MassFatalInit: string;
    Fatal: string;
    AlreadyStarting: string;
    InvalidType: string;
    InvalidInstance: string;
    Info: string;
    Warning: string;
    Distortion: string;
    InitWarning: string;
    RunContext: string;
  };
  URL: string;
}

declare const logs: DebuggerLogs;

export = logs;
