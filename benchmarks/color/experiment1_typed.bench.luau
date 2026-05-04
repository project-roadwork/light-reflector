--!strict
--!native
--
--[[
    SPDX-FileCopyrightText: 2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0
]]
--
-- Experiment 1 compares the following:
-- number
-- Color3
--
-- This module is also fully typed

type Profiler = any

type BenchmarkFunction = (Profiler, number) -> ()

type BenchmarkModule = {
	ParameterGenerator: () -> number,
	Functions: { [string]: BenchmarkFunction },
}

local module: BenchmarkModule = {
	ParameterGenerator = function(): number
		return 10000
	end,

	Functions = {

		["Color3 Pipeline"] = function(Profiler: Profiler, N: number): ()
			local base: Color3 = Color3.new(0.2, 0.4, 0.6)
			local orig: Color3 = Color3.new(0.8, 0.7, 0.3)
			local light: Color3 = Color3.new(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local plastic: Color3 = base:Lerp(orig, tPlastic)

				local nr: number = base.R * light.R
				local ng: number = base.G * light.G
				local nb: number = base.B * light.B

				local neon: Color3 = Color3.new(nr, ng, nb)

				local final: Color3 = plastic:Lerp(neon, t)

				local _: Color3 = final
			end
		end,

		["Raw Numbers"] = function(Profiler: Profiler, N: number): ()
			local baseR: number, baseG: number, baseB: number = 0.2, 0.4, 0.6
			local origR: number, origG: number, origB: number = 0.8, 0.7, 0.3
			local lightR: number, lightG: number, lightB: number = 1, 0.9, 0.8

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local pr: number = baseR + (origR - baseR) * tPlastic
				local pg: number = baseG + (origG - baseG) * tPlastic
				local pb: number = baseB + (origB - baseB) * tPlastic

				local nr: number = baseR * lightR
				local ng: number = baseG * lightG
				local nb: number = baseB * lightB

				local r: number = pr + (nr - pr) * t
				local g: number = pg + (ng - pg) * t
				local b: number = pb + (nb - pb) * t

				local _: Color3 = Color3.new(r, g, b)
			end
		end,
	},
}

return module
