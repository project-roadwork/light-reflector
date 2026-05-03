--!native

return {
	ParameterGenerator = function()
		return 10000
	end,

	Functions = {

		["Color3 Pipeline"] = function(Profiler, N)
			local base = Color3.new(0.2, 0.4, 0.6)
			local orig = Color3.new(0.8, 0.7, 0.3)
			local light = Color3.new(1, 0.9, 0.8)

			local t = 0.5
			local tPlastic = 0.3

			for i = 1, N do
				local plastic = base:Lerp(orig, tPlastic)

				local nr = base.R * light.R
				local ng = base.G * light.G
				local nb = base.B * light.B

				local neon = Color3.new(nr, ng, nb)

				local final = plastic:Lerp(neon, t)

				local _ = final
			end
		end,

		["Raw Numbers"] = function(Profiler, N)
			local baseR, baseG, baseB = 0.2, 0.4, 0.6
			local origR, origG, origB = 0.8, 0.7, 0.3
			local lightR, lightG, lightB = 1, 0.9, 0.8

			local t = 0.5
			local tPlastic = 0.3

			for i = 1, N do
				local pr = baseR + (origR - baseR) * tPlastic
				local pg = baseG + (origG - baseG) * tPlastic
				local pb = baseB + (origB - baseB) * tPlastic

				local nr = baseR * lightR
				local ng = baseG * lightG
				local nb = baseB * lightB

				local r = pr + (nr - pr) * t
				local g = pg + (ng - pg) * t
				local b = pb + (nb - pb) * t

				local _ = Color3.new(r, g, b)
			end
		end,

	},
}
