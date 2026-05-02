--!native
--!strict
-- USAGE: lightreflector/client/render.luau
-- Rendering loop for Light Reflector

--[[

    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
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

-- IMPORTANT: Register Variables
const world: jecs.World,
components: types.Components,
_instancetoEntityId: {[Instance]: jecs.Entity},
cachedQueries: types.CachedQueries = register.getWorldUtils()

-- IMPORTANT: Configuration Variables
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig
local signConfig: types.SignConfig = baseConfig.SignConfig

-- IMPORTANT: Module Public and Private Variables
const activeReflectorEntities: {[jecs.Entity]: boolean} = detect.activeReflectorEntities
local currentDetectedEntities: { [jecs.Entity]: boolean } = {}
local _runnerThread : thread?
local hasInit: boolean = false

-- Equations
const clamp: (number, number, number) -> number = math.clamp
const abs: (number) -> number = math.abs
const exp: (number) -> number = math.exp

-- Micro Optimizations (Variables)
local signLerpSpeed: number = 0
local signLerpSpeedClamped: number = 0
local reflectorLerpSpeed: number = 0
local allInactive: boolean = true
local deltaTime: number, MPH: number = 0, 0

local RENDER_MIN_FPS: number = constraints.RENDER_MIN_FPS
local RENDER_MAX_FPS: number = constraints.RENDER_MAX_FPS

local minColorScale: number = reflectorConfig.minBrightness / 255
local maxColorScale: number = reflectorConfig.maxBrightness / 255

local inactiveMaterial: Enum.Material = reflectorConfig.inactiveMaterial

local riseMultiplier: number = 0
local fallMultiplier: number = 0

const renderWait: (number?) -> number = utils.renderWait
const sourceInstances: jecs.Cached_Query<BasePart> = cachedQueries.SourceInstances
const reflectors: jecs.Cached_Query<BasePart, types.ReflectorState> = cachedQueries.Reflectors
const signsPartsStates: jecs.Cached_Query<BasePart, types.SignEntity> = cachedQueries.SignsPartsStates

--[=[
	Public: Initialize

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function init(): ()
	if hasInit then
		return
	end

	config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
		baseConfig = NEW_CONFIG
		constraints = NEW_CONFIG.Constraints
		reflectorConfig = NEW_CONFIG.ReflectorConfig
		signConfig = NEW_CONFIG.SignConfig

		reflectorLerpSpeed = reflectorConfig.lerpSpeed
		signLerpSpeed = signConfig.lerpSpeed

		RENDER_MIN_FPS = constraints.RENDER_MIN_FPS
		RENDER_MAX_FPS = constraints.RENDER_MAX_FPS

		minColorScale = reflectorConfig.minBrightness / 255
		maxColorScale = reflectorConfig.maxBrightness / 255

		inactiveMaterial = reflectorConfig.inactiveMaterial
	end)

	hasInit = true
end

--[=[
	Public: Rendering loop

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start(): ()
	_runnerThread = constraints.SPAWN(utils.pcallRetry, function()
		while true do
			deltaTime, MPH = utils.adaptiveWait(renderWait, RENDER_MIN_FPS, RENDER_MAX_FPS,
				utils.getFastestSource(sourceInstances)) -- adaptive waiting based on fastest vehicle speed

			-- This should run in a higher FPS than the detect the module since it renders fading. Also, utils.renderWait uses RunService.PreRender
			-- rather than RunService.Heartbeat which I think the task sceduler uses.

			-- Render stepped / prerender runs on the client framerate, so it would make sense to put the fading under that event.

			if not dark() and allInactive then
				task.wait(.5)
				continue
			end

			allInactive = true

			currentDetectedEntities = detect.getDetectedEntities()

			if reflectorConfig.isEnabled then
		    	riseMultiplier = exp(-reflectorLerpSpeed * deltaTime)
				fallMultiplier = exp(-(reflectorLerpSpeed * 5) * deltaTime)

				for entity: jecs.Entity<nil>, part:BasePart, state: types.ReflectorState in reflectors do
					if not activeReflectorEntities[entity] then
						const baseColor: Color3 = state.origColor
						const lastColor: Color3 = state.lastColor

						if baseColor then
							if state.lastMaterial ~= inactiveMaterial then -- reducing writes
								part.Material = inactiveMaterial
								state.lastMaterial = inactiveMaterial
							end

							if lastColor ~= baseColor then
								if not utils.areColorsEqual(lastColor, baseColor, 0.01) then
									part.Color = baseColor
									state.lastColor = baseColor
								end
							end

						end

						if state.isHybrid then
						    if state.lastTransparency ~= 1 then
								--state.currentTransparency = 1
								state.lastTransparency = 1
								part.Transparency = 1
							end
						end

						world:remove(entity, components.ReflectorState)
						continue
					end

					const targetIntensity: number = state.targetIntensity

					state.currentIntensity =
						targetIntensity + (state.currentIntensity - targetIntensity) * riseMultiplier

					if targetIntensity <= 0 then
						state.currentIntensity *= fallMultiplier
					end

					if state.isHybrid then
						state.currentTransparency += (state.targetTransparency - state.currentTransparency)
							* clamp(reflectorLerpSpeed * deltaTime, 0, 1)

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

					const neonCenter: number = reflectorConfig.neonActivationIntensity
					const neonWidth: number = 0.55

					const neonStart: number = neonCenter - neonWidth
					const neonEnd: number = neonCenter + neonWidth

					local t: number = clamp((intensity - neonStart) / (neonEnd - neonStart), 0, 1)

					t = t * t * (3 - 2 * t)

					const baseColor: Color3 = state.baseColor
					const lightColor: Color3 = state.neutralizedColor

					const scale: number = minColorScale + (maxColorScale - minColorScale) * intensity

					local nr: number = baseColor.R * lightColor.R * scale
					local ng: number = baseColor.G * lightColor.G * scale
					local nb: number = baseColor.B * lightColor.B * scale

					local maxChannel: number = nr

					if ng > maxChannel then maxChannel = ng end
					if nb > maxChannel then maxChannel = nb end

					if maxChannel > 1 then
						const inv: number = 1 / maxChannel
						nr *= inv
						ng *= inv
						nb *= inv
					end

					const neonColor: Color3 = Color3.new(nr, ng, nb)

					const fadeStart: number = 0.15
					const fadeEnd: number = 0.6

					const tPlastic: number = clamp((intensity - fadeStart) / (fadeEnd - fadeStart), 0, 1)

					const plasticColor: Color3 = state.baseColor:Lerp(
						state.origColor,
						tPlastic
					)

					local newColor: Color3 = plasticColor:Lerp(neonColor, t)
					local newMaterial: Enum.Material

					if t > 0.5 or state.isHybrid then
						newMaterial = reflectorConfig.activeMaterial -- Neon
					else
						newMaterial = reflectorConfig.inactiveMaterial
						newColor = state.origColor
					end

					const r: number, g: number, b: number = newColor.R, newColor.G, newColor.B

					maxChannel = r

					if g > maxChannel then maxChannel = g end
					if b > maxChannel then maxChannel = b end

					if maxChannel > 1 then
						const inv = 1 / maxChannel
						newColor = Color3.new(r * inv, g * inv, b * inv)
					end

					if state.lastMaterial ~= newMaterial then
						part.Material = newMaterial
						state.lastMaterial = newMaterial
					end

					if state.lastColor ~= newColor then -- reduce areColorsEqual calls
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
				signLerpSpeedClamped = clamp(signLerpSpeed * deltaTime, 0, 1)

				for entity: jecs.Entity<nil>, part: Instance, signState: types.SignEntity in signsPartsStates do
					if signState.partRenderMode == "SurfaceGui" then
						const state: types.SurfaceGuiState? = signState.surfaceGuiState

						if not state then
							continue
						end

						const gui: (SurfaceGui & { ImageLabel: ImageLabel })? = state.gui

						if gui and gui.Parent then
							const inPart: boolean = currentDetectedEntities[entity] ~= nil

							if inPart then
								state.currentTransparency += (state.targetTransparency - state.currentTransparency) * signLerpSpeedClamped
								state.currentBrightness += (state.targetBrightness - state.currentBrightness) * signLerpSpeedClamped
								state.currentLightInfluence += (state.targetLightInfluence - state.currentLightInfluence) * signLerpSpeedClamped
							else
								state.currentTransparency += (1 - state.currentTransparency) * signLerpSpeedClamped
								state.currentBrightness += (0 - state.currentBrightness) * signLerpSpeedClamped
								state.currentLightInfluence += (1 - state.currentLightInfluence) * signLerpSpeedClamped

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

							if state.currentTransparency >= signConfig.inactiveTransparencyThreshold then
								state.isActive = false
								state.isPendingRemoval = true
							end

							if state.currentTransparency < 0.999 then
								allInactive = false
							end

							if state.lastColor3 ~= signState.neutralizedColor then
							    if not utils.areColorsEqual(state.lastColor3, signState.neutralizedColor, 0.01) then
									gui.ImageLabel.ImageColor3 = signState.neutralizedColor
									state.lastColor3 = signState.neutralizedColor
								end
							end
						end
					elseif signState.partRenderMode == "Decal" then
						const state: types.DecalState? = signState.decalState

						if not state then
							continue
						end

						const decal: Decal? = signState.mainDecal
						if not decal then continue end

						const inPart: boolean = currentDetectedEntities[entity] ~= nil

						if inPart then
							state.currentBrightness += (state.targetBrightness - state.currentBrightness) * signLerpSpeedClamped
						else
							state.currentBrightness += (0 - state.currentBrightness) * signLerpSpeedClamped
						end

						const base: Color3 = state.baseColor
						local light: Color3 = signState.neutralizedColor
						const scale: number = 1 + ((clamp(state.currentBrightness, 0, 4)) * signConfig.decalIntensityMultiplier) -- multiply to better match up the brightness with the SurfaceGui rendering mode

						const fadeStart: number = 0.05
						const brightness: number = state.currentBrightness

						const r: number = base.R * light.R * scale
						const g: number = base.G * light.G * scale
						const b: number = base.B * light.B * scale

						local newColor: Color3? = nil
						const litColor: Color3 = Color3.new(r, g, b)

						if not inPart then
						    if brightness < fadeStart then
                                const t: number = clamp(brightness / fadeStart, 0, 1)
                                newColor = litColor:Lerp(state.baseColor, 1 - t)
                            else
                                newColor = litColor
							end
						else
						    newColor = litColor
						end

						if state.lastColor3 ~= newColor then
						    if not utils.areColorsEqual(state.lastColor3, newColor, 0.01) then
								decal.Color3 = newColor
								state.lastColor3 = newColor
							end
						end

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
	init = init,
	start = start,
	safeCancelThread = safeCancelThread
})
