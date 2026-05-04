// USAGE: lightreflector/shared/debugger.luau
// A customizable and extendable debugger for open source software.
//

/*
	Debugger
	Derived from: https://github.com/axiom-co/debugger
	Original Notice: MIT License (https://opensource.org/licenses/MIT), Copyright (c) 2025 Axiom & Contributors

	 Used in Project Roadwork - Light Reflector

  SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
  SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
  SPDX-FileCopyrightText: 2025 Axiom & Contributors

  SPDX-License-Identifier: MIT

*/

declare namespace Debugger {
  interface Parsed {
    raw: string;
    message: string;
    trace: string;
  }

  type LogsTable = { [key: string]: boolean };

  interface DataType {
    Logs?: LogsTable;
    URL?: string;
    Name?: string;
  }

  interface API {
    readonly name: string;

    set: (name: string, logs: LogsTable, url?: string) => void;

    warn: (id: string, ...args: unknown[]) => void;

    print: (id: string, ...args: unknown[]) => void;

    shortPrint: (...args: unknown[]) => void;

    assert: <T>(assertion: T, id: string, ...args: unknown[]) => T;

    fatal: (id: string, ...args: unknown[]) => never;

    parse: (error: string) => Parsed;
  }
}

declare const Debugger: Debugger.API;

export = Debugger;
