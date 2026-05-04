/*
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

*/

declare namespace VersionModule {
  export interface Version {
    readonly major: number;
    readonly minor: number;
    readonly patch: number;
    readonly pre_release: string;
    readonly build: number;
    readonly metadata: string;
  }
}

interface VersionModule {
  readonly name: "version";
  readonly _VERSION: string;
  checkVersion(): void;
}

declare const version: VersionModule;

export = version;
