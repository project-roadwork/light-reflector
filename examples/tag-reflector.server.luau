--!strict
--!native
-- USAGE: tag-reflector.server.luau
-- Reflector pre-tagger for Light Reflector

-- Copyright (c) 2024-2026 Project Roadwork and Contributors
-- Licensed under the Apache License, Version 2.0

local CollectionService = game:GetService("CollectionService")
local ReplicatedStorage = game:GetService("ReplicatedStorage")

local LightReflector = ReplicatedStorage.lightreflector

local config = require(LightReflector.shared.config)

local signFolders = config.SignConfig.SignsFolders
local reflectorFolders = config.ReflectorConfig.ReflectorsFolder

if config.ReflectorConfig.Enabled then
	for i,Folder in reflectorFolders do
		for i,p in Folder:GetDescendants() do
			if p:IsA("BasePart") and p.Parent and p.Parent.Name == "P" and not p:IsA("MeshPart") then
				CollectionService:AddTag(p, "Reflector")
			end
		end
	end

elseif config.SignConfig.Enabled then
	for i,Folder in signFolders do
		for i,p in Folder:GetDescendants() do
			if p:IsA("Decal") and p.Parent and p.Parent:IsA("BasePart") then
				CollectionService:AddTag(p.Parent, config.SignConfig.TagName)
			end
		end
	end
end

print(":: tag-reflector :: Completed!")

script:Destroy()
