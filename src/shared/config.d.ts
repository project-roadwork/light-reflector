/*
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

*/

import type { BASE_CONFIG, Dict } from "./types";

declare namespace config {
  export const name: "config";

  export const FLAGS: { [key: string]: boolean };

  export function applyOverrides(userConfig: unknown): BASE_CONFIG;

  export function lock(): void;
  export function unlock(): void;

  export function waitForLock(callback: () => void): void;
  export function onChange(callback: (config: BASE_CONFIG) => void): void;

  export function getKey(section: string, key: string): unknown;
  export function getSection(section: string): Dict;

  export function overrideKey(
    section: string,
    key: string,
    value: unknown,
  ): void;

  export function getConfig(): BASE_CONFIG;
}

export = config;
