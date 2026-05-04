/*
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

*/

import type { LightSource, ReflectorState, SignEntity } from "../shared/types";
import type { JecsModule } from "../shared/types";

export interface Detect {
  readonly name: string;

  readonly currentDetectedEntities: Record<JecsModule["Entity"], boolean>;
  readonly activeReflectorEntities: Record<JecsModule["Entity"], boolean>;

  readonly init: () => void;
  readonly start: () => void;
  readonly reset: () => void;

  readonly getDetectedEntities: () => Record<JecsModule["Entity"], boolean>;

  readonly safeCancelThread: () => LuaTuple<[boolean, string?]>;
}

declare const Detect: Detect;
export = Detect;
