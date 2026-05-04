--!strict
--!native
--
--[[
    SPDX-FileCopyrightText: 2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0
]]
--
-- Experiment 2 compares the following:
-- Table
-- Vector3
-- vector
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
		return 1000
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

				local _: Color3 = plastic:Lerp(neon, t)
			end
		end,

		["Color3 Pipeline (No Lerp)"] = function(Profiler: Profiler, N: number): ()
			local base: Color3 = Color3.new(0.2, 0.4, 0.6)
			local orig: Color3 = Color3.new(0.8, 0.7, 0.3)
			local light: Color3 = Color3.new(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local pr: number = base.R + (orig.R - base.R) * tPlastic
				local pg: number = base.G + (orig.G - base.G) * tPlastic
				local pb: number = base.B + (orig.B - base.B) * tPlastic

				local plastic: Color3 = Color3.new(pr, pg, pb)

				local nr: number = base.R * light.R
				local ng: number = base.G * light.G
				local nb: number = base.B * light.B

				local neon: Color3 = Color3.new(nr, ng, nb)

				local r: number = pr + (nr - pr) * t
				local g: number = pg + (ng - pg) * t
				local b: number = pb + (nb - pb) * t

				local _: Color3 = Color3.new(r, g, b)
			end
		end,

		["vector Pipeline"] = function(Profiler: Profiler, N: number): ()
			local base: vector = vector.create(0.2, 0.4, 0.6)
			local orig: vector = vector.create(0.8, 0.7, 0.3)
			local light: vector = vector.create(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local plastic: vector = vector.lerp(base, orig, tPlastic)

				local neon: vector = vector.create(base.x * light.x, base.y * light.y, base.z * light.z)

				local finalVec: vector = vector.lerp(plastic, neon, t)

				local _: Color3 = Color3.new(finalVec.x, finalVec.y, finalVec.z)
			end
		end,

		["vector Pipeline (no lerp)"] = function(Profiler: Profiler, N: number): ()
			local base: vector = vector.create(0.2, 0.4, 0.6)
			local orig: vector = vector.create(0.8, 0.7, 0.3)
			local light: vector = vector.create(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local plastic: vector = base + (orig - base) * tPlastic

				local neon: vector = vector.create(base.x * light.x, base.y * light.y, base.z * light.z)

				local finalVec: vector = plastic + (neon - plastic) * t

				local _: Color3 = Color3.new(finalVec.x, finalVec.y, finalVec.z)
			end
		end,

		["Vector3 Pipeline (no lerp)"] = function(Profiler: Profiler, N: number): ()
			local base: Vector3 = Vector3.new(0.2, 0.4, 0.6)
			local orig: Vector3 = Vector3.new(0.8, 0.7, 0.3)
			local light: Vector3 = Vector3.new(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local plastic: Vector3 = base + (orig - base) * tPlastic
				local neon: Vector3 = Vector3.new(base.X * light.X, base.Y * light.Y, base.Z * light.Z)
				local finalVec: Vector3 = plastic + (neon - plastic) * t

				local _: Color3 = Color3.new(finalVec.X, finalVec.Y, finalVec.Z)
			end
		end,

		["Vector3 Pipeline"] = function(Profiler: Profiler, N: number): ()
			local base: Vector3 = Vector3.new(0.2, 0.4, 0.6)
			local orig: Vector3 = Vector3.new(0.8, 0.7, 0.3)
			local light: Vector3 = Vector3.new(1, 0.9, 0.8)

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				local plastic: Vector3 = base:Lerp(orig, tPlastic)

				local neon: Vector3 = Vector3.new(base.X * light.X, base.Y * light.Y, base.Z * light.Z)

				local finalVec: Vector3 = plastic:Lerp(neon, t)

				local _: Color3 = Color3.new(finalVec.X, finalVec.Y, finalVec.Z)
			end
		end,

		["Table Pipeline (Reuse)"] = function(Profiler: Profiler, N: number): ()
			type Vec3 = { x: number, y: number, z: number }

			local base: Vec3 = { x = 0.2, y = 0.4, z = 0.6 }
			local orig: Vec3 = { x = 0.8, y = 0.7, z = 0.3 }
			local light: Vec3 = { x = 1, y = 0.9, z = 0.8 }

			local plastic: Vec3 = { x = 0, y = 0, z = 0 }
			local neon: Vec3 = { x = 0, y = 0, z = 0 }
			local finalVec: Vec3 = { x = 0, y = 0, z = 0 }

			local t: number = 0.5
			local tPlastic: number = 0.3

			for i: number = 1, N do
				plastic.x = base.x + (orig.x - base.x) * tPlastic
				plastic.y = base.y + (orig.y - base.y) * tPlastic
				plastic.z = base.z + (orig.z - base.z) * tPlastic

				neon.x = base.x * light.x
				neon.y = base.y * light.y
				neon.z = base.z * light.z

				finalVec.x = plastic.x + (neon.x - plastic.x) * t
				finalVec.y = plastic.y + (neon.y - plastic.y) * t
				finalVec.z = plastic.z + (neon.z - plastic.z) * t

				local _: Color3 = Color3.new(finalVec.x, finalVec.y, finalVec.z)
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
