--!strict
--!native
-- USAGE: tag-reflector.server.luau
-- Reflector pre-tagger for Light Reflector

--[[
    SPDX-FileCopyrightText: NONE

    SPDX-License-Identifier: CC0-1.0 OR Unlicense
]]

-- Variables
local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightReflector = ReplicatedStorage.Packages.lightreflector

local config = require(LightReflector.shared.config).getConfig()

local signFolders = config.SignConfig.signsFolders
local reflectorFolders = config.ReflectorConfig.reflectorsFolder

if config.ReflectorConfig.Enabled then
	for i,Folder in reflectorFolders do
		for i,p in Folder:GetDescendants() do
			if p:IsA("BasePart") and p.Parent and p.Parent.Name == "P" and not p:IsA("MeshPart") then
				CollectionService:AddTag(p, "Reflector")
			end
		end
	end
end

if config.SignConfig.Enabled then
	for i,Folder in signFolders do
		for i,p in Folder:GetDescendants() do
			if p:IsA("Decal") and p.Parent and p.Parent:IsA("BasePart") then
				CollectionService:AddTag(p.Parent, config.SignConfig.tagName)
			end
		end
	end
end

print(":: tag-reflector :: Completed!")

script:Destroy()
