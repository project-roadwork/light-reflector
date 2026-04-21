--!native
--!strict
-- USAGE: lightreflector/client/render.luau
-- Rendering loop for Light Reflector

--[[

    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Modules
const types = require("../shared/types")
const config: types.Configuration = require("../shared/config")
const jecs: types.JecsModule = require("../shared/jecs")
const utils: types.Utils = require("./utils")
const register: types.Register = require("./register")
const detect: types.Detect = require("./detect")
const dark: () -> boolean = require("./dark")
const sources: types.SourcesModule = require("./sources")

-- IMPORTANT: Register Variables
const world: jecs.World,
components: types.Components,
instancetoEntityId: {[Instance]: jecs.Entity},
cachedQueries: types.CachedQueries = register.getWorldUtils()

-- IMPORTANT: Configuration Variables
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig
local generalConfig: types.GeneralConfig = baseConfig.General
local signConfig: types.SignConfig = baseConfig.SignConfig
local isConfigTracked: boolean = false

-- IMPORTANT: Module Public and Private Variables
const activeReflectorEntities: {[jecs.Entity]: boolean} = detect.activeReflectorEntities
local currentDetectedEntities: { [jecs.Entity]: boolean } = {}
local _runnerThread : thread?

-- Miscellaneous
const clamp: (number, number, number) -> number = math.clamp
const abs: (number) -> number = math.abs
const exp: (number) -> number = math.exp

--[=[
	Public: Rendering loop

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start(): ()
	local allInactive: boolean = true

	_runnerThread = constraints.SPAWN(utils.pcallRetry, function()

		-- Start config tracking
		if isConfigTracked == false then
			config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
				baseConfig = NEW_CONFIG
				constraints = NEW_CONFIG.Constraints
				reflectorConfig = NEW_CONFIG.ReflectorConfig
				generalConfig = NEW_CONFIG.General
				signConfig = NEW_CONFIG.SignConfig
			end)
			isConfigTracked = true
		end

		-- pcall replaced with pcallRetry
		while true do

			const deltaTime: number, MPH: number = utils.adaptiveWait(utils.renderWait,constraints.RENDER_MIN_FPS, constraints.RENDER_MAX_FPS,
				utils.getFastestDriveSeat(cachedQueries.VehicleInstances)) -- adaptive waiting based on fastest vehicle speed
			-- this should be in a higher FPS since it renders the fading
			-- also utils.renderWait uses RunService.PreRender rather than RunService.Heartbeat which I think the task scheduler uses
			-- render stepped / prerender runs on the client framerate so it would make sense to put the fading animations under that event,
			--  also considering that the target time to wait which is around 1/45 - 1/60 could be higher than the actual client framerate, which is not ideal

			const isDark: boolean = dark()

			if not isDark and allInactive then
				task.wait(1)
				continue
			end

			currentDetectedEntities = detect.getDetectedEntities()

			const reflectorConfig: types.ReflectorConfig = reflectorConfig

			local lerpSpeed: number = reflectorConfig.lerpSpeed

			if reflectorConfig.isEnabled then
				for entity: jecs.Entity<nil>, part:BasePart, state: types.ReflectorState in cachedQueries.Reflectors do
					if not activeReflectorEntities[entity] then
						const BaseMaterial = reflectorConfig.inactiveMaterial

						if state.baseColor then
							if state.lastMaterial ~= BaseMaterial then -- reducing writes
								part.Material = BaseMaterial
								state.lastMaterial = BaseMaterial
							end

							if state.lastColor ~= state.baseColor then
								if not utils.areColorsEqual(state.lastColor, state.baseColor, 0.01) then
									part.Color = state.baseColor
									state.lastColor = state.baseColor
								end
							end

						end
						world:remove(entity, components.ReflectorState)
						continue
					end

					const riseSpeed: number = reflectorConfig.lerpSpeed
					const fallSpeed: number = reflectorConfig.lerpSpeed * 5

					const f: number = exp(-riseSpeed * deltaTime)
					state.currentIntensity =
						state.targetIntensity + (state.currentIntensity - state.targetIntensity) * f

					if state.targetIntensity <= 0 then
						state.currentIntensity *= exp(-fallSpeed * deltaTime)
					end

			 --[[state.currentIntensity +=
				(state.targetIntensity - state.currentIntensity)
				* clamp(lerpSpeed * deltaTime, 0, 1)]]

					if state.isHybrid then

						state.currentTransparency += (state.targetTransparency - state.currentTransparency)
							* clamp(lerpSpeed * deltaTime, 0, 1)

						if abs(state.currentTransparency - state.lastTransparency) > 0.01 then
							part.Transparency = state.currentTransparency
							state.lastTransparency = state.currentTransparency
						end
					end

					if state.isActive == nil then
						state.isActive = false
					end

					if state.isActive then
						if state.currentIntensity <= reflectorConfig.inactivateIntensityThreshold then
							state.isActive = false
						end
					else
						if state.currentIntensity >= reflectorConfig.activateIntensityThreshold then
							state.isActive = true
						end
					end

					const intensity: number = state.currentIntensity
					--if abs(intensity - state.lastIntensity) < 0.00002 then
					--	continue
					--end

					local newColor: Color3?
					local newMaterial: Enum.Material?
					-- ^ variables to reduce .Material and .Color calls
					--   Will only be changed if the material/color is not the same as the current one

					if intensity >= reflectorConfig.neonActivationIntensity or state.isHybrid == true then
						newMaterial = reflectorConfig.activeMaterial

						const baseColor: Color3 = state.baseColor
						const minScale: number = reflectorConfig.minBrightness / 255
						const maxScale: number = reflectorConfig.maxBrightness / 255

						const scale: number = minScale + (maxScale - minScale) * intensity

						const r: number = clamp(baseColor.R * scale, 0, 1)
						const g: number = clamp(baseColor.G * scale, 0, 1)
						const b: number = clamp(baseColor.B * scale, 0, 1)

						newColor = Color3.new(r, g, b)

			 --[[elseif intensity > 0.3 then
				newMaterial = Enum.Material.Plastic

				newColor = state.baseColor:Lerp(
					reflectorConfig.partialDimmingBaseColor,
					intensity * 0.5
				)]]
					else
						--newMaterial = reflectorConfig.inactiveMaterial
						--newColor = state.baseColor

						const fadeStart: number = 0.15
						const fadeEnd: number = 0.6

						const t: number = clamp((intensity - fadeStart) / (fadeEnd - fadeStart), 0, 1)

						newMaterial = if intensity > 0 then Enum.Material.Plastic else reflectorConfig.inactiveMaterial

						newColor = state.baseColor:Lerp(
							reflectorConfig.partialDimmingBaseColor,
							t
						)
					end

					if state.lastMaterial ~= newMaterial then
						part.Material = newMaterial
						state.lastMaterial = newMaterial
					end

					if state.lastColor ~= newColor then
						if not utils.areColorsEqual(state.lastColor, newColor, 0.01) then
							part.Color = newColor
							state.lastColor = newColor
						end
					end

					state.lastIntensity = intensity

					if state.currentIntensity > 0.001 then
						allInactive = false
					end
				end
			end

			if signConfig.isEnabled then
				lerpSpeed = signConfig.lerpSpeed

				for entity: jecs.Entity<nil>, part: Instance, signState: types.SignEntity in cachedQueries.SignsPartsStates do
					if signState.partRenderMode == "SurfaceGui" then
						const state: types.SurfaceGuiState? = signState.surfaceGuiState

						if not state then
							continue
						end

						if signConfig.isEnabled == false then break end

						const gui: (SurfaceGui & { ImageLabel: ImageLabel })? = state.gui

						if gui and gui.Parent then
							const inPart: boolean = currentDetectedEntities[entity] ~= nil
							if inPart then
								state.currentTransparency += (state.targetTransparency - state.currentTransparency) * clamp(lerpSpeed * deltaTime, 0, 1)
								state.currentBrightness += (state.targetBrightness - state.currentBrightness) * clamp(lerpSpeed * deltaTime, 0, 1)
								state.currentLightInfluence += (state.targetLightInfluence - state.currentLightInfluence) * clamp(lerpSpeed * deltaTime, 0, 1)
							else
								state.currentTransparency += (1 - state.currentTransparency) * clamp(lerpSpeed * deltaTime, 0, 1)
								state.currentBrightness += (0 - state.currentBrightness) * clamp(lerpSpeed * deltaTime, 0, 1)
								state.currentLightInfluence += (1 - state.currentLightInfluence) * clamp(lerpSpeed * deltaTime, 0, 1)

								if state.currentTransparency >= signConfig.inactiveTransparencyThreshold then
									state.isPendingRemoval = true
								end
							end

							if state.lastBrightness ~= state.currentBrightness then
								gui.Brightness = state.currentBrightness
								state.lastBrightness = state.currentBrightness
							end

							if state.lastTransparency ~= state.currentTransparency then
								gui.ImageLabel.ImageTransparency = state.currentTransparency
								state.lastTransparency = state.currentTransparency
							end

							if state.lastLightInfluence ~= state.currentLightInfluence then
								gui.LightInfluence = state.currentLightInfluence
								state.lastLightInfluence = state.currentLightInfluence
							end

							const num: number = signConfig.inactiveTransparencyThreshold

							if state.currentTransparency >= num then
								state.isActive = false
								state.isPendingRemoval = true
							end

							if state.currentTransparency < 0.999 then
								allInactive = false
							end
						end
					elseif signState.partRenderMode == "Decal" then
						const state: types.DecalState? = signState.decalState

						if not state then
							continue
						end

						const decal: Decal? = signState.mainDecal
						if not decal then continue end

						const lerpSpeed: number = signConfig.lerpSpeed

						const inPart: boolean = currentDetectedEntities[entity] ~= nil

						if inPart then
							state.currentBrightness += (state.targetBrightness - state.currentBrightness) * clamp(lerpSpeed * deltaTime, 0, 1)
						else
							state.currentBrightness += (0 - state.currentBrightness) * clamp(lerpSpeed * deltaTime, 0, 1)
						end

						const base: Color3 = state.baseColor
						const scale: number = 1 + (clamp(state.currentBrightness, 0, 4) * signConfig.decalIntensityMultiplier) -- multiply to better match up the brightness with the SurfaceGui rendering mode

						const r: number = base.R * scale
						const g: number = base.G * scale
						const b: number = base.B * scale

						decal.Color3 = Color3.new(r, g, b)

						if state.currentBrightness > 0.001 then
							allInactive = false
						end
					end
				end
			end
		end
	end, constraints.MAX_PCALL_RETRIES)
end

--[=[
	Public: Safe cancels the runner thread

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function safeCancelThread(): (boolean, string? | any)
	if not _runnerThread then
		return false, "There is no running thread"
	end

	if typeof(_runnerThread) ~= "thread" then
		return false, "Runner thread is not a thread"
	end

	const threadToCancel: thread = _runnerThread -- have to add this due to pcall issues

	const success: boolean, result: string? | any = pcall(function() -- pcall typing is broken, cannot fix
		task.cancel(threadToCancel)
	end)

	return success, result
end

-- Return public API
return table.freeze({
	Name = "render",
	start = start,
	safeCancelThread = safeCancelThread
}) :: types.Render
