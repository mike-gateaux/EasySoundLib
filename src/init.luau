local easySound = {}
local cch = {}
local activeSounds = { unutilized = {} :: soundObject, anchors = {} :: { Part } }

local RunService = game:GetService("RunService")
local SoundService = game:GetService("SoundService")
local Workspace = game:GetService("Workspace")

local Sift = require(script.Packages.Sift)
local Signal = require(script.Packages.GoodSignal)

local timescaleValue = { changed = Signal.new(), value = 1 }

type objectValue = {
	changed: typeof(Signal.new()),
	value: number,
}

type soundObject = {
	instance: Sound,
	speed: number,
	id: string,
	anchor: Part,
	timescaleObject: {
		connectedTo: objectValue,
		changed: typeof(Signal.new()),
	},
	soundGroupObject: {
		connectedTo: objectValue?,
		changed: typeof(Signal.new()),
	},
}

local function setSpeed(soundObject)
	soundObject.instance.PlaybackSpeed = soundObject.timescaleObject.connectedTo.value * soundObject.speed
end

local function connectObjectToTimescaleValue(soundObject)
	soundObject.timescaleObject.connectedTo.changed:Connect(function()
		soundObject.instance.PlaybackSpeed = soundObject.timescaleObject.connectedTo.value * soundObject.speed
	end)
end

local function addSoundToPool(soundObject)
	Sift.Array.removeIndex(activeSounds, Sift.Array.find(activeSounds, soundObject) :: number)
	Sift.Array.append(activeSounds.unutilized, soundObject)
end

local function toggleSound(enable, soundObject, looped, poolAfterEnd)
	if enable then
		soundObject.instance:Play()
		soundObject.instance.Looped = looped
		soundObject.timescaleObject.changed:Connect(connectObjectToTimescaleValue)

		setSpeed(soundObject)
		connectObjectToTimescaleValue(soundObject)

		if poolAfterEnd then
			soundObject.instance.Ended:Connect(function()
				addSoundToPool(soundObject)
			end)
		end

		return
	end

	soundObject.instance:Stop()

	if poolAfterEnd then
		addSoundToPool(soundObject)
	end
end

function createInstance(type, properties, children)
	local newObject = Instance.new(type)

	return modifyInstance(newObject, properties, children)
end

function modifyInstance(object, properties, children)
	for key, value in properties or {} do
		object[key] = value
	end

	for key, object in children or {} do
		object.Parent = object
	end

	return object
end

local cacheFolder = createInstance("Configuration", {
	Parent = SoundService,
	Name = ("%sasySoundInstances"):format(RunService:IsClient() and "e" or "serverE"),
})

local anchorCacheFolder = createInstance("Configuration", {
	Parent = Workspace,
	Name = ("%snchorInstances"):format(RunService:IsClient() and "a" or "serverA"),
})

function easySound.toId(id, valid)
	return (typeof(id) == "number" and tonumber(tostring(id)) ~= nil)
			and (valid and ("rbxassetid://%d"):format(id) or id)
		or valid and tonumber(id:gsub("rbxassetid://", ""))
		or id
end

function easySound.resolveAnchor(partOrPosition)
	local isPosition = typeof(partOrPosition) == "Vector3"

	if isPosition then
		local poolExistingInstance = #activeSounds.anchors > 0
		local newAnchor = poolExistingInstance
				and { modifyInstance(activeSounds.anchors[1], { Position = partOrPosition }), false }
			or {
				createInstance("Part", {
					Name = ("easySoundAnchor%d"):format(id:generateId(#activeSounds > 16_384 and 32 or 16)),
					Parent = anchorCacheFolder,
					Anchored = true,
					Size = Vector3.new(),
					CanCollide = false,
					CanQuery = false,
					Transparency = 1,
				}),
				true,
			}

		if not newAnchor[2] then
			Sift.Array.removeIndex(activeSounds.anchors, Sift.Array.find(activeSounds.anchors, newAnchor[1]) :: number)
		end

		return newAnchor[1]
	end

	return partOrPosition
end

function easySound.playLoop(properties)
	local soundInstance = easySound.create(properties)
	toggleSound(true, soundInstance, true, false)

	return {
		stop = function()
			toggleSound(false, soundInstance, false, false)
		end,
		complete = function()
			toggleSound(false, soundInstance, false, true)
		end,
	}
end

function easySound.play(properties)
	local soundInstance = easySound.create(properties)
	toggleSound(true, soundInstance, false, true)
end

function easySound.create(properties)
	local soundId = easySound.toId(properties.id)
	local findResult = #activeSounds.unutilized > 0 and activeSounds.unutilized[1]

	if findResult then
		Sift.Array.removeIndex(activeSounds.unutilized, Sift.Array.find(activeSounds, findResult) :: number)
		Sift.Array.append(activeSounds, findResult)

		return Sift.Dictionary.merge(findResult, {
			instance = modifyInstance(findResult.instance, {
				Parent = easySound.resolveAnchor(properties.part or properties.position) or cacheFolder,
				SoundId = soundId,
				PlaybackSpeed = properties.speed,
			}),
		})
	end

	local newSoundInstance = createInstance("Sound", {
		Name = ("easySoundInstance%d"):format(id:generateId(#activeSounds > 16_384 and 32 or 16)),
		Parent = easySound.resolveAnchor(properties.part or properties.position) or cacheFolder,
		SoundId = soundId,
		PlaybackSpeed = properties.speed,
	}, {
		PitchShift = createInstance("PitchShiftSoundEffect", {
			Pitch = 1,
		}),
	})

	local newObject = {
		speed = properties.speed,
		id = soundId,
		anchor = newSoundInstance.Parent,
		instance = newSoundInstance,
		timescaleObject = { connectedTo = timescaleValue, changed = Signal.new() },
		soundGroupObject = { changed = Signal.new() },
	}

	Sift.Array.append(activeSounds, newObject)

	return newObject
end

function easySound.connectToSoundGroup(sound, type) end

function easySound.connectToTimescaleValue(sound, timescale)
	local newTimescaleObject = { changed = Signal.new(), value = timescale }

	sound.timescaleObject.connectedTo = newTimescaleObject
	sound.timescaleObject.changed:Fire(sound)
end

function easySound.changeGlobalTimescaleValue(timescale)
	timescaleValue.value = timescale
	timescaleValue.changed:Fire()
end

return easySound
