function RegisterMod(modname, apiversion)
	local mod = {
		Name = modname,
		AddCallback = function(self, callbackId, fn, param)
			Isaac.AddCallback(self, callbackId, fn, param)
		end,
		AddPriorityCallback = function(self, callbackId, priority, fn, param)
			Isaac.AddPriorityCallback(self, callbackId, priority, fn, param)
		end,
		RemoveCallback = function(self, callbackId, fn)
			Isaac.RemoveCallback(self, callbackId, fn)
		end,
		SaveData = function(self, data)
			Isaac.SaveModData(self, data)
		end,
		LoadData = function(self)
			return Isaac.LoadModData(self)
		end,
		HasData = function(self)
			return Isaac.HasModData(self)
		end,
		RemoveData = function(self)
			Isaac.RemoveModData(self)
		end
	}
	Isaac.RegisterMod(mod, modname, apiversion)
	return mod
end

function StartDebug()
	local ok, m = pcall(require, 'mobdebug') 
	if ok and m then
		m.start()
	else
		Isaac.DebugString("Failed to start debugging.")
		-- m is now the error 
		-- Isaac.DebugString(m)
	end
end

local debug_getinfo = debug.getinfo

local function checktype(index, val, typ, level)
	local t = type(val)
	if t ~= typ then
		error(string.format("bad argument #%d to '%s' (%s expected, got %s)", index, debug_getinfo(level).name, typ, t), level+1)
	end
end

local function checknumber(index, val, level) checktype(index, val, "number", (level or 2)+1) end
local function checkfunction(index, val, level) checktype(index, val, "function", (level or 2)+1) end
local function checkstring(index, val, level) checktype(index, val, "string", (level or 2)+1) end
local function checktable(index, val, level) checktype(index, val, "table", (level or 2)+1) end

------------------------------------------------------------
-- Callbacks

local Callbacks = {}

local defaultCallbackMeta = {
	__matchParams = function(a, b)
		return not a or not b or a == -1 or b == -1 or a == b
	end
}

function _RunCallback(callbackId, param, ...)
	local callbacks = Callbacks[callbackId]
	if callbacks then
		local matchFunc = getmetatable(callbacks).__matchParams or defaultCallbackMeta.__matchParams
		
		for _,v in ipairs(callbacks) do
			if matchFunc(param, v.Param) then
				local result = v.Function(v.Mod, ...)
				if result ~= nil  then
					return result
				end
			end
		end
	end
end

function _UnloadMod(mod)
	Isaac.RunCallback(ModCallbacks.MC_PRE_MOD_UNLOAD, mod)
	
	for callbackId,callbacks in pairs(Callbacks) do
		for i=#callbacks,1,-1 do
			if callbacks[i].Mod == mod then
				table.remove(callbacks, i)
			end
		end
		
		if #callbacks == 0 then
			if type(callbackId) == "number" then
				-- No more functions left, disable this callback
				Isaac.SetBuiltInCallbackState(callbackId, false)
			end
		end
	end
end

rawset(Isaac, "AddPriorityCallback", function(mod, callbackId, priority, fn, param)
	checknumber(3, priority)
	checkfunction(4, fn)
	
	local callbacks = Isaac.GetCallbacks(callbackId, true)
	local wasEmpty = #callbacks == 0
	
	local pos = #callbacks+1
	for i=#callbacks,1,-1 do
		if callbacks[i].Priority <= priority then
			break
		else
			pos = pos-1
		end
	end
	
	table.insert(callbacks, pos, {Mod = mod, Function = fn, Priority = priority, Param = param})
	
	if wasEmpty then
		if type(callbackId) == "number" then
			-- Enable this callback
			Isaac.SetBuiltInCallbackState(callbackId, true)
		end
	end
end)

rawset(Isaac, "AddCallback", function(mod, callbackId, fn, param)
	checkfunction(3, fn)
	Isaac.AddPriorityCallback(mod, callbackId, CallbackPriority.DEFAULT, fn, param)
end)

rawset(Isaac, "RemoveCallback", function(mod, callbackId, fn)
	checkfunction(3, fn)
	
	local callbacks = Callbacks[callbackId]
	if callbacks then
		for i=#callbacks,1,-1 do
			if callbacks[i].Function == fn then
				table.remove(callbacks, i)
			end
		end
		
		-- No more functions left, disable this callback
		if not next(callbacks) then
			if type(callbackId) == "number" then
				Isaac.SetBuiltInCallbackState(callbackId, false)
			end
		end
	end
end)

rawset(Isaac, "GetCallbacks", function(callbackId, createIfMissing)
	if createIfMissing and not Callbacks[callbackId] then
		Callbacks[callbackId] = setmetatable({}, defaultCallbackMeta)
	end
	
	return Callbacks[callbackId] or {}
end)

local RunCallback = _RunCallback

rawset(Isaac, "RunCallbackWithParam", RunCallback)
rawset(Isaac, "RunCallback", function(callbackID, ...) return RunCallback(callbackID, nil, ...) end)

------------------------------------------------------------
-- Constants

REPENTANCE = true
REPENTANCE_PLUS = true

-- Vector.Zero
rawset(Vector, "Zero", Vector(0,0))

-- Vector.One
rawset(Vector, "One", Vector(1,1))

-- Color.Default
rawset(Color, "Default", Color(1,1,1,1,0,0,0))

-- KColor presets
rawset(KColor, "Black", KColor(0, 0, 0, 1))
rawset(KColor, "Red", KColor(1, 0, 0, 1))
rawset(KColor, "Green", KColor(0, 1, 0, 1))
rawset(KColor, "Blue", KColor(0, 0, 1, 1))
rawset(KColor, "Yellow", KColor(1, 1, 0, 1))
rawset(KColor, "Cyan", KColor(0, 1, 1, 1))
rawset(KColor, "Magenta", KColor(1, 0, 1, 1))
rawset(KColor, "White", KColor(1, 1, 1, 1))
rawset(KColor, "Transparent", KColor(0, 0, 0, 0))

------------------------------------------------------------
-- Compatibility wrappers begin here

local META, META0
local function BeginClass(T)
	META = {}
	if type(T) == "function" then
		META0 = getmetatable(T())
	else
		META0 = getmetatable(T).__class
	end
end

local function EndClass()
	local oldIndex = META0.__index
	local newMeta = META
	
	rawset(META0, "__index", function(self, k)
		return newMeta[k] or oldIndex(self, k)
	end)
end

local function tobitset128(n)
	if type(n) == "number" then
		return BitSet128(n, 0)
	else
		return n
	end
end

-- Isaac -----------------------------------------------

-- EntityPlayer Isaac.GetPlayer(int ID = 0)
-- table Isaac.QueryRadius(Vector Position, float Radius, int Partitions = 0xFFFFFFFF)
-- table Isaac.FindByType(EntityType Type, int Variant = -1, int SubType = -1, bool Cache = false, bool IgnoreFriendly = false)
-- int Isaac.CountEntities(Entity Spawner, EntityType Type = EntityType.ENTITY_NULL, int Variant = -1, int SubType = -1)

-- int Isaac.GetPlayerTypeByName(string Name, boolean IsBSkin = false)

-- Color -----------------------------------------------

-- Color Color(float R, float G, float B, float A=1, float RO=0, float GO=0, float BO=0)
local Color_constructor = getmetatable(Color).__call
getmetatable(Color).__call = function(self, r, g, b, a, ro, go, bo)
	return Color_constructor(self, r, g, b, a or 1, ro or 0, go or 0, bo or 0)
end

-- Vector -----------------------------------------------
local META_VECTOR = getmetatable(Vector).__class

-- Reimplement Vector:__mul to allow commutative multiplication and vector-vector multiplication
rawset(META_VECTOR, "__mul", function(a, b)
	if getmetatable(a) == META_VECTOR then
		return getmetatable(b) == META_VECTOR and Vector(a.X*b.X, a.Y*b.Y) or Vector(a.X*b,a.Y*b)
	else
		return Vector(a*b.X,a*b.Y)
	end
end)

-- BitSet128 -----------------------------------------------
local META_BITSET128 = getmetatable(BitSet128).__class

rawset(META_BITSET128, "__bnot", function(a)
	return BitSet128(~a.l, ~a.h)
end)

rawset(META_BITSET128, "__bor", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return BitSet128(a.l|b.l, a.h|b.h)
end)

rawset(META_BITSET128, "__band", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return BitSet128(a.l&b.l, a.h&b.h)
end)

rawset(META_BITSET128, "__bxor", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return BitSet128(a.l~b.l, a.h~b.h)
end)

rawset(META_BITSET128, "__shl", function(a, b)
	return BitSet128(a.l<<b, (a.h<<b) | (a.l>>(64-b)))
end)

rawset(META_BITSET128, "__shr", function(a, b)
	return BitSet128((a.l>>b) | (a.h<<(64-b)), a.h>>b)
end)

-- god damnit Lua this doesn't work when comparing with a normal number
rawset(META_BITSET128, "__eq", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return a.l==b.l and a.h==b.h
end)

rawset(META_BITSET128, "__lt", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return a.h<b.h or (a.h==b.h and a.l<b.l)
end)

rawset(META_BITSET128, "__le", function(a, b)
	a, b = tobitset128(a), tobitset128(b)
	return a.h<b.h or (a.h==b.h and a.l<=b.l)
end)

local BitSet128_constructor = getmetatable(BitSet128).__call
getmetatable(BitSet128).__call = function(self, l, h)
	return BitSet128_constructor(self, l or 0, h or 0)
end

---------------------------------------------------------
BeginClass(Font)

local Font_GetStringWidth = META0.GetStringWidth
local Font_DrawString = META0.DrawString

-- Legacy
function META:GetStringWidthUTF8(str)
	return Font_GetStringWidth(self, str)
end

function META:DrawString(str, x, y, param4, param5, param6, param7)
	-- Legacy call (param4 is KColor)
	if type(param4) == "userdata" then
		return self:DrawStringScaled(str, x, y, 1.0, 1.0, param4, param5 or 0, param6)
	-- New call
	else
		return Font_DrawString(self, str, x, y, param4, param5, param6, param7)
	end
end

-- Legacy
function META:DrawStringScaled(str, x, y, sx, sy, col, boxWidth, center)
	align = DrawStringAlignment.TOP_LEFT
	if boxWidth == nil then
		boxWidth = 0
	end
	if boxWidth ~= 0 then
		strWidth = self:GetStringWidth(str)
		if center == true then
			align = DrawStringAlignment.TOP_CENTER
			x = x + ( boxWidth * 0.5 )
		else
			align = DrawStringAlignment.TOP_RIGHT
			x = x + boxWidth
		end
	end
	settings = FontRenderSettings()
	settings:SetAlignment(align)
	return Font_DrawString(self, str, x, y, sx, sy, col, settings)
end

-- Legacy
function META:DrawStringUTF8(str, x, y, col, boxWidth, center)
	return self:DrawStringScaled(str, x, y, 1.0, 1.0, col, boxWidth or 0, center)
end

-- Legacy
function META:DrawStringScaledUTF8(str, x, y, sx, sy, col, boxWidth, center)
	return self:DrawStringScaled(str, x, y, sx, sy, col, boxWidth or 0, center)
end

EndClass()

---------------------------------------------------------
BeginClass(ItemPool)

-- CollectibleType ItemPool:GetCollectible(ItemPoolType PoolType, boolean Decrease = false, int Seed = Random(), CollectibleType DefaultItem = CollectibleType.COLLECTIBLE_NULL)
local ItemPool_GetCollectible = META0.GetCollectible
function META:GetCollectible(poolType, decrease, seed, defaultItem)
	return ItemPool_GetCollectible(self, poolType, seed or Random(), (decrease and 0) or 1, defaultItem or 0)
end

-- TrinketType ItemPool:GetTrinket(boolean DontAdvanceRNG = false)
local ItemPool_GetTrinket = META0.GetTrinket
function META:GetTrinket(noAdvance)
	return ItemPool_GetTrinket(self, noAdvance)
end

-- PillEffect ItemPool:GetPillEffect(PillColor PillColor, EntityPlayer Player = nil)
local ItemPool_GetPillEffect = META0.GetPillEffect
function META:GetPillEffect(pillColor, player)
	return ItemPool_GetPillEffect(self, pillColor, player)
end

EndClass()

---------------------------------------------------------
BeginClass(SFXManager)

-- void SFXManager:Play(SoundEffect ID, float Volume = 1, int FrameDelay = 2, boolean Loop = false, float Pitch = 1, float Pan = 0)
local SFXManager_Play = META0.Play
function META:Play(sound, volume, frameDelay, loop, pitch, pan)
	SFXManager_Play(self, sound, volume or 1, frameDelay or 2, loop, pitch or 1, pan or 0)
end

EndClass()

---------------------------------------------------------
BeginClass(HUD)

-- void HUD:FlashChargeBar(EntityPlayer Player, ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local HUD_FlashChargeBar = META0.FlashChargeBar
function META:FlashChargeBar(player, slot)
	HUD_FlashChargeBar(self, player, slot or 0)
end

-- void HUD:InvalidateActiveItem(EntityPlayer Player, ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local HUD_InvalidateActiveItem = META0.InvalidateActiveItem
function META:InvalidateActiveItem(player, slot)
	HUD_InvalidateActiveItem(self, player, slot or 0)
end

EndClass()

---------------------------------------------------------
BeginClass(TemporaryEffects)

-- void TemporaryEffects:AddCollectibleEffect(CollectibleType CollectibleType, boolean AddCostume = true, int Count = 1)
local TemporaryEffects_AddCollectibleEffect = META0.AddCollectibleEffect
function META:AddCollectibleEffect(id, addCostume, num)
	TemporaryEffects_AddCollectibleEffect(self, id, addCostume or addCostume == nil, num or 1)
end

-- void TemporaryEffects:AddTrinketEffect(TrinketType TrinketType, boolean AddCostume = true, int Count = 1)
local TemporaryEffects_AddTrinketEffect = META0.AddTrinketEffect
function META:AddTrinketEffect(id, addCostume, num)
	TemporaryEffects_AddTrinketEffect(self, id, addCostume or addCostume == nil, num or 1)
end

-- void TemporaryEffects:AddNullEffect(NullItemID NullId, boolean AddCostume = true, int Count = 1)
local TemporaryEffects_AddNullEffect = META0.AddNullEffect
function META:AddNullEffect(id, addCostume, num)
	TemporaryEffects_AddNullEffect(self, id, addCostume or addCostume == nil, num or 1)
end

-- void TemporaryEffects:RemoveCollectibleEffect(CollectibleType CollectibleType, int Count = 1)
-- * Count=-1 removes all instances of that effect
local TemporaryEffects_RemoveCollectibleEffect = META0.RemoveCollectibleEffect
function META:RemoveCollectibleEffect(id, num)
	TemporaryEffects_RemoveCollectibleEffect(self, id, num or 1)
end

-- void TemporaryEffects:RemoveTrinketEffect(TrinketType TrinketType, int Count = 1)
-- * Count=-1 removes all instances of that effect
local TemporaryEffects_RemoveTrinketEffect = META0.RemoveTrinketEffect
function META:RemoveTrinketEffect(id, num)
	TemporaryEffects_RemoveTrinketEffect(self, id, num or 1)
end

-- void TemporaryEffects:RemoveNullEffect(NullItemID NullId, int Count = 1)
-- * Count=-1 removes all instances of that effect
local TemporaryEffects_RemoveNullEffect = META0.RemoveNullEffect
function META:RemoveNullEffect(id, num)
	TemporaryEffects_RemoveNullEffect(self, id, num or 1)
end

EndClass()

---------------------------------------------------------
BeginClass(Room)

-- Vector Room:FindFreePickupSpawnPosition(Vector Pos, float InitialStep = 0, boolean AvoidActiveEntities = false, boolean AllowPits = false)
local Room_FindFreePickupSpawnPosition = META0.FindFreePickupSpawnPosition
function META:FindFreePickupSpawnPosition(pos, initStep, avoidActive, allowPits)
	return Room_FindFreePickupSpawnPosition(self, pos, initStep or 0, avoidActive, allowPits)
end

-- boolean, Vector Room:CheckLine(Vector Pos1, Vector Pos2, LinecheckMode Mode, int GridPathThreshold = 0, boolean IgnoreWalls = false, boolean IgnoreCrushable = false)
-- * Returns
--      boolean: true if there are no obstructions between Pos1 and Pos2, false otherwise
--      Vector: first hit position from Pos1 to Pos2 (returns Pos2 if the line didn't hit anything)
local Room_CheckLine = META0.CheckLine
function META:CheckLine(pos1, pos2, mode, gridPathThreshold, ignoreWalls, ignoreCrushable)
	local out = Vector(0, 0)
	local ok = Room_CheckLine(self, pos1, pos2, mode, gridPathThreshold or 0, ignoreWalls, ignoreCrushable, out)
	return ok, out
end

-- boolean Room:TrySpawnBlueWombDoor(boolean FirstTime = true, boolean IgnoreTime = false, boolean Force = false)
local Room_TrySpawnBlueWombDoor = META0.TrySpawnBlueWombDoor
function META:TrySpawnBlueWombDoor(firstTime, ignoreTime, force)
	return Room_TrySpawnBlueWombDoor(self, firstTime or firstTime == nil, ignoreTime, force)
end

-- void Room:MamaMegaExplosion(Vector Position = Vector.Zero, EntityPlayer Player = nil)
local Room_MamaMegaExplosion = META0.MamaMegaExplosion
function META:MamaMegaExplosion(position, player)
	return Room_MamaMegaExplosion(self, position or Vector.Zero, player)
end

EndClass()

---------------------------------------------------------
BeginClass(MusicManager)

-- void	MusicManager:Play(Music ID, float Volume = 1)
local MusicManager_Play = META0.Play
function META:Play(id, volume)
	MusicManager_Play(self, id, volume or 1)
end

-- void	MusicManager:Fadein(Music ID, float Volume = 1, float FadeRate = 0.08)
local MusicManager_Fadein = META0.Fadein
function META:Fadein(id, volume, fadeRate)
	MusicManager_Fadein(self, id, volume or 1, fadeRate or 0.08)
end

-- void	MusicManager:Crossfade(Music ID, float FadeRate = 0.08)
local MusicManager_Crossfade = META0.Crossfade
function META:Crossfade(id, fadeRate)
	MusicManager_Crossfade(self, id, fadeRate or 0.08)
end

-- void	MusicManager:Fadeout(float FadeRate = 0.08)
local MusicManager_Fadeout = META0.Fadeout
function META:Fadeout(fadeRate)
	MusicManager_Fadeout(self, fadeRate or 0.08)
end

-- void	MusicManager:EnableLayer(int LayerId = 0, boolean Instant = false)
local MusicManager_EnableLayer = META0.EnableLayer
function META:EnableLayer(id, instant)
	MusicManager_EnableLayer(self, id or 0, instant)
end

-- void	MusicManager:DisableLayer(int LayerId = 0)
local MusicManager_DisableLayer = META0.DisableLayer
function META:DisableLayer(id)
	MusicManager_DisableLayer(self, id or 0)
end

-- boolean MusicManager:IsLayerEnabled(int LayerId = 0)
local MusicManager_IsLayerEnabled = META0.IsLayerEnabled
function META:IsLayerEnabled(id)
	return MusicManager_IsLayerEnabled(self, id or 0)
end

-- void	MusicManager:VolumeSlide(float TargetVolume, float FadeRate = 0.08)
local MusicManager_VolumeSlide = META0.VolumeSlide
function META:VolumeSlide(vol, fadeRate)
	return MusicManager_VolumeSlide(self, vol, fadeRate or 0.08)
end

EndClass()

---------------------------------------------------------
BeginClass(Game)

-- void Game:ChangeRoom(int RoomIndex, int Dimension = -1)
local Game_ChangeRoom = META0.ChangeRoom
function META:ChangeRoom(idx, dim)
	Game_ChangeRoom(self, idx, dim or -1)
end

-- void Game:Fart(Vector Position, float Radius = 85, Entity Source = nil, float FartScale = 1, int FartSubType = 0, Color FartColor = Color.Default)
local Game_Fart = META0.Fart
function META:Fart(pos, radius, source, scale, subType, color)
	Game_Fart(self, pos, radius or 85, source, scale or 1, subType or 0, color or Color.Default)
end

-- void Game:BombDamage(Vector Position, float Damage, float Radius, boolean LineCheck = true, Entity Source = nil, BitSet128 TearFlags = TearFlags.TEAR_NORMAL, int DamageFlags = DamageFlag.DAMAGE_EXPLOSION, boolean DamageSource = false)
local Game_BombDamage = META0.BombDamage
function META:BombDamage(pos, damage, radius, lineCheck, source, tearFlags, damageFlags, damageSource)
	Game_BombDamage(self, pos, damage, radius, lineCheck ~= false, source, tobitset128(tearFlags or TearFlags.TEAR_NORMAL), damageFlags or DamageFlag.DAMAGE_EXPLOSION, damageSource)
end

-- void	Game:BombExplosionEffects(Vector Position, float Damage, BitSet128 TearFlags = TearFlags.TEAR_NORMAL, Color Color = Color.Default, Entity Source = nil, float RadiusMult = 1, boolean LineCheck = true, boolean DamageSource = false, int DamageFlags = DamageFlag.DAMAGE_EXPLOSION)
local Game_BombExplosionEffects = META0.BombExplosionEffects
function META:BombExplosionEffects(pos, damage, tearFlags, color, source, radiusMult, lineCheck, damageSource, damageFlags)
	Game_BombExplosionEffects(self, pos, damage, tobitset128(tearFlags or TearFlags.TEAR_NORMAL), color or Color.Default, source, radiusMult or 1, lineCheck ~= false, damageFlags or DamageFlag.DAMAGE_EXPLOSION, damageSource)
end

-- void	Game::BombTearflagEffects(Vector Position, float Radius, int TearFlags, Entity Source = nil, float RadiusMult = 1)
local Game_BombTearflagEffects = META0.BombTearflagEffects
function META:BombTearflagEffects(pos, radius, tearFlags, source, radiusMult)
	Game_BombTearflagEffects(self, pos, radius, tearFlags, source, radiusMult or 1)
end

-- void Game:SpawnParticles(Vector Pos, EffectVariant ParticleType, int NumParticles, float Speed, Color Color = Color.Default, float Height = 100000, int SubType = 0)
local Game_SpawnParticles = META0.SpawnParticles
function META:SpawnParticles(pos, variant, num, speed, color, height, subType)
	Game_SpawnParticles(self, pos, variant, num, speed, color or Color.Default, height or 100000, subType or 0)
end

-- void Game:StartRoomTransition(int RoomIndex, Direction Direction, RoomTransitionAnim Animation = RoomTransitionAnim.WALK, EntityPlayer Player = nil, int Dimension = -1)
local Game_StartRoomTransition = META0.StartRoomTransition
function META:StartRoomTransition(roomIdx, dir, anim, player, dim)
	Game_StartRoomTransition(self, roomIdx, dir, anim or RoomTransitionAnim.WALK, player, dim or -1)
end

-- void	Game:UpdateStrangeAttractor(Vector Position, float Force = 10, float Radius = 250)
local Game_UpdateStrangeAttractor = META0.UpdateStrangeAttractor
function META:UpdateStrangeAttractor(pos, force, radius)
	Game_UpdateStrangeAttractor(self, pos, force or 10, radius or 250)
end

-- void Game:ShowHallucination(int FrameCount, BackdropType Backdrop = BackdropType.NUM_BACKDROPS)
local Game_ShowHallucination = META0.ShowHallucination
function META:ShowHallucination(frameCount, backdrop)
	Game_ShowHallucination(self, frameCount, backdrop or BackdropType.NUM_BACKDROPS)
end

-- void Game:Fadein(float Speed, bool ShowIcon = true, const Color & FadeColor = KAGE::Graphics::Colors.Black)
local Game_Fadein = META0.Fadein
function META:Fadein(speed, show_icon, color)
	Game_Fadein( self, speed, show_icon or true, color or KColor(0,0,0,255) )
end

-- void Game:Fadeout(float Speed, eFadeoutTarget Target, const Color & FadeColor = KAGE::Graphics::Colors.Black)
local Game_Fadeout = META0.Fadeout
function META:Fadeout(speed, target, color)
	Game_Fadeout( self, speed, target, color or KColor(0,0,0,255) )
end

EndClass()

---------------------------------------------------------
BeginClass(Level)

-- const RoomDescriptor Level:GetRoomByIdx(int RoomIdx, int Dimension = -1)
-- * Dimension: ID of the dimension to get the room from
--      -1: Current dimension
--      0: Main dimension
--      1: Secondary dimension, used by Downpour mirror dimension and Mines escape sequence
--      2: Death Certificate dimension
local Level_GetRoomByIdx = META0.GetRoomByIdx
function META:GetRoomByIdx(idx, dim)
	return Level_GetRoomByIdx(self, idx, dim or -1)
end

-- int Level:QueryRoomTypeIndex(RoomType RoomType, boolean Visited, RNG rng, boolean IgnoreGroup = false)
-- * IgnoreGroup: If set to true, includes rooms that do not have the same group ID as the current room (currently unused)
local Level_QueryRoomTypeIndex = META0.QueryRoomTypeIndex
function META:QueryRoomTypeIndex(roomType, visited, rng, ignoreGroup)
	return Level_QueryRoomTypeIndex(self, roomType, visited, rng, ignoreGroup)
end

-- void Level:ChangeRoom(int RoomIndex, int Dimension = -1)
local Level_ChangeRoom = META0.ChangeRoom
function META:ChangeRoom(idx, dim)
	Level_ChangeRoom(self, idx, dim or -1)
end

EndClass()

BeginClass(Sprite)

-- void Sprite:SetFrame(int Frame)
-- void Sprite:SetFrame(string Anim, int Frame)
local Sprite_SetFrame = META0.SetFrame
local Sprite_SetFrame_1 = META0.SetFrame_1
function META:SetFrame(a, b)
	if type(a) == "number" then
		Sprite_SetFrame_1(self, a)
	else
		Sprite_SetFrame(self, a, b)
	end
end

-- void Sprite:Render(Vector Pos, Vector TopLeftClamp = Vector.Zero, Vector BottomRightClamp = Vector.Zero)
local Sprite_Render = META0.Render
function META:Render(pos, tl, br)
	Sprite_Render(self, pos, tl or Vector.Zero, br or Vector.Zero)
end

-- void Sprite:RenderLayer(int LayerId, Vector Pos, Vector TopLeftClamp = Vector.Zero, Vector BottomRightClamp = Vector.Zero)
local Sprite_RenderLayer = META0.RenderLayer
function META:RenderLayer(layer, pos, tl, br)
	Sprite_RenderLayer(self, layer, pos, tl or Vector.Zero, br or Vector.Zero)
end

-- boolean Sprite:IsFinished(string Anim = "")
local Sprite_IsFinished = META0.IsFinished
function META:IsFinished(anim)
	return Sprite_IsFinished(self, anim or "")
end

-- boolean Sprite:IsPlaying(string Anim = "")
local Sprite_IsPlaying = META0.IsPlaying
function META:IsPlaying(anim)
	return Sprite_IsPlaying(self, anim or "")
end

-- boolean Sprite:IsOverlayFinished(string Anim = "")
local Sprite_IsOverlayFinished = META0.IsOverlayFinished
function META:IsOverlayFinished(anim)
	return Sprite_IsOverlayFinished(self, anim or "")
end

-- boolean Sprite:IsOverlayPlaying(string Anim = "")
local Sprite_IsOverlayPlaying = META0.IsOverlayPlaying
function META:IsOverlayPlaying(anim)
	return Sprite_IsOverlayPlaying(self, anim or "")
end

-- void Sprite:Load(string Path, boolean LoadGraphics = true)
local Sprite_Load = META0.Load
function META:Load(path, loadGraphics)
	Sprite_Load(self, path, loadGraphics ~= false)
end

-- void Sprite:PlayRandom(int Seed = Random())
local Sprite_PlayRandom = META0.PlayRandom
function META:PlayRandom(seed)
	Sprite_PlayRandom(self, seed or Random())
end

-- void Sprite:SetAnimation(string Anim, boolean Reset = true)
local Sprite_SetAnimation = META0.SetAnimation
function META:SetAnimation(anim, reset)
	Sprite_SetAnimation(self, anim, reset ~= false)
end

-- void Sprite:SetOverlayAnimation(string Anim, boolean Reset = true)
local Sprite_SetOverlayAnimation = META0.SetOverlayAnimation
function META:SetOverlayAnimation(anim, reset)
	Sprite_SetOverlayAnimation(self, anim, reset ~= false)
end

-- KColor Sprite:GetTexel(Vector SamplePos, Vector RenderPos, float AlphaThreshold = 0.01, int LayerId  = -1)
local Sprite_GetTexel = META0.GetTexel
function META:GetTexel(samplePos, renderPos, alphaThreshold, layerId)
	return Sprite_GetTexel(self, samplePos, renderPos, alphaThreshold or 0.01, layerId or -1)
end

EndClass()

---------------------------------------------------------
BeginClass(EntityTear)

-- void EntityTear:AddTearFlags(BitSet128 Flags)
--	Adds the specified tear flags
function META:AddTearFlags(f)
	self.TearFlags = self.TearFlags | f
end

-- void EntityTear:ClearTearFlags(BitSet128 Flags)
--	Removes the specified tear flags
function META:ClearTearFlags(f)
	self.TearFlags = self.TearFlags & ~f
end

-- boolean EntityTear:HasTearFlags(BitSet128 Flags)
--	Returns true if we have any of the specified tear flags
function META:HasTearFlags(f)
	return self.TearFlags & f ~= TearFlags.TEAR_NORMAL
end

EndClass()

---------------------------------------------------------
BeginClass(EntityBomb)

-- void EntityBomb:AddTearFlags(BitSet128 Flags)
--	Adds the specified tear flags
function META:AddTearFlags(f)
	self.Flags = self.Flags | f
end

-- void EntityBomb:ClearTearFlags(BitSet128 Flags)
--	Removes the specified tear flags
function META:ClearTearFlags(f)
	self.Flags = self.Flags & ~f
end

-- boolean EntityBomb:HasTearFlags(BitSet128 Flags)
--	Returns true if we have any of the specified tear flags
function META:HasTearFlags(f)
	return self.Flags & f ~= TearFlags.TEAR_NORMAL
end

EndClass()

---------------------------------------------------------
BeginClass(EntityKnife)

-- void EntityKnife:AddTearFlags(BitSet128 Flags)
--	Adds the specified tear flags
function META:AddTearFlags(f)
	self.TearFlags = self.TearFlags | f
end

-- void EntityKnife:ClearTearFlags(BitSet128 Flags)
--	Removes the specified tear flags
function META:ClearTearFlags(f)
	self.TearFlags = self.TearFlags & ~f
end

-- boolean EntityKnife:HasTearFlags(BitSet128 Flags)
--	Returns true if we have any of the specified tear flags
function META:HasTearFlags(f)
	return self.TearFlags & f ~= TearFlags.TEAR_NORMAL
end

EndClass()

---------------------------------------------------------
BeginClass(EntityLaser)

-- void EntityLaser:AddTearFlags(BitSet128 Flags)
--	Adds the specified tear flags
function META:AddTearFlags(f)
	self.TearFlags = self.TearFlags | f
end

-- void EntityLaser:ClearTearFlags(BitSet128 Flags)
--	Removes the specified tear flags
function META:ClearTearFlags(f)
	self.TearFlags = self.TearFlags & ~f
end

-- boolean EntityLaser:HasTearFlags(BitSet128 Flags)
--	Returns true if we have any of the specified tear flags
function META:HasTearFlags(f)
	return self.TearFlags & f ~= TearFlags.TEAR_NORMAL
end

EndClass()

---------------------------------------------------------
BeginClass(EntityProjectile)

-- void EntityProjectile:ClearProjectileFlags(int Flags)
--	Removes the specified projectile flags
function META:ClearProjectileFlags(f)
	self.ProjectileFlags = self.ProjectileFlags & ~f
end

-- boolean EntityProjectile:HasProjectileFlags(int Flags)
--	Returns true if we have any of the specified projectile flags
function META:HasProjectileFlags(f)
	return self.ProjectileFlags & f ~= 0
end

EndClass()

---------------------------------------------------------
BeginClass(EntityFamiliar)

-- void	EntityFamiliar:PickEnemyTarget(float MaxDistance, int FrameInterval = 13, int Flags = 0, Vector ConeDir = Vector.Zero, float ConeAngle = 15)
-- * Flags: A combination of the following flags (none of these are set by default)
--       1: Allow switching to a better target even if we already have one
--       2: Don't prioritize enemies that are close to our owner
--       4: Prioritize enemies with higher HP
--       8: Prioritize enemies with lower HP
--       16: Give lower priority to our current target (this makes us more likely to switch between targets)
-- * ConeDir: If ~= Vector.Zero, searches for targets in a cone pointing in this direction
-- * ConeAngle: If ConeDir ~= Vector.Zero, sets the half angle of the search cone in degrees (45 results in a search angle of 90 degrees)
local Entity_Familiar_PickEnemyTarget = META0.PickEnemyTarget
function META:PickEnemyTarget(maxDist, frameInterval, flags, coneDir, coneAngle)
	Entity_Familiar_PickEnemyTarget(self, maxDist, frameInterval or 13, flags or 0, coneDir or Vector(0, 0), coneAngle or 15)
end

EndClass()

---------------------------------------------------------
BeginClass(EntityNPC)

-- void	EntityNPC:MakeChampion(int Seed, ChampionColor ChampionColorIdx = -1, boolean Init = false)
-- * ChampionColorIdx: The type of champion to turn this enemy into (-1 results in a random champion type)
-- * Init: Set to true when called while initializing the enemy, false otherwise
local Entity_NPC_MakeChampion = META0.MakeChampion
function META:MakeChampion(seed, championType, init)
	Entity_NPC_MakeChampion(self, seed, championType or -1, init)
end
		
EndClass()

---------------------------------------------------------
BeginClass(EntityPickup)

-- boolean EntityPickup:TryOpenChest(EntityPlayer Player = nil)
-- * Player: The player that opened this chest
local Entity_Pickup_TryOpenChest = META0.TryOpenChest
function META:TryOpenChest(player)
	return Entity_Pickup_TryOpenChest(self, player)
end

-- void	EntityPickup::Morph(EntityType Type, int Variant, int SubType, boolean KeepPrice = false, boolean KeepSeed = false, boolean IgnoreModifiers = false)
-- * KeepSeed: If set to true, keeps the initial RNG seed of the pickup instead of rerolling it
-- * IgnoreModifiers: If set to true, ignores item effects that might turn this pickup into something other than the specificed variant and subtype

EndClass()
 
---------------------------------------------------------
BeginClass(EntityPlayer)

-- void	EntityPlayer:AddCollectible(CollectibleType Type, int Charge = 0, boolean AddConsumables = true, ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY, int VarData = 0)
-- * Slot: Sets the active slot this collectible should be added to
-- * VarData: Sets the variable data for this collectible (this is used to store extra data for some active items like the number of uses for Jar of Wisps)
local Entity_Player_AddCollectible = META0.AddCollectible
function META:AddCollectible(id, charge, addConsumables, activeSlot, varData, pool)
	Entity_Player_AddCollectible(self, id, charge or 0, addConsumables or addConsumables == nil, activeSlot or 0, varData or 0, pool or 0)
end

-- void	EntityPlayer:RemoveCollectible(CollectibleType Type, bool IgnoreModifiers = false, ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY, bool RemoveFromPlayerForm = true)
-- * IgnoreModifiers: Ignores collectible effects granted by other items (i.e. Void)
-- * Slot: Sets the active slot this collectible should be removed from
-- * RemoveFromPlayerForm: If successfully removed and part of a transformation, decrease that transformation's counter by 1
local Entity_Player_RemoveCollectible = META0.RemoveCollectible
function META:RemoveCollectible(id, ignoreModifiers, activeSlot, removeFromPlayerForm)
	Entity_Player_RemoveCollectible(self, id, ignoreModifiers, activeSlot or 0, removeFromPlayerForm ~= false)
end

-- void	EntityPlayer:AddTrinket(TrinketType Type, boolean AddConsumables = true)
local Entity_Player_AddTrinket = META0.AddTrinket
function META:AddTrinket(id, addConsumables)
	Entity_Player_AddTrinket(self, id, addConsumables or addConsumables == nil)
end

-- CollectibleType EntityPlayer:GetActiveItem(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_GetActiveItem = META0.GetActiveItem
function META:GetActiveItem(id)
	return Entity_Player_GetActiveItem(self, id or 0)
end

-- int EntityPlayer:GetActiveCharge(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_GetActiveCharge = META0.GetActiveCharge
function META:GetActiveCharge(id)
	return Entity_Player_GetActiveCharge(self, id or 0)
end

-- int EntityPlayer:GetBatteryCharge(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_GetBatteryCharge = META0.GetBatteryCharge
function META:GetBatteryCharge(id)
	return Entity_Player_GetBatteryCharge(self, id or 0)
end

-- int EntityPlayer:GetActiveSubCharge(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_GetActiveSubCharge = META0.GetActiveSubCharge
function META:GetActiveSubCharge(id)
	return Entity_Player_GetActiveSubCharge(self, id or 0)
end

-- void EntityPlayer:SetActiveCharge(int Charge, ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_SetActiveCharge = META0.SetActiveCharge
function META:SetActiveCharge(charge, id)
	Entity_Player_SetActiveCharge(self, charge, id or 0)
end

-- void EntityPlayer:DischargeActiveItem(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_DischargeActiveItem = META0.DischargeActiveItem
function META:DischargeActiveItem(id)
	Entity_Player_DischargeActiveItem(self, id or 0)
end

-- boolean EntityPlayer:NeedsCharge(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY)
local Entity_Player_NeedsCharge = META0.NeedsCharge
function META:NeedsCharge(id)
	return Entity_Player_NeedsCharge(self, id or 0)
end

-- boolean EntityPlayer:FullCharge(ActiveSlot Slot = ActiveSlot.SLOT_PRIMARY, boolean Force = false)
-- * Force: If set, items will always be charged even if they normally cannot be recharged by batteries
local Entity_Player_FullCharge = META0.FullCharge
function META:FullCharge(id, force)
	return Entity_Player_FullCharge(self, id or 0, force) ~= 0
end

-- void EntityPlayer:CheckFamiliar(int FamiliarVariant, int TargetCount, RNG rng, ItemConfig::Item SourceItem = nil, int FamiliarSubType = -1)
-- * SourceItem: The item this type of familiar was created by
-- * FamiliarSubType: The subtype of the familiar to check (-1 matches any subtype)
local Entity_Player_CheckFamiliar = META0.CheckFamiliar
function META:CheckFamiliar(variant, count, rng, sourceItem, subType)
	Entity_Player_CheckFamiliar(self, variant, count, rng, sourceItem, subType or -1)
end

-- void	EntityPlayer:UseActiveItem(CollectibleType Item, UseFlag UseFlags = 0, ActiveSlot Slot = -1, int CustomVarData = 0)
--   or
-- void	EntityPlayer:UseActiveItem(CollectibleType Item, boolean ShowAnim = false, boolean KeepActiveItem = false, boolean AllowNonMainPlayer = true, boolean ToAddCostume = false, ActiveSlot Slot = -1, int CustomVarData = 0)
-- * Slot: The active slot this item was used from (set to -1 if this item wasn't triggered by any active slot)
local Entity_Player_UseActiveItem = META0.UseActiveItem
function META:UseActiveItem(item, showAnim, keepActive, allowNonMain, addCostume, activeSlot, customVarData)
	if type(showAnim) == "number" then
		-- Repentance version
		local useFlags = showAnim
		activeSlot = keepActive
		customVarData = allowNonMain
		
		Entity_Player_UseActiveItem(self, item, useFlags, activeSlot or -1, customVarData or 0)
	else
		-- AB+ backwards compatibility
		local useFlags = 0
		if showAnim == false then useFlags = useFlags + 1 end
		if keepActive == false then useFlags = useFlags + 16 end
		if allowNonMain then useFlags = useFlags + 8 end
		if addCostume == false then useFlags = useFlags + 2 end
		if customVarData then useFlags = useFlags + 1024 end
		
		Entity_Player_UseActiveItem(self, item, useFlags, activeSlot or -1, customVarData or 0)
	end
end

-- void	EntityPlayer:UseCard(Card ID, UseFlag UseFlags = 0)
local Entity_Player_UseCard = META0.UseCard
function META:UseCard(id, useFlags)
	Entity_Player_UseCard(self, id, useFlags or 0)
end

-- void	EntityPlayer:UsePill(PillEffect ID, PillColor PillColor, UseFlag UseFlags = 0)
local Entity_Player_UsePill = META0.UsePill
function META:UsePill(id, color, useFlags)
	Entity_Player_UsePill(self, id, color, useFlags or 0)
end

-- boolean EntityPlayer:HasInvincibility(DamageFlag Flags = 0)
local Entity_Player_HasInvincibility = META0.HasInvincibility
function META:HasInvincibility(damageFlags)
	return Entity_Player_HasInvincibility(self, damageFlags or 0)
end

-- MultiShotParams EntityPlayer:GetMultiShotParams(WeaponType WeaponType = WeaponType.WEAPON_TEARS)
local Entity_Player_GetMultiShotParams = META0.GetMultiShotParams
function META:GetMultiShotParams(weaponType)
	return Entity_Player_GetMultiShotParams(self, weaponType or 1)
end

-- boolean EntityPlayer:CanAddCollectible(CollectibleType Type = CollectibleType.COLLECTIBLE_NULL)
local Entity_Player_CanAddCollectible = META0.CanAddCollectible
function META:CanAddCollectible(item)
	return Entity_Player_CanAddCollectible(self, item or 0)
end

-- EntityBomb EntityPlayer:FireBomb(Vector Position, Vector Velocity, Entity Source = nil)
local Entity_Player_FireBomb = META0.FireBomb
function META:FireBomb(pos, vel, source)
	return Entity_Player_FireBomb(self, pos, vel, source)
end

-- EntityLaser EntityPlayer:FireBrimstone(Vector Position, Entity Source = nil, float DamageMultiplier = 1)
local Entity_Player_FireBrimstone = META0.FireBrimstone
function META:FireBrimstone(pos, source, mul)
	return Entity_Player_FireBrimstone(self, pos, source, mul or 1)
end

-- EntityKnife EntityPlayer:FireKnife(Entity Parent, float RotationOffset = 0, boolean CantOverwrite = false, int SubType = 0, int Variant = 0)
local Entity_Player_FireKnife = META0.FireKnife
function META:FireKnife(parent, rotationOffset, cantOverwrite, subType, variant)
	return Entity_Player_FireKnife(self, parent, variant or 0, rotationOffset or 0, cantOverwrite, subType or 0)
end

-- EntityTear EntityPlayer:FireTear(Vector Position, Vector Velocity, boolean CanBeEye = true, boolean NoTractorBeam = false, boolean CanTriggerStreakEnd = true, Entity Source = nil, float DamageMultiplier = 1)
local Entity_Player_FireTear = META0.FireTear
function META:FireTear(pos, vel, canBeEye, noTractorBeam, canTriggerStreakEnd, source, mul)
	local flags = 0
	if canBeEye == false then flags = flags + 1 end
	if noTractorBeam then flags = flags + 2 end
	if canTriggerStreakEnd == false then flags = flags + 4 end
	return Entity_Player_FireTear(self, pos, vel, flags, source, mul or 1)
end

-- EntityLaser EntityPlayer:FireTechLaser(Vector Position, LaserOffset OffsetID, Vector Direction, boolean LeftEye, boolean OneHit = false, Entity Source = nil, float DamageMultiplier = 1)
local Entity_Player_FireTechLaser = META0.FireTechLaser
function META:FireTechLaser(pos, offsetId, dir, leftEye, oneHit, source, mul)
	return Entity_Player_FireTechLaser(self, pos, offsetId, dir, leftEye, oneHit, source, mul or 1)
end

-- EntityLaser EntityPlayer:FireTechXLaser(Vector Position, Vector Direction, float Radius, Entity Source = nil, float DamageMultiplier = 1)
local Entity_Player_FireTechXLaser = META0.FireTechXLaser
function META:FireTechXLaser(pos, dir, radius, source, mul)
	return Entity_Player_FireTechXLaser(self, pos, dir, radius, source, mul or 1)
end

-- void EntityPlayer:QueueItem(ItemConfig::Item Item, int Charge = 0, boolean Touched = false, bool Golden = false, int VarData = 0)
local Entity_Player_QueueItem = META0.QueueItem
function META:QueueItem(item, charge, touched, golden, varData)
	local flags = 0
	if touched then flags = flags + 1 end
	if golden then flags = flags + 2 end
	Entity_Player_QueueItem(self, item, charge or 0, flags, varData or 0)
end

-- TearParams EntityPlayer:GetTearHitParams(WeaponType WeaponType, float DamageScale = 1, int TearDisplacement = 1, Entity Source = nil)
local Entity_Player_GetTearHitParams = META0.GetTearHitParams
function META:GetTearHitParams(weapon, scale, disp, src)
	return Entity_Player_GetTearHitParams(self, weapon, scale or 1, disp or 1, src)
end

-- void EntityPlayer:AnimateCard(Card ID, string AnimName = "Pickup")
local Entity_Player_AnimateCard = META0.AnimateCard
function META:AnimateCard(id, anim)
	return Entity_Player_AnimateCard(self, id, anim or "Pickup")
end

-- void EntityPlayer:AnimatePill(PillColor ID, string AnimName = "Pickup")
local Entity_Player_AnimatePill = META0.AnimatePill
function META:AnimatePill(id, anim)
	return Entity_Player_AnimatePill(self, id, anim or "Pickup")
end

-- void EntityPlayer:AnimateTrinket(TrinketType ID, string AnimName = "Pickup", string SpriteAnimName = "PlayerPickupSparkle")
local Entity_Player_AnimateTrinket = META0.AnimateTrinket
function META:AnimateTrinket(id, anim, spriteAnim)
	return Entity_Player_AnimateTrinket(self, id, anim or "Pickup", spriteAnim or "PlayerPickupSparkle")
end

-- void EntityPlayer:AnimateCollectible(CollectibleType ID, string AnimName = "Pickup", string SpriteAnimName = "PlayerPickupSparkle")
local Entity_Player_AnimateCollectible = META0.AnimateCollectible
function META:AnimateCollectible(id, anim, spriteAnim)
	return Entity_Player_AnimateCollectible(self, id, anim or "Pickup", spriteAnim or "PlayerPickupSparkle")
end

-- void EntityPlayer:AnimatePickup(Sprite Sprite, boolean HideShadow = false, string AnimName = "Pickup")
local Entity_Player_AnimatePickup = META0.AnimatePickup
function META:AnimatePickup(sprite, hideShadow, anim)
	return Entity_Player_AnimatePickup(self, sprite, hideShadow, anim or "Pickup")
end

-- boolean EntityPlayer:HasCollectible(CollectibleType Type, boolean IgnoreModifiers = false)
-- * IgnoreModifiers: If set to true, only counts collectibles the player actually owns and ignores effects granted by items like Zodiac, 3 Dollar Bill and Lemegeton

-- int EntityPlayer:GetCollectibleNum(CollectibleType Type, boolean IgnoreModifiers = false)
-- * IgnoreModifiers: Same as above

-- boolean EntityPlayer:HasTrinket(TrinketType Type, boolean IgnoreModifiers = false)
-- * IgnoreModifiers: If set to true, only counts trinkets the player actually holds and ignores effects granted by other items

-- Backwards compatibility
META.GetMaxPoketItems = META0.GetMaxPocketItems
META.DropPoketItem = META0.DropPocketItem

-- void EntityPlayer:ChangePlayerType(PlayerType Type)

-- void EntityPlayer:AddBrokenHearts(int Num)
-- int EntityPlayer:GetBrokenHearts()
-- void EntityPlayer:AddRottenHearts(int Num)
-- int EntityPlayer:GetRottenHearts()

-- void EntityPlayer:AddSoulCharge(int Num)
-- void EntityPlayer:SetSoulCharge(int Num)
-- int EntityPlayer:GetSoulCharge()
-- int EntityPlayer:GetEffectiveSoulCharge()

-- void EntityPlayer:AddBloodCharge(int Num)
-- void EntityPlayer:SetBloodCharge(int Num)
-- int EntityPlayer:GetBloodCharge()
-- int EntityPlayer:GetEffectiveBloodCharge()

-- boolean EntityPlayer:CanPickRottenHearts()

-- EntityPlayer EntityPlayer:GetMainTwin()
-- EntityPlayer EntityPlayer:GetOtherTwin()

-- boolean EntityPlayer:TryHoldEntity(Entity Ent)
-- Entity EntityPlayer:ThrowHeldEntity(Vector Velocity)

-- EntityFamiliar EntityPlayer:AddFriendlyDip(int Subtype, Vector Position)
-- EntityFamiliar EntityPlayer:AddWisp(int Subtype, Vector Position, boolean AdjustOrbitLayer = false, boolean DontUpdate = false)
-- EntityFamiliar EntityPlayer:AddItemWisp(int Subtype, Vector Position, boolean AdjustOrbitLayer = false)
-- EntityFamiliar EntityPlayer:AddSwarmFlyOrbital(Vector Position)

-- int EntityPlayer:GetNumGigaBombs()
-- void EntityPlayer:AddGigaBombs(int Num)

-- CollectibleType EntityPlayer:GetModelingClayEffect()
-- void EntityPlayer:AddCurseMistEffect()
-- void EntityPlayer:RemoveCurseMistEffect()
-- boolean EntityPlayer:HasCurseMistEffect()

-- boolean EntityPlayer:IsCoopGhost()

-- EntityFamiliar EntityPlayer:AddMinisaac(Vector Position, boolean PlayAnim = true)
local Entity_Player_AddMinisaac = META0.AddMinisaac
function META:AddMinisaac(pos, playAnim)
	return Entity_Player_AddMinisaac(self, pos, playAnim ~= false)
end

-- EntityFamiliar EntityPlayer:ThrowFriendlyDip(int Subtype, Vector Position, Vector Target = Vector.Zero)
local Entity_Player_ThrowFriendlyDip = META0.ThrowFriendlyDip
function META:ThrowFriendlyDip(subtype, pos, target)
	return Entity_Player_ThrowFriendlyDip(self, subtype, pos, target)
end

-- void EntityPlayer:TriggerBookOfVirtues(CollectibleType Type = CollectibleType.COLLECTIBLE_NULL, int Charge = 0)
local Entity_Player_TriggerBookOfVirtues = META0.TriggerBookOfVirtues
function META:TriggerBookOfVirtues(id, charge)
	Entity_Player_TriggerBookOfVirtues(self, id or 0, charge or 0)
end

-- void EntityPlayer:SetPocketActiveItem(CollectibleType Type, ActiveSlot Slot = ActiveSlot.SLOT_POCKET, boolean KeepInPools = false)
local Entity_Player_SetPocketActiveItem = META0.SetPocketActiveItem
function META:SetPocketActiveItem(id, slot, keep)
	Entity_Player_SetPocketActiveItem(self, id, slot or ActiveSlot.SLOT_POCKET, keep)
end

EndClass()

---------------------------------------------------------

Game = Game_0
Game_0 = nil

if not _LUADEBUG then
	debug = nil
	arg = nil
	dofile = nil
	loadfile = nil
end

-- Custom mod logic integrated into the game (this one's for two treasures in a treasure room, tested for a long time with no desyncs at all)
local function onNewRoom()
    local room = Game():GetRoom()
    local roomType = room:GetType()

    -- Check if it's a treasure room
    if roomType == RoomType.ROOM_TREASURE then
        -- Only spawn additional item on first visit
        if Game():GetLevel():GetCurrentRoomDesc().VisitedCount < 2 then
            -- Find if there's already an item present
            local entities = Isaac.GetRoomEntities()
            for i = 1, #entities do
                local entity = entities[i]
                if entity.Type == 5 and entity.Variant == 100 then
				-- Get item from treasure room pool
                    local itemPool = Game():GetItemPool()
                    local newItem = itemPool:GetCollectible(ItemPoolType.POOL_TREASURE, true, entity.InitSeed)
                    -- Spawn second item slightly offset from the first (still has a change to be trapped lol
					-- better write some code to destroy anything that would prevent the item from spawning, but
					-- not to make desyncs happen this is just enough.
                    Isaac.Spawn(5, 100, newItem, entity.Position + Vector(100, 0), Vector(0,0), nil)
                    break
                end
            end
        end
    end
end

-- Register the callback manually
Isaac.AddCallback(nil, ModCallbacks.MC_POST_NEW_ROOM, onNewRoom)


--Descriptions
--These for for ab
local descriptionsOfItems = {
	{"1", "The Sad Onion", "↑ {{Tears}} +0.7 Tears"}, -- The Sad Onion
	{"2", "The Inner Eye", "↓ {{Tears}} x0.48 Tears multiplier#↓ {{Tears}} +3 Tear delay#Isaac shoots 3 tears at once"}, -- The Inner Eye
	{"3", "Spoon Bender", "Homing tears"}, -- Spoon Bender
	{"4", "Cricket's Head", "↑ {{Damage}} +0.5 Damage#↑ {{Damage}} x1.5 Damage multiplier"}, -- Cricket's Head
	{"5", "My Reflection", "↑ {{Range}} +1.5 Range#↑ +1 Tear height#↑ {{Shotspeed}} +0.6 Shot speed#Tears get a boomerang effect"}, -- My Reflection
	{"6", "Number One", "↑ {{Tears}} +1.5 Tears#↑ +0.76 Tear height#↓ {{Range}} -17.62 Range"}, -- Number One
	{"7", "Blood of the Martyr", "↑ {{Damage}} +1 Damage"}, -- Blood of the Martyr
	{"8", "Brother Bobby", "Shoots normal tears#Deals 3.5 damage per tear"}, -- Brother Bobby
	{"9", "Skatole", "All fly enemies are friendly"}, -- Skatole
	{"10", "Halo of Flies", "+2 Fly orbitals#Blocks enemy projectiles"}, -- Halo of Flies
	{"11", "1up!", "↑ +1 Life#Isaac respawns with full health on death"}, -- 1up!
	{"12", "Magic Mushroom", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +0.3 Damage#↑ {{Damage}} x1.5 Damage multiplier#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height#Size up#{{HealingRed}} Full health"}, -- Magic Mushroom
	{"13", "The Virus", "↓ {{Speed}} -0.1 Speed#{{Poison}} Touching enemies poisons them#{{BlackHeart}} Poisoned enemies can drop Black Hearts"}, -- The Virus
	{"14", "Roid Rage", "↑ {{Speed}} +0.6 Speed#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- Roid Rage
	{"15", "<3", "↑ {{Heart}} +1 Health#{{HealingRed}} Full health"}, -- <3
	{"16", "Raw Liver", "↑ {{Heart}} +2 Health#{{HealingRed}} Full health"}, -- Raw Liver
	{"17", "Skeleton Key", "{{Key}} +99 Keys"}, -- Skeleton Key
	{"18", "A Dollar", "{{Coin}} +99 Coins"}, -- A Dollar
	{"19", "Boom!", "{{Bomb}} +10 Bombs"}, -- Boom!
	{"20", "Transcendence", "Flight"}, -- Transcendence
	{"21", "The Compass", "Reveals icons on the map#Does not reveal the layout of the map"}, -- The Compass
	{"22", "Lunch", "↑ {{Heart}} +1 Health"}, -- Lunch
	{"23", "Dinner", "↑ {{Heart}} +1 Health"}, -- Dinner
	{"24", "Dessert", "↑ {{Heart}} +1 Health"}, -- Dessert
	{"25", "Breakfast", "↑ {{Heart}} +1 Health"}, -- Breakfast
	{"26", "Rotten Meat", "↑ {{Heart}} +1 Health"}, -- Rotten Meat
	{"27", "Wooden Spoon", "↑ {{Speed}} +0.3 Speed"}, -- Wooden Spoon
	{"28", "The Belt", "↑ {{Speed}} +0.3 Speed"}, -- The Belt
	{"29", "Mom's Underwear", "↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- Mom's Underwear
	{"30", "Mom's Heels", "↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- Mom's Heels
	{"31", "Mom's Lipstick", "↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- Mom's Lipstick
	{"32", "Wire Coat Hanger", "↑ {{Tears}} +0.7 Tears"}, -- Wire Coat Hanger
	{"33", "The Bible", "{{Timer}} Flight for the room#{{MomsHeart}} Kills Mom's Foot and Mom's Heart instantly#{{Warning}} Kills Isaac when used on Satan"}, -- The Bible
	{"34", "The Book of Belial", "{{AngelDevilChance}} +12.5% Devil/Angel Room chance while held#{{Timer}} Receive for the room:#↑ {{Damage}} +2 Damage"}, -- The Book of Belial
	{"35", "The Necronomicon", "Deals 40 damage to all enemies in the room"}, -- The Necronomicon
	{"36", "The Poop", "Spawns one poop and knocks back enemies#Can be placed next to a pit and destroyed with a bomb to make a bridge"}, -- The Poop
	{"37", "Mr. Boom", "Drops a large bomb below Isaac which deals 110 damage"}, -- Mr. Boom
	{"38", "Tammy's Head", "Shoots 10 tears in a circle around Isaac#The tears copy Isaac's tear effects, plus 25 damage"}, -- Tammy's Head
	{"39", "Mom's Bra", "Petrifies all enemies in the room for 4 seconds"}, -- Mom's Bra
	{"40", "Kamikaze!", "Causes an explosion at Isaac's location#It deals 40 damage"}, -- Kamikaze!
	{"41", "Mom's Pad", "{{Fear}} Fears all enemies in the room for 5 seconds"}, -- Mom's Pad
	{"42", "Bob's Rotten Head", "Using the item and firing in a direction throws the head#{{Poison}} The head explodes on impact and poisons enemies"}, -- Bob's Rotten Head
	{"43", "", "<item does not exist>"},
	{"44", "Teleport!", "Teleports Isaac into a random room, except I AM ERROR rooms"}, -- Teleport!
	{"45", "Yum Heart", "{{HealingRed}} Heals 1 heart"}, -- Yum Heart
	{"46", "Lucky Foot", "↑ {{Luck}} +1 Luck#+8% room clear reward chance#Better chance to win while gambling"}, -- Lucky Foot
	{"47", "Doctor's Remote", "{{Collectible168}} On use, start aiming a crosshair#A missile lands on the crosshair after 1.5 seconds#It deals 20x Isaac's damage"}, -- Doctor's Remote
	{"48", "Cupid's Arrow", "Piercing tears"}, -- Cupid's Arrow
	{"49", "Shoop da Whoop!", "The next shot is replaced with a beam#It deals 26x Isaac's damage over 0.9 seconds"}, -- Shoop da Whoop!
	{"50", "Steven", "↑ {{Damage}} +1 Damage"}, -- Steven
	{"51", "Pentagram", "↑ {{Damage}} +1 Damage#{{AngelDevilChance}} +10% Devil/Angel Room chance"}, -- Pentagram
	{"52", "Dr. Fetus", "↓ {{Tears}} x0.4 Tears multiplier#{{Bomb}} Isaac shoots bombs instead of tears#{{Damage}} Those bombs deal 5x Isaac's damage + 30"}, -- Dr. Fetus
	{"53", "Magneto", "Pickups are attracted to Isaac"}, -- Magneto
	{"54", "Treasure Map", "Reveals the floor layout#Does not reveal room icons"}, -- Treasure Map
	{"55", "Mom's Eye", "50% chance to shoot an extra tear backwards#{{Luck}} 100% chance at 2 luck"}, -- Mom's Eye
	{"56", "Lemon Mishap", "Spills a pool of creep#The creep deals 24 damage per second"}, -- Lemon Mishap
	{"57", "Distant Admiration", "Mid-range fly orbital#Deals 75 contact damage per second"}, -- Distant Admiration
	{"58", "Book of Shadows", "{{Timer}} Invincibility for 10 seconds"}, -- Book of Shadows
	{"59", "", "<item does not exist>"},
	{"60", "The Ladder", "Allows Isaac to cross 1-tile gaps"}, -- The Ladder
	{"61", "", "<item does not exist>"},
	{"62", "Charm of the Vampire", "{{HealingRed}} Killing 13 enemies heals half a heart"}, -- Charm of the Vampire
	{"63", "The Battery", "{{Battery}} Active items can be overcharged to two full charges"}, -- The Battery
	{"64", "Steam Sale", "{{Shop}} Shop items cost 50% less"}, -- Steam Sale
	{"65", "Anarchist Cookbook", "Spawns 6 Troll Bombs near the center of the room"}, -- Anarchist Cookbook
	{"66", "The Hourglass", "{{Slow}} Slows enemies down for 8 seconds"}, -- The Hourglass
	{"67", "Sister Maggy", "Shoots normal tears#Deals 3.5 damage per tear"}, -- Sister Maggy
	{"68", "Technology", "Isaac shoots lasers instead of tears"}, -- Technology
	{"69", "Chocolate Milk", "{{Chargeable}} Chargeable tears#{{Damage}} Damage scales with charge time, up to 4x#{{Tears}} Max charge time is 2.5x tear delay"}, -- Chocolate Milk
	{"70", "Growth Hormones", "↑ {{Speed}} +0.4 Speed#↑ {{Damage}} +1 Damage"}, -- Growth Hormones
	{"71", "Mini Mush", "↑ {{Speed}} +0.3 Speed#↑ +1.5 Tear height#↑ Size down#↓ {{Range}} -4.25 Range#The tear height up and range down = slight range up"}, -- Mini Mush
	{"72", "Rosary", "{{SoulHeart}} +3 Soul Hearts#{{Collectible33}} The Bible is added to all item pools"}, -- Rosary
	{"73", "Cube of Meat", "Lv1: Orbital#Lv2: Shooting orbital#Lv3: Meat Boy#Lv4: Super Meat Boy"}, -- Cube of Meat
	{"74", "A Quarter", "{{Coin}} +25 Coins"}, -- A Quarter
	{"75", "PHD", "{{HealingRed}} Heals 2 hearts#{{Pill}} Spawns 1 pill#{{Pill}} Changes bad pills into good pills#{{BloodDonationMachine}} Blood Donation Machines give more {{Coin}} coins"}, -- PHD
	{"76", "X-Ray Vision", "{{SecretRoom}} Opens all secret room entrances"}, -- X-Ray Vision
	{"77", "My Little Unicorn", "{{Timer}} Receive for 6 seconds:#↑ {{Speed}} +0.28 Speed#Invincibility#Isaac can't shoot but deals 40 contact damage per second"}, -- My Little Unicorn
	{"78", "Book of Revelations", "{{SoulHeart}} +1 Soul Heart#{{AngelDevilChance}} +17.5% Devil/Angel Room chance while held#Using the item has a high chance to replace the floor's boss with a horseman"}, -- Book of Revelations
	{"79", "The Mark", "↑ {{Speed}} +0.2 Speed#↑ {{Damage}} +1 Damage#{{SoulHeart}} +1 Soul Heart"}, -- The Mark
	{"80", "The Pact", "↑ {{Tears}} +0.7 Tears#↑ {{Damage}} +0.5 Damage#{{SoulHeart}} +2 Soul Hearts"}, -- The Pact
	{"81", "Dead Cat", "↑ +9 Lives#Isaac respawns with 1 heart container on death#{{Warning}} Sets Isaac's heart containers to 1 when picked up"}, -- Dead Cat
	{"82", "Lord of the Pit", "↑ {{Speed}} +0.3 Speed#Flight"}, -- Lord of the Pit
	{"83", "The Nail", "Upon use:#{{SoulHeart}} +1 Soul Heart#{{Timer}} Receive for the room:#↑ {{Damage}} +0.7 Damage#↓ {{Speed}} -0.18 Speed#Isaac deals 40 contact damage per second#Allows Isaac to destroy rocks by walking into them"}, -- The Nail
	{"84", "We Need To Go Deeper!", "Opens a trapdoor to the next floor#{{LadderRoom}} 10% chance to open a crawlspace trapdoor"}, -- We Need To Go Deeper!
	{"85", "Deck of Cards", "{{Card}} Spawns 1 card"}, -- Deck of Cards
	{"86", "Monstro's Tooth", "Monstro falls on an enemy and deals 120 damage#{{Warning}} Monstro falls on Isaac if the room has no enemies"}, -- Monstro's Tooth
	{"87", "Loki's Horns", "25% chance to shoot in 4 directions#{{Luck}} 100% chance at 7 luck"}, -- Loki's Horns
	{"88", "Little Chubby", "Charges forward in the direction Isaac is shooting#Deals 52.5 contact damage per second"}, -- Little Chubby
	{"89", "Spider Bite", "{{Slow}} 25% chance to shoot slowing tears#{{Luck}} 100% chance at 15 luck"}, -- Spider Bite
	{"90", "The Small Rock", "↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +1 Damage#↓ {{Speed}} -0.2 Speed"}, -- The Small Rock
	{"91", "Spelunker Hat", "Reveals the room type of adjacent rooms#{{SecretRoom}} Can reveal Secret and Super Secret Rooms"}, -- Spelunker Hat
	{"92", "Super Bandage", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#{{SoulHeart}} +2 Soul Hearts"}, -- Super Bandage
	{"93", "The Gamekid", "{{Timer}} Receive for 6.5 seconds:#Invincibility#Isaac can't shoot but deals 40 contact damage per second#{{HealingRed}} Killing 2 enemies heals half a heart#{{Fear}} Fears all enemies in the room"}, -- The Gamekid
	{"94", "Sack of Pennies", "{{Coin}} Spawns a random coin every 2 rooms"}, -- Sack of Pennies
	{"95", "Robo-Baby", "Shoots lasers#Deals 3.5 damage per shot"}, -- Robo-Baby
	{"96", "Little C.H.A.D.", "{{HalfHeart}} Spawns a half Red Heart every 3 rooms"}, -- Little C.H.A.D.
	{"97", "The Book of Sin", "Spawns a random pickup"}, -- The Book of Sin
	{"98", "The Relic", "{{SoulHeart}} Spawns 1 Soul Heart every 5-6 rooms"}, -- The Relic
	{"99", "Little Gish", "{{Slow}} Shoots slowing tears#Deals 3.5 damage per tear"}, -- Little Gish
	{"100", "Little Steven", "Shoots homing tears#Deals 3.5 damage per tear"}, -- Little Steven
	{"101", "The Halo", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +0.3 Damage#↑ {{Range}} +0.25 Range#↑ +0.5 Tear height"}, -- The Halo
	{"102", "Mom's Bottle of Pills", "{{Pill}} Spawns 1 pill"}, -- Mom's Bottle of Pills
	{"103", "The Common Cold", "{{Poison}} 25% chance to shoot poison tears#{{Luck}} 100% chance at 12 luck"}, -- The Common Cold
	{"104", "The Parasite", "Tears split in two on contact#Split tears deal half damage"}, -- The Parasite
	{"105", "The D6", "Rerolls pedestal items in the room"}, -- The D6
	{"106", "Mr. Mega", "↑ {{Bomb}} x1.83 Bomb damage#{{Bomb}} +5 Bombs"}, -- Mr. Mega
	{"107", "The Pinking Shears", "{{Timer}} Receive for the room:#Flight#Isaac's body separates from his head and attacks enemies with 82.5 contact damage per second"}, -- The Pinking Shears
	{"108", "The Wafer", "Reduces most damage taken to half a heart"}, -- The Wafer
	{"109", "Money = Power", "↑ {{Damage}} +0.04 Damage for every {{Coin}} coin Isaac has"}, -- Money = Power
	{"110", "Mom's Contacts", "↑ {{Range}} +0.25 Range#↑ +0.5 Tear height#20% chance to shoot petrifying tears#{{Luck}} 50% chance at 20 luck"}, -- Mom's Contacts
	{"111", "The Bean", "{{Poison}} Deals 5 damage to enemies nearby and poisons them#The poison deals Isaac's damage 6 times"}, -- The Bean
	{"112", "Guardian Angel", "Orbital#Speeds up all other orbitals#Blocks projectiles#Deals 105 contact damage per second"}, -- Guardian Angel
	{"113", "Demon Baby", "Shoots enemies that get close to him#Deals 3 damage per tear"}, -- Demon Baby
	{"114", "Mom's Knife", "Isaac's tears are replaced by a throwable knife#{{Damage}} The knife deals 2x Isaac's damage while held and 6x at the furthest possible distance"}, -- Mom's Knife
	{"115", "Ouija Board", "Spectral tears"}, -- Ouija Board
	{"116", "9 Volt", "{{Battery}} Automatically charges the first bar of active items#{{Battery}} Fully recharges the active item on pickup"}, -- 9 Volt
	{"117", "Dead Bird", "Taking damage spawns a bird that attacks enemies#The bird deals 4.3 contact damage per second"}, -- Dead Bird
	{"118", "Brimstone", "↓ {{Tears}} x0.33 Tears multiplier#{{Chargeable}} Isaac's tears are replaced by a chargeable blood beam#{{Damage}} It deals 13x Isaac's damage over 0.9 seconds"}, -- Brimstone
	{"119", "Blood Bag", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#{{HealingRed}} Heals 4 hearts"}, -- Blood Bag
	{"120", "Odd Mushroom (Thin)", "↑ {{Speed}} +0.3 Speed#↑ {{Tears}} +1.7 Tears#↓ {{Damage}} x0.9 Damage multiplier#↓ {{Damage}} -0.4 Damage"}, -- Odd Mushroom (Thin)
	{"121", "Odd Mushroom (Large)", "↑ {{EmptyHeart}} +1 Empty heart container#↑ {{Damage}} +0.3 Damage#↑ {{Range}} +0.25 Range#↑ +0.5 Tear height#↓ {{Speed}} -0.1 Speed"}, -- Odd Mushroom (Large)
	{"122", "Whore of Babylon", "When on half a Red Heart or less:#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +1.5 Damage"}, -- Whore of Babylon
	{"123", "Monster Manual", "{{Timer}} Spawns a random familiar for the room"}, -- Monster Manual
	{"124", "Dead Sea Scrolls", "Triggers a random active item effect"}, -- Dead Sea Scrolls
	{"125", "Bobby-Bomb", "{{Bomb}} +5 Bombs#Homing bombs"}, -- Bobby-Bomb
	{"126", "Razor Blade", "↑ {{Damage}} +1.2 Damage for the room#{{Warning}} Deals 1 heart of damage to Isaac#{{Heart}} Removes Red Hearts first"}, -- Razor Blade
	{"127", "Forget Me Now", "Rerolls and restarts the entire floor"}, -- Forget Me Now
	{"128", "Forever Alone", "Long range fly orbital#Deals 30 contact damage per second"}, -- Forever Alone
	{"129", "Bucket of Lard", "↑ {{EmptyHeart}} +2 Empty heart containers#↓ {{Speed}} -0.2 Speed#{{HealingRed}} Heals half a heart"}, -- Bucket of Lard
	{"130", "A Pony", "While held:#{{Speed}} Sets your Speed to at least 1.5#Flight#Upon use, dashes in the direction of Isaac's movement"}, -- A Pony
	{"131", "Bomb Bag", "{{Bomb}} Spawns 1 bomb pickup every 3 rooms"}, -- Bomb Bag
	{"132", "A Lump of Coal", "{{Damage}} Tears deal more damage the further they travel"}, -- A Lump of Coal
	{"133", "Guppy's Paw", "{{SoulHeart}} Converts 1 heart container into 3 Soul Hearts"}, -- Guppy's Paw
	{"134", "Guppy's Tail", "{{Chest}} 33% chance to replace the room clear reward with a chest#33% chance to spawn no room clear reward"}, -- Guppy's Tail
	{"135", "IV Bag", "{{Coin}} Hurts Isaac for half a heart and spawns 1-2 coins#{{Heart}} Removes Red Hearts first"}, -- IV Bag
	{"136", "Best Friend", "Spawns a decoy Isaac that attracts enemies and explodes after 5 seconds"}, -- Best Friend
	{"137", "Remote Detonator", "{{Bomb}} +5 Bombs#Isaac's bombs no longer explode automatically#Upon use, detonates all of Isaac's bombs at once"}, -- Remote Detonator
	{"138", "Stigmata", "↑ {{Heart}} +1 Health#↑ {{Damage}} +0.3 Damage"}, -- Stigmata
	{"139", "Mom's Purse", "{{Trinket}} Isaac can hold 2 trinkets"}, -- Mom's Purse
	{"140", "Bob's Curse", "{{Bomb}} +5 Bombs#{{Poison}} Isaac's bombs poison enemies caught in the blast"}, -- Bob's Curse
	{"141", "Pageant Boy", "{{Coin}} Spawns 7 random coins"}, -- Pageant Boy
	{"142", "Scapular", "{{SoulHeart}} Isaac gains 1 Soul Heart when damaged down to half a heart#Can only happen once per room#Exiting and re-entering the room allows the effect to trigger again"}, -- Scapular
	{"143", "Speed Ball", "↑ {{Speed}} +0.3 Speed#↑ {{Shotspeed}} +0.2 Shot speed"}, -- Speed Ball
	{"144", "Bum Friend", "{{Coin}} Picks up nearby coins#Spawns random pickups every 3-4 coins"}, -- Bum Friend
	{"145", "Guppy's Head", "Spawns 2-4 blue flies"}, -- Guppy's Head
	{"146", "Prayer Card", "{{EternalHeart}} +1 Eternal Heart"}, -- Prayer Card
	{"147", "Notched Axe", "{{Timer}} For the room, Isaac can break rocks and Secret Room walls by walking into them"}, -- Notched Axe
	{"148", "Infestation", "Taking damage spawns 1-3 blue flies"}, -- Infestation
	{"149", "Ipecac", "↑ {{Damage}} +40 Damage#↓ {{Tears}} x0.5 Tears multiplier#↓ {{Tears}} +10 Tear delay#Isaac's tears are shot in an arc#{{Poison}} The tears explode and poison enemies where they land"}, -- Ipecac
	{"150", "Tough Love", "{{Damage}} 10% chance to shoot teeth that deal 3.2x Isaac's damage#{{Luck}} 100% chance at 9 luck"}, -- Tough Love
	{"151", "The Mulligan", "Tears have a 1/6 chance to spawn a blue fly when hitting an enemy"}, -- The Mulligan
	{"152", "Technology 2", "↓ {{Tears}} x0.5 Tears multiplier#↓ {{Damage}} x0.65 Damage multiplier#Replaces Isaac's right eye tears with a continuous laser#{{Damage}} It deals 3x Isaac's damage per second"}, -- Technology 2
	{"153", "Mutant Spider", "↓ {{Tears}} x0.48 Tears multiplier#↓ {{Tears}} +3 Tear delay#Isaac shoots 4 tears at once"}, -- Mutant Spider
	{"154", "Chemical Peel", "↑ {{Damage}} +2 Damage for the left eye"}, -- Chemical Peel
	{"155", "The Peeper", "Floats around the room#Deals 17 contact damage per second"}, -- The Peeper
	{"156", "Habit", "{{Battery}} Taking damage adds 1 charge to the active item"}, -- Habit
	{"157", "Bloody Lust", "↑ {{Damage}} Taking damage grants a damage up#Applies up to 6 times per floor#Lasts for the whole floor"}, -- Bloody Lust
	{"158", "Crystal Ball", "Spawns a {{SoulHeart}} Soul Heart, {{Rune}} rune or {{Card}} card#{{Timer}} Full mapping effect for the floor (except {{SuperSecretRoom}} Super Secret Room)"}, -- Crystal Ball
	{"159", "Spirit of the Night", "Spectral tears#Flight"}, -- Spirit of the Night
	{"160", "Crack the Sky", "Spawns 5 beams of light near enemies#Each beam deals 8x Isaac's damage + 160 over 0.8 seconds"}, -- Crack the Sky
	{"161", "Ankh", "{{Player4}} Respawn as ??? (Blue Baby) on death"}, -- Ankh
	{"162", "Celtic Cross", "Taking damage has a 20% chance to make Isaac temporarily invincible#{{Luck}} 100% chance at 27 luck"}, -- Celtic Cross
	{"163", "Ghost Baby", "Shoots spectral tears#Deals 3.5 damage per tear"}, -- Ghost Baby
	{"164", "The Candle", "Throws a blue flame#It deals contact damage, blocks enemy tears, and despawns after 2 seconds"}, -- The Candle
	{"165", "Cat-o-nine-tails", "↑ {{Damage}} +1 Damage#↑ {{Shotspeed}} +0.23 Shot speed"}, -- Cat-o-nine-tails
	{"166", "D20", "Rerolls all pickups in the room"}, -- D20
	{"167", "Harlequin Baby", "Shoots two tears in a V-shaped pattern#Deals 4 damage per tear"}, -- Harlequin Baby
	{"168", "Epic Fetus", "Instead of shooting tears, aim a crosshair#A rocket lands on the crosshair after 1.5 seconds#{{Damage}} Rockets deal 20x Isaac's damage"}, -- Epic Fetus
	{"169", "Polyphemus", "↑ {{Damage}} +4 Damage#↑ {{Damage}} x2 Damage multiplier#↓ {{Tears}} x0.48 Tears multiplier#↓ {{Tears}} +3 Tear delay#Tears pierce killed enemies if there is leftover damage"}, -- Polyphemus
	{"170", "Daddy Longlegs", "Stomps on a nearby enemy every 4 seconds#Deals 40 damage per second"}, -- Daddy Longlegs
	{"171", "Spider Butt", "{{Slow}} Slows down enemies for 4 seconds#Deals 10 damage to all enemies"}, -- Spider Butt
	{"172", "Sacrificial Dagger", "Orbital#Blocks enemy shots#Deals 225 contact damage per second"}, -- Sacrificial Dagger
	{"173", "Mitre", "{{SoulHeart}} 50% chance that Red Hearts spawn as Soul Hearts instead"}, -- Mitre
	{"174", "Rainbow Baby", "Shoots random tears#Deals 3-5 damage per tear"}, -- Rainbow Baby
	{"175", "Dad's Key", "Opens all doors in the room, including {{SecretRoom}}{{SuperSecretRoom}}Secret Rooms, {{ChallengeRoom}}{{BossRushRoom}}Challenge Rooms, and the Mega Satan door"}, -- Dad's Key
	{"176", "Stem Cells", "↑ {{Heart}} +1 Health#↑ {{Shotspeed}} +0.16 Shot speed"}, -- Stem Cells
	{"177", "Portable Slot", "{{Coin}} Spend 1 coin for a chance to spawn a pickup"}, -- Portable Slot
	{"178", "Holy Water", "Taking damage spills a pool of creep#The creep deals 24 damage per second"}, -- Holy Water
	{"179", "Fate", "{{EternalHeart}} +1 Eternal Heart#Flight"}, -- Fate
	{"180", "The Black Bean", "Isaac farts when damaged#{{Poison}} The fart poisons enemies"}, -- The Black Bean
	{"181", "White Pony", "{{Speed}} Sets your Speed to at least 1.5#Flight while held#Using the item dashes in the direction of Isaac's movement, leaving behind beams of light"}, -- White Pony
	{"182", "Sacred Heart", "↑ {{Heart}} +1 Health#↑ {{Damage}} x2.3 Damage multiplier#↑ {{Damage}} +1 Damage#↑ {{Range}} +0.38 Range#↑ +0.75 Tear height#↓ {{Tears}} -0.4 Tears#↓ {{Shotspeed}} -0.25 Shot speed#{{HealingRed}} Full health#Homing tears"}, -- Sacred Heart
	{"183", "Tooth Picks", "↑ {{Tears}} +0.7 Tears#↑ {{Shotspeed}} +0.16 Shot speed"}, -- Tooth Picks
	{"184", "Holy Grail", "↑ {{Heart}} +1 Health#Flight"}, -- Holy Grail
	{"185", "Dead Dove", "Spectral tears#Flight"}, -- Dead Dove
	{"186", "Blood Rights", "Deals 40 damage to every enemy#{{Warning}} Deals 1 heart of damage to Isaac#{{Heart}} Removes Red Hearts first"}, -- Blood Rights
	{"187", "Guppy's Hairball", "Moving swings the hairball around#The ball grows when it kills an enemy#It deals more damage the bigger it is"}, -- Guppy's Hairball
	{"188", "Abel", "Mirrors Isaac's movement#Shoots towards Isaac#Deals 3.5 damage per tear"}, -- Abel
	{"189", "SMB Super Fan", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.2 Speed#↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +0.3 Damage#↑ {{Range}} +0.5 Range#↑ +1 Tear height#{{HealingRed}} Full health"}, -- SMB Super Fan
	{"190", "Pyro", "{{Bomb}} +99 Bombs"}, -- Pyro
	{"191", "3 Dollar Bill", "Isaac's tears get random effects every 2-3 seconds"}, -- 3 Dollar Bill
	{"192", "Telepathy For Dummies", "{{Timer}} Homing tears for the room"}, -- Telepathy For Dummies
	{"193", "MEAT!", "↑ {{Heart}} +1 Health#↑ {{Damage}} +0.3 Damage"}, -- MEAT!
	{"194", "Magic 8 Ball", "↑ {{Shotspeed}} +0.16 Shot speed#{{Card}} Spawns a card"}, -- Magic 8 Ball
	{"195", "Mom's Coin Purse", "{{Pill}} Spawns 4 pills"}, -- Mom's Coin Purse
	{"196", "Squeezy", "↑ {{Tears}} +0.4 Tears#{{SoulHeart}} Spawns 2 Soul Hearts"}, -- Squeezy
	{"197", "Jesus Juice", "↑ {{Damage}} +0.5 Damage#↑ {{Range}} +0.25 Range#↑ +0.5 Tear height"}, -- Jesus Juice
	{"198", "Box", "Spawns 1 pickup of each type"}, -- Box
	{"199", "Mom's Key", "{{Key}} +2 Keys#Chests contain more pickups"}, -- Mom's Key
	{"200", "Mom's Eyeshadow", "{{Charm}} 10% chance to shoot charming tears#{{Luck}} 100% chance at 27 luck"}, -- Mom's Eyeshadow
	{"201", "Iron Bar", "↑ {{Damage}} +0.3 Damage#{{Confusion}} 10% chance to shoot concussive tears#{{Luck}} 100% chance at 27 luck"}, -- Iron Bar
	{"202", "Midas' Touch", "Touching enemies petrifies them and turns them gold#Isaac deals contact damage based on his coin count#{{Coin}} Killing a golden enemy spawns coins#Poop spawned by Isaac has a high chance to be golden poop"}, -- Midas' Touch
	{"203", "Humbleing Bundle", "Pickups spawned are doubled if possible"}, -- Humbleing Bundle
	{"204", "Fanny Pack", "Taking damage has a 50% chance to spawn a random pickup"}, -- Fanny Pack
	{"205", "Sharp Plug", "{{Battery}} Using an uncharged active item fully recharges it at the cost of 2 hearts#Only works when the item has no charges"}, -- Sharp Plug
	{"206", "Guillotine", "↑ {{Tears}} -1 Tear delay#↑ {{Damage}} +1 Damage#Isaac's head becomes an orbital that shoots, doesn't take damage and deals 105 contact damage per second"}, -- Guillotine
	{"207", "Ball of Bandages", "Lv1: Orbital#{{Charm}} Lv2: Orbital that shoots charmed tears#{{Charm}} Lv3: Bandage Girl#{{Charm}} Lv4: Super Bandage Girl"}, -- Ball of Bandages
	{"208", "Champion Belt", "↑ {{Damage}} +1 Damage#Champion enemy chance goes from 5% to 20%#Doesn't increase chance of champion bosses"}, -- Champion Belt
	{"209", "Butt Bombs", "{{Bomb}} +5 Bombs#{{Confusion}} Explosions concuss and damage every enemy in the room"}, -- Butt Bombs
	{"210", "Gnawed Leaf", "After 1 second of inactivity, Isaac becomes invincible"}, -- Gnawed Leaf
	{"211", "Spiderbaby", "Taking damage spawns 1-2 blue spiders"}, -- Spiderbaby
	{"212", "Guppy's Collar", "50% chance to revive with half a heart on death"}, -- Guppy's Collar
	{"213", "Lost Contact", "↓ {{Shotspeed}} -0.15 Shot speed#Isaac's tears destroy enemy shots"}, -- Lost Contact
	{"214", "Anemic", "↑ {{Range}} +5 Range#{{Timer}} When taking damage Isaac leaves a trail of blood creep for the room#The creep deals 6 damage per second"}, -- Anemic
	{"215", "Goat Head", "{{AngelDevilChance}} 100% Devil/Angel Room chance"}, -- Goat Head
	{"216", "Ceremonial Robes", "↑ {{Damage}} +1 Damage#{{BlackHeart}} +3 Black Hearts"}, -- Ceremonial Robes
	{"217", "Mom's Wig", "{{HealingRed}} Heals 1 heart#5% chance to spawn a blue spider when shooting tears#{{Luck}} 100% chance at 10 luck"}, -- Mom's Wig
	{"218", "Placenta", "↑ {{Heart}} +1 Health#{{HealingRed}} 50% chance to heal half a heart every minute"}, -- Placenta
	{"219", "Old Bandage", "↑ {{EmptyHeart}} +1 Empty heart container#{{Heart}} Taking damage has a 10% chance to spawn a Red Heart"}, -- Old Bandage
	{"220", "Sad Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs shoot 10 tears in a circle when they explode"}, -- Sad Bombs
	{"221", "Rubber Cement", "Isaac's tears bounce off enemies and obstacles"}, -- Rubber Cement
	{"222", "Anti-Gravity", "↑ {{Tears}} -2 Tear delay#Holding the fire buttons causes tears to hover in midair#Releasing the fire buttons shoots them in the direction they were fired"}, -- Anti-Gravity
	{"223", "Pyromaniac", "{{Bomb}} +5 Bombs#Immunity to explosions, rock waves, and stomp attacks#{{HealingRed}} Getting hit by explosions heals 1 heart"}, -- Pyromaniac
	{"224", "Cricket's Body", "↑ {{Tears}} -1 Tear delay#↑ {{Tearsize}} x1.2 Tear size#↓ {{Range}} -10 Range#Tears split up in 4 on hit#Split tears deal half damage"}, -- Cricket's Body
	{"225", "Gimpy", "{{SoulHeart}} Taking damage has a chance to spawn a Soul Heart#{{HalfHeart}} Enemies have a chance to drop a half Red Heart on death"}, -- Gimpy
	{"226", "Black Lotus", "↑ {{Heart}} +1 Health#{{SoulHeart}} +1 Soul Heart#{{BlackHeart}} +1 Black Heart"}, -- Black Lotus
	{"227", "Piggy Bank", "{{Coin}} +3 Coins#{{Coin}} Taking damage spawns 1-2 coins"}, -- Piggy Bank
	{"228", "Mom's Perfume", "↑ {{Tears}} -1 Tear delay#{{Fear}} 15% chance to shoot fear tears"}, -- Mom's Perfume
	{"229", "Monstro's Lung", "↓ {{Tears}} x0.23 Tears multiplier#{{Chargeable}} Tears are charged and released in a shotgun style attack"}, -- Monstro's Lung
	{"230", "Abaddon", "↑ {{Speed}} +0.2 Speed#↑ {{Damage}} +1.5 Damage#↓ {{EmptyHeart}} Removes all heart containers#{{BlackHeart}} +6 Black Hearts#{{Fear}} 15% chance to shoot fear tears"}, -- Abaddon
	{"231", "Ball of Tar", "{{Slow}} 10% chance to shoot slowing tears#{{Luck}} 100% chance at 18 luck#{{Slow}} Isaac leaves a trail of slowing creep"}, -- Ball of Tar
	{"232", "Stop Watch", "↑ {{Speed}} +0.3 Speed#{{Slow}} Taking damage slows all enemies in the room permanently"}, -- Stop Watch
	{"233", "Tiny Planet", "↑ +7 Tear height#Spectral tears#Isaac's tears orbit around him"}, -- Tiny Planet
	{"234", "Infestation 2", "Killing an enemy spawns a blue spider"}, -- Infestation 2
	{"235", "", "<item does not exist>"},
	{"236", "E. Coli", "Touching an enemy turns it into poop"}, -- E. Coli
	{"237", "Death's Touch", "↑ {{Damage}} +1.5 Damage#↑ {{Tearsize}} x2 Tear size#↓ {{Tears}} -0.3 Tears#Piercing tears"}, -- Death's Touch
	{"238", "Key Piece 1", "{{Warning}} Getting both parts of the key opens a big golden door#{{AngelChance}} +25% Angel Room chance#{{EternalHeart}} +2% chance for Eternal Hearts"}, -- Key Piece 1
	{"239", "Key Piece 2", "{{Warning}} Getting both parts of the key opens a big golden door#{{AngelChance}} +25% Angel Room chance#{{EternalHeart}} +2% chance for Eternal Hearts"}, -- Key Piece 2
	{"240", "Experimental Treatment", "↑ Increases 4 random stats#↓ Decreases 2 random stats"}, -- Experimental Treatment
	{"241", "Contract from Below", "Doubles all room clear rewards#33% chance for no room clear reward"}, -- Contract from Below
	{"242", "Infamy", "50% chance to block enemy shots"}, -- Infamy
	{"243", "Trinity Shield", "Blocks enemy shots coming from the direction Isaac is shooting"}, -- Trinity Shield
	{"244", "Tech.5", "Occasionally shoot lasers in addition to Isaac's tears"}, -- Tech.5
	{"245", "20/20", "Isaac shoots 2 tears at once"}, -- 20/20
	{"246", "Blue Map", "{{SecretRoom}} Reveals secret room locations on the map"}, -- Blue Map
	{"247", "BFFS!", "Familiars deal double damage"}, -- BFFS!
	{"248", "Hive Mind", "Blue spiders and flies deal double damage"}, -- Hive Mind
	{"249", "There's Options", "Allows Isaac to choose between 2 items after beating a boss"}, -- There's Options
	{"250", "Bogo Bombs", "{{Bomb}} All bomb drops become double bombs"}, -- Bogo Bombs
	{"251", "Starter Deck", "{{Card}} Spawns 1 card on pickup#Isaac can carry 2 cards#Turns all pills into cards"}, -- Starter Deck
	{"252", "Little Baggy", "{{Pill}} Spawns 1 pill on pickup#Isaac can carry 2 pills#Turns all cards into pills"}, -- Little Baggy
	{"253", "Magic Scab", "↑ {{Heart}} +1 Health#↑ {{Luck}} +1 Luck"}, -- Magic Scab
	{"254", "Blood Clot", "↑ {{Damage}} +1 Damage for the left eye#↑ {{Range}} +5 Range for the left eye#↑ +0.5 Tear height"}, -- Blood Clot
	{"255", "Screw", "↑ {{Tears}} +0.5 Tears#↑ {{Shotspeed}} +0.2 Shot speed"}, -- Screw
	{"256", "Hot Bombs", "{{Bomb}} +5 Bombs#{{Burning}} Isaac's bombs leave a flame where they explode"}, -- Hot Bombs
	{"257", "Fire Mind", "{{Burning}} Isaac's tears light enemies on fire#10% chance for tears to explode on enemy impact#{{Luck}} 100% chance at 13 luck#{{Warning}} The explosion can hurt Isaac"}, -- Fire Mind
	{"258", "Missing No.", "Rerolls all of Isaac's items and stats on pickup and at every new floor"}, -- Missing No.
	{"259", "Dark Matter", "↑ {{Damage}} +1 Damage#{{Fear}} 33% chance to shoot fear tears#{{Luck}} 100% chance at 20 luck"}, -- Dark Matter
	{"260", "Black Candle", "{{CurseBlind}} Immune to curses#{{BlackHeart}} +1 Black Heart#{{AngelDevilChance}} +15% Devil/Angel Room chance"}, -- Black Candle
	{"261", "Proptosis", "↑ {{Damage}} x2 Damage multiplier#↓ Tears deal less damage the further they travel"}, -- Proptosis
	{"262", "Missing Page 2", "{{BlackHeart}} +1 Black Heart#Taking damage down to 1 heart damages all enemies in the room"}, -- Missing Page 2
	{"263", "", "<item does not exist>"},
	{"264", "Smart Fly", "Orbital#Attacks enemies when Isaac takes damage#Deals 22.5 contact damage per second"}, -- Smart Fly
	{"265", "Dry Baby", "10% chance to damage all enemies in the room when it is hit by an enemy tear"}, -- Dry Baby
	{"266", "Juicy Sack", "{{Slow}} Leaves slowing creep#Spawns 1-2 friendly spiders after clearing a room"}, -- Juicy Sack
	{"267", "Robo-Baby 2.0", "Shoots lasers#Deals 3.5 damage per shot#Moves in the direction Isaac is shooting"}, -- Robo-Baby 2.0
	{"268", "Rotten Baby", "Spawns blue flies when Isaac shoots"}, -- Rotten Baby
	{"269", "Headless Baby", "Leaves creep which deals 6 damage per second"}, -- Headless Baby
	{"270", "Leech", "Chases enemies#{{HealingRed}} Heals Isaac for half a heart when it kills an enemy#Deals 3.2 damage per second"}, -- Leech
	{"271", "Mystery Sack", "Spawns a random pickup every 5-6 rooms"}, -- Mystery Sack
	{"272", "BBF", "Friendly exploding fly#The explosion deals 60 damage#{{Warning}} The explosion can hurt Isaac"}, -- BBF
	{"273", "Bob's Brain", "Dashes in the direction Isaac is shooting#Explodes when it hits an enemy#{{Poison}} The explosion deals 60 damage and poisons enemies#{{Warning}} The explosion can hurt Isaac"}, -- Bob's Brain
	{"274", "Best Bud", "Taking damage spawns one midrange orbital for the room#It deals 75 contact damage per second"}, -- Best Bud
	{"275", "Lil Brimstone", "{{Chargeable}} Familiar that charges and shoots a {{Collectible118}} blood beam#It deals 31.5 damage over 0.63 seconds"}, -- Lil Brimstone
	{"276", "Isaac's Heart", "Isaac becomes invincible#Spawns a heart familiar that follows Isaac#{{Warning}} If the heart familiar gets hit, Isaac takes damage"}, -- Isaac's Heart
	{"277", "Lil Haunt", "{{Fear}} Chases and fears enemies#Deals 4 contact damage per second"}, -- Lil Haunt
	{"278", "Dark Bum", "{{Heart}} Picks up nearby Red Hearts#{{SoulHeart}} Spawns a Soul Heart or spider for every 1.5 Red Hearts picked up"}, -- Dark Bum
	{"279", "Big Fan", "Large orbital#Deals 30 contact damage per second"}, -- Big Fan
	{"280", "Sissy Longlegs", "Randomly spawns blue spiders in hostile rooms"}, -- Sissy Longlegs
	{"281", "Punching Bag", "Decoy familiar#Enemies target him instead of Isaac"}, -- Punching Bag
	{"282", "How to Jump", "Allows Isaac to jump over gaps and obstacles"}, -- How to Jump
	{"283", "D100", "Reroll all pickups and pedestal items in the room, and all of Isaac's passive items"}, -- D100
	{"284", "D4", "Reroll all of Isaac's passive items"}, -- D4
	{"285", "D10", "Reroll all enemies in the room"}, -- D10
	{"286", "Blank Card", "Triggers the effect of the rune or card Isaac holds without using it"}, -- Blank Card
	{"287", "Book of Secrets", "{{Timer}} Grants one of these effects for the floor:#{{Collectible54}} Treasure Map#{{Collectible21}} Compass#{{Collectible246}} Blue Map"}, -- Book of Secrets
	{"288", "Box of Spiders", "Spawns 1-4 blue spiders"}, -- Box of Spiders
	{"289", "Red Candle", "Throws a red flame#It deals contact damage, blocks enemy tears, and disappears when it has dealt damage or blocked shots 5 times"}, -- Red Candle
	{"290", "The Jar", "{{Heart}} Picking up Red Hearts while at full health stores up to 4 of them in the Jar#Using the item drops all stored hearts on the floor"}, -- The Jar
	{"291", "Flush!", "Turns all non-boss enemies into poop#Instantly kills poop enemies and bosses"}, -- Flush!
	{"292", "Satanic Bible", "{{BlackHeart}} +1 Black Heart"}, -- Satanic Bible
	{"293", "Head of Krampus", "{{Collectible118}} Shoot a 4-way blood beam#They each deal 440 damage over 1.33 seconds"}, -- Head of Krampus
	{"294", "Butter Bean", "Knocks back nearby enemies and projectiles#10% chance to turn into the stronger {{Collectible484}} Wait What? when swapping it with a different active item and picking it up again"}, -- Butter Bean
	{"295", "Magic Fingers", "Deals 2x Isaac's damage to all enemies#{{Coin}} Costs 1 coin"}, -- Magic Fingers
	{"296", "Converter", "{{Heart}} Converts 2 Soul/Black Hearts into 1 heart container"}, -- Converter
	-- NOTE FOR LOCALIZERS: There is code to highlight the text of your current floor
	-- For it to work, only use line breaks or semicolons to separate floor details, and use the same order as English
	{"297", "Pandora's Box", "{{NoLB}}Spawns rewards based on floor:#B1: 2{{SoulHeart}}; B2: 2{{Bomb}} + 2{{Key}}#{{NoLB}}C1: Boss item; C2: C1 + 2{{SoulHeart}}#D1: 4{{SoulHeart}}; D2: 20{{Coin}}#W1: 2 Boss items#W2: {{Collectible33}} The Bible#???/Void: Nothing#Sheol: Devil item + 1{{BlackHeart}}#Cathe: Angel item + 1{{EternalHeart}}#{{NoLB}}Dark Room: Unlocks {{Collectible523}} Moving Box#Chest: 1{{Coin}}"}, -- Pandora's Box
	{"298", "Unicorn Stump", "{{Timer}} Receive for 6 seconds:#↑ {{Speed}} +0.28 Speed#Invincibility#Isaac can't shoot (No contact damage)"}, -- Unicorn Stump
	{"299", "Taurus", "↓ {{Speed}} -0.3 Speed#↑ {{Speed}} Slowly gain speed while in hostile rooms#At 2 speed, Isaac becomes invincible and deals contact damage#Afterwards, lose the Taurus speed boost for the room"}, -- Taurus
	{"300", "Aries", "↑ {{Speed}} +0.25 Speed#Touching enemies deals contact damage"}, -- Aries
	{"301", "Cancer", "{{SoulHeart}} +3 Soul Hearts#Taking damage reduces all future damage in the room to half a heart"}, -- Cancer
	{"302", "Leo", "Size up#Isaac can destroy rocks by walking into them"}, -- Leo
	{"303", "Virgo", "Taking damage can make Isaac temporarily invincible#{{Luck}} 100% chance at 10 luck#{{Pill}} Converts negative pills into positive ones"}, -- Virgo
	{"304", "Libra", "+6 {{Coin}} coins, {{Bomb}} bombs and {{Key}} keys#Balances Isaac's stats#Future stat changes will be spread across all stats"}, -- Libra
	{"305", "Scorpio", "{{Poison}} Poison tears"}, -- Scorpio
	{"306", "Sagittarius", "↑ {{Speed}} +0.2 Speed#Piercing tears"}, -- Sagittarius
	{"307", "Capricorn", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.1 Speed#↑ {{Tears}} -1 Tear delay#↑ {{Damage}} +0.5 Damage#↑ {{Range}} +1.5 Range#+1 {{Coin}} coin, {{Bomb}} bomb and {{Key}} key"}, -- Capricorn
	{"308", "Aquarius", "Isaac leaves a trail of creep#The creep deals 6 damage per second"}, -- Aquarius
	{"309", "Pisces", "↑ {{Tears}} -1 Tear delay#↑ {{Tearsize}} x1.25 Tear size#Increases tear knockback"}, -- Pisces
	{"310", "Eve's Mascara", "↑ {{Damage}} x2 Damage multiplier#↓ {{Tears}} x0.5 Tears multiplier#↓ {{Shotspeed}} -0.5 Shot speed"}, -- Eve's Mascara
	{"311", "Judas' Shadow", "{{Player12}} When dead, respawn as Dark Judas with a x2 damage multiplier"}, -- Judas' Shadow
	{"312", "Maggy's Bow", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#All Red Hearts heal double their value"}, -- Maggy's Bow
	{"313", "Holy Mantle", "Negates the first hit taken once per room"}, -- Holy Mantle
	{"314", "Thunder Thighs", "↑ {{Heart}} +1 Health#↓ {{Speed}} -0.4 Speed#Isaac can destroy rocks by walking into them"}, -- Thunder Thighs
	{"315", "Strange Attractor", "Isaac's tears attract enemies, pickups and trinkets"}, -- Strange Attractor
	{"316", "Cursed Eye", "Charged wave of 4 tears#{{Warning}} Taking damage while partially charged teleports Isaac to a random room"}, -- Cursed Eye
	{"317", "Mysterious Liquid", "Isaac's tears leave creep#The creep deals 30 damage per second"}, -- Mysterious Liquid
	{"318", "Gemini", "Close combat familiar#Deals 6 contact damage per second"}, -- Gemini
	{"319", "Cain's Other Eye", "Bounces around the room#Low accuracy tears that deal Isaac's damage"}, -- Cain's Other Eye
	{"320", "???'s Only Friend", "Controllable fly#Deals 37.5 contact damage per second"}, -- ???'s Only Friend
	{"321", "Samson's Chains", "Draggable ball that can destroy rocks#Deals 10.7 contact damage per second"}, -- Samson's Chains
	{"322", "Mongo Baby", "Mimics your baby familiars' tears#If you have none, shoots normal 3.5 damage tears"}, -- Mongo Baby
	{"323", "Isaac's Tears", "Shoots 8 tears in all directions#The tears copy Isaac's tear effects#Recharges by shooting tears"}, -- Isaac's Tears
	{"324", "Undefined", "Teleports Isaac to the {{TreasureRoom}} Treasure, {{SecretRoom}} Secret, {{SuperSecretRoom}} Super Secret or {{ErrorRoom}} I AM ERROR Room"}, -- Undefined
	{"325", "Scissors", "{{Timer}} Isaac's head turns into a stationary familiar for the room#The head shoots 3.5 damage tears#The body is controlled separately and still shoots Isaac's tears"}, -- Scissors
	{"326", "Breath of Life", "Holding down the USE button empties the charge bar#Isaac is temporarily invincible when the charge bar is empty#{{Warning}} Holding it for too long deals damage to Isaac"}, -- Breath of Life
	{"327", "The Polaroid", "Taking damage at half a Red Heart or none makes isaac temporarily invincible"}, -- The Polaroid
	{"328", "The Negative", "Taking damage at half a Red Heart or none damages all enemies in the room"}, -- The Negative
	{"329", "The Ludovico Technique", "Replaces Isaac's tears with one giant controllable tear"}, -- The Ludovico Technique
	{"330", "Soy Milk", "↑ {{Tears}} x4 Tears multiplier#↑ {{Tears}} -2 Tear delay#↓ {{Damage}} x0.2 Damage multiplier#↓ {{Tearsize}} x0.5 Tear size"}, -- Soy Milk
	{"331", "Godhead", "↑ {{Damage}} +0.5 Damage#↑ {{Range}} +1.2 Range#↑ +0.8 Tear height#↓ {{Tears}} -0.3 Tears#↓ {{Shotspeed}} -0.3 Shot speed#Homing tears#{{Damage}} Tears gain an aura that deals 4.5x Isaac's damage per second"}, -- Godhead
	{"332", "Lazarus' Rags", "{{Player11}} When dead, revive as Lazarus (Risen)"}, -- Lazarus' Rags
	{"333", "The Mind", "Full mapping effect"}, -- The Mind
	{"334", "The Body", "↑ {{Heart}} +3 Health"}, -- The Body
	{"335", "The Soul", "{{SoulHeart}} +2 Soul Hearts#Grants an aura that repels enemies and projectiles"}, -- The Soul
	{"336", "Dead Onion", "↑ {{Range}} +0.25 Range#↑ {{Tearsize}} x1.5 Tear size#↓ -0.5 Tear height#↓ {{Shotspeed}} -0.4 Shot speed#Piercing + spectral tears"}, -- Dead Onion
	{"337", "Broken Watch", "{{Slow}} Slows down every 4th room#13% chance to speed up the room instead"}, -- Broken Watch
	{"338", "The Boomerang", "Throwable boomerang#Petrifies enemies and deals 2x Isaac's damage#Can grab and bring back items"}, -- The Boomerang
	{"339", "Safety Pin", "↑ {{Range}} +5.25 Range#↑ +0.5 Tear height#↑ {{Shotspeed}} +0.16 Shot speed#{{BlackHeart}} +1 Black Heart"}, -- Safety Pin
	{"340", "Caffeine Pill", "↑ {{Speed}} +0.3 Speed#↑ Size down#{{Pill}} Spawns a random pill"}, -- Caffeine Pill
	{"341", "Torn Photo", "↑ {{Tears}} +0.7 Tears#↑ {{Shotspeed}} +0.16 Shot speed"}, -- Torn Photo
	{"342", "Blue Cap", "↑ {{Heart}} +1 Health#↑ {{Tears}} +0.7 Tears#↓ {{Shotspeed}} -0.16 Shot speed"}, -- Blue Cap
	{"343", "Latch Key", "↑ {{Luck}} +1 Luck#{{SoulHeart}} +1 Soul Heart#{{Key}} Spawns 2 keys"}, -- Latch Key
	{"344", "Match Book", "{{BlackHeart}} +1 Black Heart#{{Bomb}} Spawns 3 bombs"}, -- Match Book
	{"345", "Synthoil", "↑ {{Damage}} +1 Damage#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- Synthoil
	{"346", "A Snack", "↑ {{Heart}} +1 Health"}, -- A Snack
	{"347", "Diplopia", "Duplicates all item pedestals and pickups in the room"}, -- Diplopia
	{"348", "Placebo", "{{Pill}} Triggers the effect of the pill Isaac holds without using it"}, -- Placebo
	{"349", "Wooden Nickel", "{{Coin}} 56% chance to spawn a random coin"}, -- Wooden Nickel
	{"350", "Toxic Shock", "{{Poison}} Entering a room poisons all enemies#Enemies killed leave a puddle of creep#The creep deals 30 damage per second"}, -- Toxic Shock
	{"351", "Mega Bean", "Petrifies all enemies in the room#{{Poison}} Deals 5 damage and poisons any enemies nearby#Sends a rock wave in the direction Isaac is moving#The rock wave can open secret rooms and break rocks"}, -- Mega Bean
	{"352", "Glass Cannon", "{{Warning}} Firing the cannon reduces Isaac's health down to half a heart#Shoots a large piercing + spectral tear that does 10x Isaac's damage"}, -- Glass Cannon
	{"353", "Bomber Boy", "{{Bomb}} +5 Bombs#Bombs explode in a cross-shaped pattern"}, -- Bomber Boy
	{"354", "Crack Jacks", "↑ {{Heart}} +1 Health#{{Trinket}} Spawns a trinket"}, -- Crack Jacks
	{"355", "Mom's Pearls", "↑ {{Range}} +1.25 Range#↑ +0.5 Tear height#↑ {{Luck}} +1 Luck"}, -- Mom's Pearls
	{"356", "Car Battery", "{{Battery}} Using an active item triggers its effect twice"}, -- Car Battery
	{"357", "Box of Friends", "{{Timer}} Duplicates all your familiars for the room#{{Collectible113}} Grants a Demon Baby for the room if Isaac has no familiars"}, -- Box of Friends
	{"358", "The Wiz", "Spectral tears#Isaac shoots 2 tears at once diagonally"}, -- The Wiz
	{"359", "8 Inch Nails", "↑ {{Damage}} +1.5 Damage#Increases knockback"}, -- 8 Inch Nails
	{"360", "Incubus", "Shoots tears with the same tear rate, damage and effects as Isaac"}, -- Incubus
	{"361", "Fate's Reward", "Shoots tears with the same damage and effects as Isaac#Shoots at half the rate of other familiars"}, -- Fate's Reward
	{"362", "Lil Chest", "35% chance to spawn a pickup every room"}, -- Lil Chest
	{"363", "Sworn Protector", "Orbital#Deals 105 contact damage per second#Blocks and attracts enemy shots#{{EternalHeart}} Blocking 10 shots in one room spawns an Eternal Heart"}, -- Sworn Protector
	{"364", "Friend Zone", "Midrange fly orbital#Deals 45 contact damage per second"}, -- Friend Zone
	{"365", "Lost Fly", "Moves along walls/obstacles#Deals 105 contact damage per second"}, -- Lost Fly
	{"366", "Scatter Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs scatter into 2-4 tiny bombs"}, -- Scatter Bombs
	{"367", "Sticky Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs stick to enemies#Killing an enemy with a bomb spawns blue spiders"}, -- Sticky Bombs
	{"368", "Epiphora", "↑ {{Tears}} Shooting in one direction gradually decreases tear delay up to 200% and decreases accuracy"}, -- Epiphora
	{"369", "Continuum", "↑ {{Range}} +2.25 Range#↑ +1.5 Tear height#Spectral tears#Tears can travel through one side of the screen and come out the other side"}, -- Continuum
	{"370", "Mr. Dolly", "↑ {{Tears}} +0.7 Tears#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height#{{UnknownHeart}} Spawns 3 random hearts"}, -- Mr. Dolly
	{"371", "Curse of the Tower", "{{Warning}} Taking damage spawns 6 Troll Bombs#The Troll Bombs inherit Isaac's bomb effects"}, -- Curse of the Tower
	{"372", "Charged Baby", "Every 30 seconds while in an uncleared room, the familiar can:#{{Battery}} Spawn a Battery (max 2 per room)#{{Battery}} Add one charge to the active item (max 2 per room)#Petrify all enemies in the room"}, -- Charged Baby
	{"373", "Dead Eye", "↑ {{Damage}} Consecutive tear hits on enemies grant +25% damage (max +100%)#Missing has a chance to reset the multiplier"}, -- Dead Eye
	{"374", "Holy Light", "10% chance to shoot holy tears, which spawn a beam of light on hit#{{Luck}} 50% chance at 9 luck#{{Damage}} The beam deals 4x Isaac's damage"}, -- Holy Light
	{"375", "Host Hat", "Grants immunity to explosions, rock wave attacks and Mom and Satan's stomp attacks#25% chance to reflect enemy shots"}, -- Host Hat
	{"376", "Restock", "Spawns 3 random pickups#Buying an item from a Shop restocks it instantly"}, -- Restock
	{"377", "Bursting Sack", "Spider enemies no longer target or deal contact damage to Isaac"}, -- Bursting Sack
	{"378", "No. 2", "Holding a fire button for 2.35 seconds spawns a lit Butt Bomb"}, -- No. 2
	{"379", "Pupula Duplex", "↑ {{Tearsize}} x2 Tear size#Spectral tears"}, -- Pupula Duplex
	{"380", "Pay To Play", "{{Coin}} +5 Coins#{{Coin}} Single-key doors must be opened with coins instead of keys"}, -- Pay To Play
	{"381", "Eden's Blessing", "↑ {{Tears}} +0.7 Tears#Grants a random item at the start of the next run"}, -- Eden's Blessing
	{"382", "Friendly Ball", "Can be thrown at enemies to capture them#Using the item after capturing an enemy spawns it as a friendly companion"}, -- Friendly Ball
	{"383", "Tear Detonator", "Splits all of Isaac's tears currently on screen in a circle of 6 tears"}, -- Tear Detonator
	{"384", "Lil Gurdy", "{{Chargeable}} Launches and bounces around the room with speed based on charge amount#Deals 5-90 contact damage per second depending on speed"}, -- Lil Gurdy
	{"385", "Bumbo", "{{Coin}} Picks up nearby coins#Levels up after getting 6, 12, and 24 coins#Lv2: Chance to spawn item after room clears#Lv3: Shoots tears that can spawn coins on hit#Lv4: Chases enemies, occasionally dropping bombs, can spawn item on coin pickup"}, -- Bumbo
	{"386", "D12", "Rerolls any obstacle into another random obstacle (e.g. poop, pots, TNT, red poop, stone blocks etc.)"}, -- D12
	{"387", "Censer", "{{Slow}} Familiar surrounded by a huge aura of light that slows down enemies and projectiles in it"}, -- Censer
	{"388", "Key Bum", "{{Key}} Picks up nearby keys#{{Chest}} Spawns random chests in return"}, -- Key Bum
	{"389", "Rune Bag", "{{Rune}} Spawns a random rune every 5-6 rooms"}, -- Rune Bag
	{"390", "Seraphim", "Shoots Sacred Heart tears#Deals 10 damage per tear"}, -- Seraphim
	{"391", "Betrayal", "{{Charm}} Taking damage charms all enemies in the room"}, -- Betrayal
	{"392", "Zodiac", "Grants a random zodiac item effect every floor"}, -- Zodiac
	{"393", "Serpent's Kiss", "{{Poison}} 15% chance to shoot poison tears#{{Poison}} Poison enemies on contact#{{BlackHeart}} Poisoned enemies have a chance to drop a Black Heart on death"}, -- Serpent's Kiss
	{"394", "Marked", "↑ {{Tears}} +0.7 Tears#↑ {{Range}} +3.15 Range#↑ +0.3 Tear height#Isaac automatically shoots tears at a movable red target on the ground"}, -- Marked
	{"395", "Tech X", "{{Chargeable}} Isaac's tears are replaced by a chargeable laser ring#Ring size increases with charge amount"}, -- Tech X
	{"396", "Ventricle Razor", "Creates up to two portals to travel between#Can be placed in different rooms"}, -- Ventricle Razor
	{"397", "Tractor Beam", "↑ {{Tears}} +0.5 Tears#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height#↑ {{Shotspeed}} +0.16 Shot speed#Isaac's tears always travel along a beam of light in front of him"}, -- Tractor Beam
	{"398", "God's Flesh", "Tears can shrink enemies#Shrunken enemies can be crushed and killed by walking over them"}, -- God's Flesh
	{"399", "Maw of the Void", "↑ {{Damage}} +1 Damage#{{Chargeable}} Shooting tears for 2.35 seconds and releasing the fire button creates a black brimstone ring around Isaac#It deals 30x Isaac's damage over 2 seconds#{{BlackHeart}} Enemies killed by the black ring have a 5% chance to drop a Black Heart"}, -- Maw of the Void
	{"400", "Spear of Destiny", "Isaac holds a spear in front of him#{{Fear}} The spear deals twice his damage and can fear enemies on contact"}, -- Spear of Destiny
	{"401", "Explosivo", "25% chance to shoot sticky bomb tears#Sticky bomb tears do not deal damage on hit and explode after a few seconds"}, -- Explosivo
	{"402", "Chaos", "All items are chosen from random item pools#Spawns 1-6 random pickups"}, -- Chaos
	{"403", "Spider Mod", "Displays tear damage and health bars of all enemies#Inflicts random status effects to enemies on contact#Randomly spawns batteries"}, -- Spider Mod
	{"404", "Farting Baby", "Blocks projectiles#When hit, 10% chance to fart and {{Charm}} charm, {{Poison}} poison or knockback enemies"}, -- Farting Baby
	{"405", "GB Bug", "Bounces around the room#Deals 120 damage per second and applies random status effects to enemies on contact"}, -- GB Bug
	{"406", "D8", "Multiplies Isaac's damage, tears, range and speed stats by between x0.5 and x2#The multipliers are rerolled each use"}, -- D8
	{"407", "Purity", "↑ Boosts one of Isaac's stats depending on the color of the aura#Taking damage removes the effect, and gives Isaac a new effect in the next room#{{ColorYellow}}Yellow{{CR}} = ↑ {{Speed}} +0.5 Speed#{{ColorBlue}}Blue{{CR}} = ↑ {{Tears}} -4 Tear delay#{{ColorRed}}Red{{CR}} = ↑ {{Damage}} +4 Damage#{{ColorOrange}}Orange{{CR}} = ↑ {{Range}} +7.5 Range, ↑ +1 Tear height"}, -- Purity
	{"408", "Athame", "Taking damage creates a black brimstone ring around Isaac#It deals 30x Isaac's damage over 2 seconds#{{BlackHeart}} Enemies killed by the ring have a 15% chance to drop a Black Heart"}, -- Athame
	{"409", "Empty Vessel", "{{BlackHeart}} +2 Black Hearts#{{EmptyHeart}} When Isaac has no Red Hearts:#Flight#Every 40 seconds while in a hostile room, gain a shield for 10 seconds"}, -- Empty Vessel
	{"410", "Evil Eye", "3.33% chance to shoot an eye#{{Luck}} 10% chance at 20 luck#The eye moves in a straight line and shoots tears in the same direction as Isaac"}, -- Evil Eye
	{"411", "Lusty Blood", "↑ {{Damage}} +0.5 Damage for each enemy killed in the room#Caps at +5 Damage after 10 kills"}, -- Lusty Blood
	{"412", "Cambion Conception", "Taking damage 15 times spawns a permanent demon familiar#After two familiars, it takes 30 instead of 15#Caps at 4 familiars"}, -- Cambion Conception
	{"413", "Immaculate Conception", "Picking up 15 hearts spawns a permanent angelic familiar#Caps at 5 familiars#{{SoulHeart}} If all familiars have been granted, spawns a Soul Heart instead"}, -- Immaculate Conception
	{"414", "More Options", "{{TreasureRoom}} Allows Isaac to choose between 2 items in treasure rooms"}, -- More Options
	{"415", "Crown Of Light", "{{SoulHeart}} +2 Soul Hearts#If Isaac has no damaged heart containers:#↑ {{Damage}} x2 Damage multiplier#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height#↓ {{Shotspeed}} -0.3 Shot speed#Taking any damage removes the effect for the room"}, -- Crown Of Light
	{"416", "Deep Pockets", "Allows Isaac to carry two runes/cards/pills"}, -- Deep Pockets
	{"417", "Succubus", "Bounces around the room surrounded by a damaging aura that deals 1.29x Isaac's damage per second#↑ {{Damage}} x1.5 Damage multiplier while standing in the aura"}, -- Succubus
	{"418", "Fruit Cake", "Each one of Isaac's tears gets a different effect"}, -- Fruit Cake
	{"419", "Teleport 2.0", "Teleports Isaac to a room that has not been cleared yet#Hierarchy: {{Room}}>{{BossRoom}}>{{SuperSecretRoom}}>{{Shop}}>{{TreasureRoom}}>{{SacrificeRoom}}> {{DiceRoom}}>{{Library}}>{{CursedRoom}}>{{MiniBoss}}>{{ChallengeRoom}}{{BossRushRoom}}>{{IsaacsRoom}}{{BarrenRoom}}> {{ArcadeRoom}}>{{ChestRoom}}>{{SecretRoom}}>{{DevilRoom}}{{AngelRoom}}>{{ErrorRoom}}"}, -- Teleport 2.0
	{"420", "Black Powder", "Walking in a circle draws a pentagram on the floor, which deals 130 damage over 4 seconds"}, -- Black Powder
	{"421", "Kidney Bean", "{{Charm}} Charms and deals 5 damage to all enemies in close range"}, -- Kidney Bean
	{"422", "Glowing Hour Glass", "Brings Isaac back to the previous room and reverses all actions done in the room the item was used in"}, -- Glowing Hour Glass
	{"423", "Circle of Protection", "Surrounds Isaac with a large halo that deals his damage on contact per second#Chance to reflect enemy projectiles"}, -- Circle of Protection
	{"424", "Sack Head", "Pickups have a 33% chance to be replaced with a sack#Spawns a sack"}, -- Sack Head
	{"425", "Night Light", "{{Slow}} Spawns a slowing cone of light in front of Isaac"}, -- Night Light
	{"426", "Obsessed Fan", "Mimics Isaac's exact movement on a 3 second delay#Deals 30 contact damage per second"}, -- Obsessed Fan
	{"427", "Mine Crafter", "Spawns a pushable TNT barrel#Using the item a second time in the same room remotely detonates the barrel"}, -- Mine Crafter
	{"428", "PJs", "{{HealingRed}} Full health#{{SoulHeart}} +4 Soul Hearts"}, -- PJs
	{"429", "Head of the Keeper", "{{Coin}} Hitting an enemy with a tear has a 5% chance to spawn a Penny"}, -- Head of the Keeper
	{"430", "Papa Fly", "Mimics Isaac's movement on a 1 second delay#Shoots tears at nearby enemies that deal Isaac's damage"}, -- Papa Fly
	{"431", "Multidimensional Baby", "Mimics Isaac's movement on a 2 second delay#Tears that pass through it are doubled and gain a range + shot speed boost"}, -- Multidimensional Baby
	{"432", "Glitter Bombs", "{{Bomb}} +5 Bombs#{{Charm}} Isaac's bombs have a 25% chance to drop a random pickup and a 15% chance to charm enemies when they explode"}, -- Glitter Bombs
	{"433", "My Shadow", "{{Fear}} Taking damage fears all enemies in the room and spawns a friendly black charger#The charger deals 5 damage per second"}, -- My Shadow
	{"434", "Jar of Flies", "Killing an enemy adds a blue fly to the jar, up to 20 flies#Using the item releases all the flies"}, -- Jar of Flies
	{"435", "Lil Loki", "Shoots 4 tears in a cross pattern#Deals 3.5 damage per tear"}, -- Lil Loki
	{"436", "Milk!", "{{Tears}} Taking damage grants a Tears up for the duration of the room"}, -- Milk!
	{"437", "D7", "Restarts a room and respawns all enemies#Can be used to get multiple room clear rewards from a single room#If used after a Greed fight, rerolls the room into a normal Shop/Secret Room"}, -- D7
	{"438", "Binky", "↑ {{Tears}} +0.75 Tears#↑ Size down#{{SoulHeart}} +1 Soul Heart"}, -- Binky
	{"439", "Mom's Box", "{{Trinket}} Spawns a random trinket#While held:#↑ {{Luck}} +1 Luck#{{Trinket}} Doubles trinket effects"}, -- Mom's Box
	{"440", "Kidney Stone", "↑ +2 Tear height#↓ {{Speed}} -0.2 Speed#↓ {{Range}} -17 Range#Isaac occasionally stops firing and charges an attack that releases a burst of tears and a kidney stone"}, -- Kidney Stone
	{"441", "Mega Blast", "{{Timer}} Fires a huge Mega Satan blood beam for 15 seconds#The beam persists between rooms and floors"}, -- Mega Blast
	{"442", "Dark Prince's Crown", "While at 1 full Red Heart:#↑ {{Tears}} +0.75 Tears#↑ {{Range}} +1.5 Range#↑ +1 Tear height#↑ {{Shotspeed}} +0.2 Shot speed"}, -- Dark Princes Crown (apostrophe added to the name in Repentance) -- Dark Prince's Crown
	{"443", "Apple!", "↑ {{Tears}} +0.3 Tears#{{Damage}} 6.66% chance to shoot razor blades that deal 4x Isaac's damage#{{Luck}} 100% chance at 14 luck"}, -- Apple!
	{"444", "Lead Pencil", "Isaac shoots a cluster of tears every 15 tears#Tears in the cluster deal double damage"}, -- Lead Pencil
	{"445", "Dog Tooth", "↑ {{Speed}} +0.1 Speed#↑ {{Damage}} +0.3 Damage#{{SecretRoom}}{{SuperSecretRoom}} A wolf howls in rooms adjacent to a Secret/Super Secret Room#{{LadderRoom}} A dog barks in rooms with a crawlspace under a rock"}, -- Dog Tooth
	{"446", "Dead Tooth", "{{Poison}} While firing, Isaac is surrounded by a green aura that poisons enemies"}, -- Dead Tooth
	{"447", "Linger Bean", "Firing without pause for 7.5 seconds spawns a poop cloud#The cloud deals Isaac's damage 5 times a second#The cloud lasts 15 seconds and can be moved by shooting it"}, -- Linger Bean
	{"448", "Shard of Glass", "Upon taking damage:#{{Heart}} 25% chance to spawn a Red Heart#{{Collectible214}} 10% chance to get ↑ {{Range}} +5 Range and leave a trail of blood creep for the room"}, -- Shard of Glass
	{"449", "Metal Plate", "{{SoulHeart}} +1 Soul Heart#{{Confusion}} Enemy bullets have a 25% chance to be reflected as concussive tears"}, -- Metal Plate
	{"450", "Eye of Greed", "Every 20 tears, Isaac shoots a coin tear that deals double damage#Enemies hit with the coin get petrified and turn into gold#{{Coin}} Killing a gold enemy drops 1-4 coins#{{Warning}} Firing a coin tear costs 1 coin"}, -- Eye of Greed
	{"451", "Tarot Cloth", "{{Card}} Spawns a card#{{Card}} Card effects are doubled or enhanced"}, -- Tarot Cloth
	{"452", "Varicose Veins", "Taking damage shoots 10 tears in a circle around Isaac#The tears deal Isaac's damage + 25"}, -- Varicose Veins
	{"453", "Compound Fracture", "↑ {{Range}} +1.5 Range#↑ +1 Tear height#Tears shatter into 1-3 small bone shards upon hitting anything"}, -- Compound Fracture
	{"454", "Polydactyly", "Spawns a {{Rune}} rune, {{Card}} card or {{Pill}} pill on pickup#Allows Isaac to carry 2 runes/cards/pills"}, -- Polydactyly
	{"455", "Dad's Lost Coin", "↑ {{Range}} +1.5 Range#↑ +1 Tear height#{{Luck}} Spawns a Lucky Penny"}, -- Dad's Lost Coin
	{"456", "Moldy Bread", "↑ {{Heart}} +1 Health"}, -- Moldy Bread
	{"457", "Cone Head", "{{SoulHeart}} +1 Soul Heart#20% chance to negate damage taken"}, -- Cone Head
	{"458", "Belly Button", "{{Trinket}} Allows Isaac to carry 2 trinkets#{{Trinket}} Spawns a random trinket"}, -- Belly Button
	{"459", "Sinus Infection", "20% chance to shoot a sticky booger#{{Damage}} Boogers deal Isaac's damage once a second and stick for 60 seconds#{{Luck}} Not affected by luck"}, -- Sinus Infection
	{"460", "Glaucoma", "{{Confusion}} 5% chance to shoot concussive tears#Makes the screen slightly darker"}, -- Glaucoma
	{"461", "Parasitoid", "15% chance to shoot egg sacks#{{Luck}} 50% chance at 5 luck#{{Slow}} Egg sacks spawn slowing creep and a blue spider or fly on hit"}, -- Parasitoid
	{"462", "Eye of Belial", "↑ {{Range}} +1.5 Range#↑ +1 Tear height#Piercing tears#Hitting an enemy makes the tear homing and doubles its damage"}, -- Eye of Belial
	{"463", "Sulfuric Acid", "↑ {{Damage}} +0.3 Damage#Isaac's tears can destroy rocks and open doors"}, -- Sulfuric Acid
	{"464", "Glyph of Balance", "{{SoulHeart}} +2 Soul Hearts#Champion enemies drop whatever pickup Isaac needs the most"}, -- Glyph of Balance
	{"465", "Analog Stick", "↑ {{Tears}} +0.3 Tears#Allows Isaac to shoot tears in any direction"}, -- Analog Stick
	{"466", "Contagion", "{{Poison}} The first enemy killed in a room explodes and poison all nearby enemies"}, -- Contagion
	{"467", "Finger!", "{{Damage}} Constantly deals 10% of Isaac's damage in the direction it points"}, -- Finger!
	{"468", "Shade", "Follows Isaac's movement on a 1 second delay#Deals 30 contact damage per second#After it deals 600 damage, it is absorbed by Isaac, increasing his contact damage"}, -- Shade
	{"469", "Depression", "Leaves a trail of creep#The creep deals 6 damage per second#Enemies that touch the cloud can be hit by a holy light beam"}, -- Depression
	{"470", "Hushy", "Bounces around the room#Deals 30 contact damage per second#Stops moving when Isaac shoots#Blocks projectiles when stopped"}, -- Hushy
	{"471", "Lil Monstro", "{{Chargeable}} Charges a shotgun attack similar to {{Collectible229}} Monstro's Lung#Each tear deals 3.5 damage"}, -- Lil Monstro
	{"472", "King Baby", "Other familiars follow it#Stops moving when Isaac shoots#Teleports back to Isaac when he stops shooting"}, -- King Baby
	{"473", "Big Chubby", "Very slowly charges forwards#Blocks shots#Deals 40.5 contact damage per second"}, -- Big Chubby
	{"474", "Tonsil", "Blocks enemy projectiles"}, -- Tonsil
	{"475", "Plan C", "Deals 9,999,999 damage to all enemies#{{Warning}} Kills Isaac 3 seconds later"}, -- Plan C
	{"476", "D1", "Duplicates a random pickup in the room"}, -- D1
	{"477", "Void", "Consumes all pedestal items in the room#Active items: Their effects activate, and will activate with every future use of Void#↑ Passive items grant two random stat ups"}, -- Void
	{"478", "Pause", "Pauses all enemies in the room until Isaac shoots#Touching a paused enemy still deals damage to Isaac#Enemies unpause after 30 seconds"}, -- Pause
	{"479", "Smelter", "{{Trinket}} Consumes Isaac's held trinkets and grants their effects permanently#Increases the spawn rate of trinkets"}, -- Smelter
	{"480", "Compost", "Converts pickups into blue flies or spiders#Doubles all blue flies and spiders#Spawns 1 blue fly or spider if Isaac has none"}, -- Compost
	{"481", "Dataminer", "↑ Random stat up#↓ Random stat down#{{Timer}} Random tear effects for the room#{{Blank}} Corrupts all sprites and music in the room"}, -- Dataminer
	{"482", "Clicker", "Changes your character to a random character#Removes the most recent item collected"}, -- Clicker
	{"483", "Mama Mega!", "Affects the whole floor#Explodes all objects#Deals 200 damage to all enemies#Opens secret rooms#Opens Boss Rush and Hush regardless of time"}, -- Mama Mega!
	{"484", "Wait What?", "Upon use, pushes enemies away and spawns a rock wave around Isaac#The rock wave can open rooms and break rocks"}, -- Wait What?
	{"485", "Crooked Penny", "50% chance to double all items, pickups and chests in room#50% chance to remove items / pickups in room and spawn 1 coin"}, -- Crooked Penny
	{"486", "Dull Razor", "Hurts Isaac without removing health#Triggers any on-hit item effects"}, -- Dull Razor
	{"487", "Potato Peeler", "{{EmptyHeart}} Removes 1 heart container for:#↑ {{Damage}} +0.2 Damage#{{Collectible73}} A Cube of Meat#{{Timer}} Receive for the room:#↑ {{Range}} +5 Range#{{Collectible214}} Leave a trail of blood creep"}, -- Potato Peeler
	{"488", "Metronome", "Grants a random item effect for the room"}, -- Metronome
	{"489", "D Infinity", "Triggers a random dice effect each use"}, -- D Infinity
	{"490", "Eden's Soul", "Spawns 2 random items depending on the current room's item pool#Starts with no charges"}, -- Eden's Soul
	{"491", "Acid Baby", "{{Pill}} Spawns a random pill every 3 rooms#{{Poison}} Using a pill poisons all enemies in the room"}, -- Acid Baby
	{"492", "YO LISTEN!", "↑ {{Luck}} +1 Luck#Highlights the location of {{SecretRoom}} secret rooms, tinted rocks and {{LadderRoom}} crawlspaces"}, -- YO LISTEN!
	{"493", "Adrenaline", "For every empty heart container:#↑ {{Damage}} +0.2 Damage"}, -- Adrenaline
	{"494", "Jacob's Ladder", "Tears spawn 1-2 sparks of electricity on impact#Sparks deal half of Isaac's damage"}, -- Jacob's Ladder
	{"495", "Ghost Pepper", "Chance to shoot a red flame that blocks enemy shots and deals contact damage#The flame disappears after dealing damage or blocking shots 5 times"}, -- Ghost Pepper
	{"496", "Euthanasia", "3.33% chance to shoot a needle#{{Luck}} 100% chance at 15 luck#Needles kill normal enemies instantly, bursting them into 10 tears#{{Damage}} Needles deal 3x Isaac's damage against bosses"}, -- Euthanasia
	{"497", "Camo Undies", "{{Confusion}} Entering a room confuses all enemies until Isaac starts shooting"}, -- Camo Undies
	{"498", "Duality", "{{AngelDevilChance}} Spawns both a Devil and Angel Room if either would have spawned#Entering one makes the other disappear"}, -- Duality
	{"499", "Eucharist", "{{AngelChance}} 100% chance for Angel Rooms to spawn"}, -- Eucharist
	{"500", "Sack of Sacks", "Spawns a sack every 5-6 rooms"}, -- Sack of Sacks
	{"501", "Greed's Gullet", "{{Heart}} +1 Heart container for every 25 coins gained after getting Greed's Gullet"}, -- Greed's Gullet
	{"502", "Large Zit", "{{Slow}} Firing occasionally shoots a white creep tear that deals double damage and slows enemies#Taking damage shoots a white creep tear"}, -- Large Zit
	{"503", "Little Horn", "5% chance to shoot tears that instantly kill enemies#{{Luck}} 20% chance at 15 luck#Isaac deals 3.5 contact damage"}, -- Little Horn
	{"504", "Brown Nugget", "Spawns a fly turret that shoots at enemies#Each shot deals 2 damage"}, -- Brown Nugget
	{"505", "Poke Go", "Entering a hostile room has a chance to spawn a charmed enemy"}, -- Poke Go
	{"506", "Backstabber", "{{BleedingOut}} Hitting an enemy in the back deals double damage and causes bleeding, which deals 10% damage of the enemy's max health every 5 seconds"}, -- Backstabber
	{"507", "Sharp Straw", "{{Damage}} Deals Isaac's damage + 10% of the enemy's max health to all enemies#{{HalfHeart}} Dealing damage with the Straw can spawn half hearts#{{HalfSoulHeart}} Having no heart containers drops Soul Hearts instead"}, -- Sharp Straw
	{"508", "Mom's Razor", "{{BleedingOut}} Orbital that causes bleeding, which deals 10% damage of the enemy's max health every 5 seconds#{{Damage}} Deals 3x Isaac's damage per second#Does not block shots"}, -- Mom's Razor
	{"509", "Bloodshot Eye", "Orbital that shoots a tear in a random direction every 2 seconds#Deals 3.5 damage per tear#Deals 30 contact damage per second#Does not block shots"}, -- Bloodshot Eye
	{"510", "Delirious", "{{Timer}} Spawns a friendly delirium version of a boss for the room"}, -- Delirious
	{"511", "Angry Fly", "Orbits a random enemy until that enemy dies#Deals 30 contact damage per second to other enemies"}, -- Angry Fly
	{"512", "Black Hole", "Throwable black hole, which sucks in everything#Deals 6 damage per second#Destroys nearby rocks#Lasts 6 seconds"}, -- Black Hole
	{"513", "Bozo", "↑ {{Damage}} +0.1 Damage#{{SoulHeart}} +1 Soul Heart#{{Charm}} Randomly charms/fears enemies#Taking damage has a random chance to spawn a Rainbow Poop"}, -- Bozo
	{"514", "Broken Modem", "Causes some enemies and projectiles to briefly pause at random intervals#25% chance to double room clear drops"}, -- Broken Modem
	{"515", "Mystery Gift", "Spawns a random item from the current room's item pool#Chance to spawn Lump of Coal or The Poop instead"}, -- Mystery Gift
	{"516", "Sprinkler", "Spawns a Sprinkler that shoots the same tears as Isaac in a circle around itself"}, -- Sprinkler
	{"517", "Fast Bombs", "{{Bomb}} +7 Bombs#Removes the delay between bomb placements"}, -- Fast Bombs
	{"518", "Buddy in a Box", "Familiar which looks like a random co-op baby#Has random tear effects#Effects change every floor"}, -- Buddy in a Box
	{"519", "Lil Delirium", "Transforms into a random familiar every 10 seconds"}, -- Lil Delirium
	{"520", "Jumper Cables", "Killing 15 enemies adds 1 charge to the active item"}, -- Jumper Cables
	{"521", "Coupon", "Makes one random item in the {{Shop}} Shop or {{DevilRoom}} Devil Room free#Holding the item guarantees one Shop item is on sale"}, -- Coupon
	{"522", "Telekinesis", "Stops all enemy projectiles that come close to Isaac for 3 seconds and throws them away from him afterwards"}, -- Telekinesis
	{"523", "Moving Box", "Stores all pickups and items from the current room#Using the item again drops everything back on the floor#Allows Isaac to move things between rooms"}, -- Moving Box
	{"524", "Technology Zero", "Isaac's tears are connected with beams of electricity#The beams deal Isaac's damage"}, -- Technology Zero
	{"525", "Leprosy", "Taking damage spawns a projectile blocking orbital#Caps at 3 orbitals#They deal 35 contact damage per second#Orbitals are destroyed if they take too much damage"}, -- Leprosy
	{"526", "7 Seals", "Spawns a small horseman familiar that spawns locusts#The horseman and its locust changes every 10 seconds"}, -- 7 Seals
	{"527", "Mr. ME!", "Displays a movable cursor for a few seconds, then summons a ghost that will, depending on the cursor position:#Open doors or chests#Fetch an item#50% chance to steal from the Shop / Devil#Attack an enemy until it dies#Explode walls, rocks, shopkeepers, angel statues, machines, beggars"}, -- Mr. ME!
	{"528", "Angelic Prism", "Orbital prism#Friendly tears hitting it split into 4"}, -- Angelic Prism
	{"529", "Pop!", "Isaac's tears bounce off each other and disappear when they stop moving"}, -- Pop!
	{"530", "Death's List", "Killing enemies in the order dictated by the mark {{DeathMark}} above them grants a random pickup or stat increase"}, -- Death's List
	{"531", "Haemolacria", "↑ {{Damage}} x1.31 Damage multiplier#↓ {{Tears}} x0.5 Tears multiplier#↓ {{Tears}} +10 Tear delay#Isaac's tears fly in an arc and burst into smaller tears on impact"}, -- Haemolacria
	{"532", "Lachryphagy", "Isaac's tears progressively slow down, stop, then explode into 8 smaller tears#Tears can merge and become bigger"}, -- Lachryphagy
	{"533", "Trisagion", "Replaces Isaac's tears with piercing beams of light#The beams deal 33% damage but can hit enemies multiple times"}, -- Trisagion
	{"534", "Schoolbag", "Allows Isaac to hold 2 active items#The items can be swapped using the Drop button ({{ButtonRT}})"}, -- Schoolbag
	{"535", "Blanket", "{{Heart}} Heals 1 heart#{{SoulHeart}} +1 Soul Heart#{{HolyMantle}} Entering a boss room grants a Holy Mantle shield (prevents damage once)"}, -- Blanket
	{"536", "Sacrificial Altar", "Sacrifices up to 2 familiars and spawns a devil item for each sacrifice#{{Coin}} Turns blue spiders/flies into coins"}, -- Sacrificial Altar
	{"537", "Lil Spewer", "{{Pill}} Spawns a random pill on pickup#Fires a line of creep#The type of creep changes with each pill use"}, -- Lil Spewer
	{"538", "Marbles", "{{Trinket}} Spawns 3 random trinkets#{{Collectible479}} Taking damage has a 10% chance to consume Isaac's held trinket and grant its effects permanently"}, -- Marbles
	{"539", "Mystery Egg", "Taking damage spawns a charmed enemy#Spawns stronger friends the more rooms are cleared without taking damage"}, -- Mystery Egg
	{"540", "Flat Stone", "Isaac's tears bounce off the floor and cause splash damage on every bounce"}, -- Flat Stone
	{"541", "Marrow", "{{Heart}} Spawns 3 Red Hearts#{{EmptyBoneHeart}} +1 Bone Heart"}, -- Marrow
	{"542", "Slipped Rib", "Orbital#Reflects enemy projectiles"}, -- Slipped Rib
	{"543", "Hallowed Ground", "Taking damage spawns a white poop#While inside the poop's aura:#↑ {{Tears}} x2 Tears multiplier#Chance to block damage"}, -- Hallowed Ground
	{"544", "Pointy Rib", "Levitates in front of Isaac#Deals 6x Isaac's damage per second"}, -- Pointy Rib
	{"545", "Book of the Dead", "Spawns a bone orbital or charmed bony per enemy killed in the room (up to 8)"}, -- Book of the Dead
	{"546", "Dad's Ring", "Grants an aura that petrifies enemies"}, -- Dad's Ring
	{"547", "Divorce Papers", "↑ {{Tears}} +0.7 Tears#{{EmptyBoneHeart}} +1 Bone Heart#{{Trinket21}} Spawns the Mysterious Paper trinket"}, -- Divorce Papers
	{"548", "Jaw Bone", "Boomerang-like familiar#Deals 7 contact damage#Can grab and bring back pickups"}, -- Jaw Bone
	{"549", "Brittle Bones", "{{EmptyBoneHeart}} Replaces all of Isaac's Red Heart containers with 6 empty Bone Hearts#Upon losing a Bone Heart:#↑ {{Tears}} +0.5 Tears#Shoots 8 bone tears in all directions"}, -- Brittle Bones
	{"550", "Broken Shovel", "Mom's Foot constantly tries to stomp Isaac#Using the item stops the stomping for the room (or one Boss Rush wave)#{{Warning}} (Try to beat Boss Rush with it!)"}, -- Broken Shovel
	{"551", "Broken Shovel", "Completes Mom's Shovel#{{Warning}} Use the shovel on the mound of dirt in the \"Dark Room\""}, -- Broken Shovel
	{"552", "Mom's Shovel", "Spawns a trapdoor to the next floor#10% chance for {{LadderRoom}} crawlspace trapdoor#{{Warning}} Use the shovel on the mound of dirt in the \"Dark Room\""}, -- Mom's Shovel
}
local descriptionsOfTrinkets = {
{"1", "Swallowed Penny", "{{Coin}} Taking damage spawns 1 coin"}, -- Swallowed Penny
	{"2", "Petrified Poop", "50% chance to get drops from poop"}, -- Petrified Poop
	{"3", "AAA Battery", "{{Battery}} -1 Charge needed for active items"}, -- AAA Battery
	{"4", "Broken Remote", "{{Collectible44}} Using an active item teleports Isaac to a random room"}, -- Broken Remote
	{"5", "Purple Heart", "2x chance for champion enemies"}, -- Purple Heart
	{"6", "Broken Magnet", "{{Coin}} Attracts coins to Isaac"}, -- Broken Magnet
	{"7", "Rosary Bead", "{{AngelChance}} 50% higher Angel Room chance#{{Collectible33}} Higher chance to find The Bible in {{Shop}} Shops and {{Library}} Libraries"}, -- Rosary Bead
	{"8", "Cartridge", "{{Timer}} 5% chance upon taking damage to receive for 6.5 seconds:#Invincibility#Isaac can't shoot but deals 40 contact damage per second#{{HealingRed}} Killing 2 enemies heals half a heart#{{Fear}} Fears all enemies in the room"}, -- Cartridge
	{"9", "Pulse Worm", "Isaac's tears pulsate#Affects tear hitbox"}, -- Pulse Worm
	{"10", "Wiggle Worm", "↑ {{Tears}} +0.3 Tears#Isaac's tears move in waves"}, -- Wiggle Worm
	{"11", "Ring Worm", "Isaac's tears move in spirals with high speed"}, -- Ring Worm
	{"12", "Flat Worm", "50% wider tears#Increases knockback"}, -- Flat Worm
	{"13", "Store Credit", "{{Shop}} Allows Isaac to take 1 Shop item for free"}, -- Store Credit
	{"14", "Callus", "Immune to creep and floor spikes"}, -- Callus
	{"15", "Lucky Rock", "{{Coin}} Destroying rocks spawns coins"}, -- Lucky Rock
	{"16", "Mom's Toenail", "Mom's Foot stomps a random spot in the room every 60 seconds"}, -- Mom's Toenail
	{"17", "Black Lipstick", "{{BlackHeart}} +5% chance for random Soul Hearts to spawn as Black Hearts"}, -- Black Lipstick
	{"18", "Bible Tract", "{{EternalHeart}} +3% chance for Eternal Hearts"}, -- Bible Tract
	{"19", "Paper Clip", "{{GoldenChest}} Gold chests can be opened for free"}, -- Paper Clip
	{"20", "Monkey Paw", "{{BlackHeart}} Spawns 1 Black Heart when Isaac's health is reduced to half a heart#{{Warning}} Disappears after spawning 3 Black Hearts"}, -- Monkey Paw
	{"21", "Mysterious Paper", "Randomly grants the effect of: #{{Collectible327}} The Polaroid#{{Collectible328}} The Negative#{{Trinket48}} A Missing Page#{{Trinket23}} Missing Poster"}, -- Mysterious Paper
	{"22", "Daemon's Tail", "{{Heart}} Decreases spawn rate of hearts to 20%#{{BlackHeart}} All Heart pickups turn into Black Hearts#{{Key}} Increases the drop chance of keys"}, -- Daemon's Tail
	{"23", "Missing Poster", "{{Player10}} Respawn as The Lost on death"}, -- Missing Poster
	{"24", "Butt Penny", "{{Coin}} 20% higher chance for coins to spawn from poop#Picking up coins makes Isaac fart"}, -- Butt Penny
	{"25", "Mysterious Candy", "Isaac farts or spawns poop every 30 seconds"}, -- Mysterious Candy
	{"26", "Hook Worm", "↑ {{Range}} +10 Range#Isaac's tears move in angular patterns"}, -- Hook Worm
	{"27", "Whip Worm", "↑ {{Shotspeed}} +0.5 Shot speed"}, -- Whip Worm
	{"28", "Broken Ankh", "{{Player4}} 22% chance to respawn as ??? (Blue Baby) on death"}, -- Broken Ankh
	{"29", "Fish Head", "Taking damage spawns 1 blue fly"}, -- Fish Head
	{"30", "Pinky Eye", "{{Poison}} 10% chance to shoot poison tears#{{Luck}} 100% chance at 18 luck"}, -- Pinky Eye
	{"31", "Push Pin", "10% chance to shoot piercing + spectral tears#{{Luck}} 100% chance at 18 luck"}, -- Push Pin
	{"32", "Liberty Cap", "25% chance for a random mushroom effect per room#Can reveal special rooms on the minimap"}, -- Liberty Cap
	{"33", "Umbilical Cord", "{{Timer}} Spawns {{Collectible100}} Little Steven for the room when Isaac's health is reduced to half a heart"}, -- Umbilical Cord
	{"34", "Child's Heart", "{{UnknownHeart}} 10% chance for the room clear reward to be a random heart#{{Heart}} 33% chance for a bonus heart from chests, tinted rocks, and destroyed machines"}, -- Child's Heart
	{"35", "Curved Horn", "↑ {{Damage}} +2 Damage"}, -- Curved Horn
	{"36", "Rusted Key", "{{Key}} 10% chance for the room clear reward to be a key#{{Key}} 33% chance for a bonus key from chests, tinted rocks, and destroyed machines"}, -- Rusted Key
	{"37", "Goat Hoof", "↑ {{Speed}} +0.15 Speed"}, -- Goat Hoof
	{"38", "Mom's Pearl", "+10% chance for heart drops to be {{SoulHeart}} Soul Hearts, {{BlackHeart}} Black Hearts or {{EmptyBoneHeart}} Bone Hearts"}, -- Mom's Pearl
	{"39", "Cancer", "↑ {{Tears}} -2 Tear delay"}, -- Cancer
	{"40", "Red Patch", "{{Timer}} Taking damage has a 20% chance to grant ↑ {{Damage}} +1.8 damage for the room#{{Luck}} 100% chance at 8 luck"}, -- Red Patch
	{"41", "Match Stick", "{{Bomb}} 10% chance for the room clear reward to be a bomb#{{Bomb}} 33% chance for a bonus bomb from chests, tinted rocks, and destroyed machines#{{Warning}} Removes {{Trinket53}} Tick"}, -- Match Stick
	{"42", "Lucky Toe", "↑ {{Luck}} +1 Luck#+8% room clear reward chance#33% chance for an extra pickup from chests, tinted rocks, and destroyed machines"}, -- Lucky Toe
	{"43", "Cursed Skull", "When damaged down to half a heart or less, Isaac is teleported to a random room"}, -- Cursed Skull
	{"44", "Safety Cap", "{{Pill}} 10% chance for the room clear reward to be a pill#{{Pill}} 33% chance for a bonus pill from chests, tinted rocks, and destroyed machines"}, -- Safety Cap
	{"45", "Ace of Spades", "{{Card}} 10% chance for the room clear reward to be a card#{{Card}} 33% chance for a bonus card from chests, tinted rocks, and destroyed machines"}, -- Ace of Spades
	{"46", "Isaac's Fork", "{{HealingRed}} Clearing a room has a 10% chance to heal half a heart#{{Luck}} 100% chance at 18 luck"}, -- Isaac's Fork
	{"47", "", "<Item does not exist>"},
	{"48", "A Missing Page", "Taking damage has a 5% chance to deal 40 damage to all enemies in the room"}, -- A Missing Page
	{"49", "Bloody Penny", "{{HalfHeart}} Picking up a coin has a 50% chance to spawn a half Red Heart"}, -- Bloody Penny
	{"50", "Burnt Penny", "{{Bomb}} Picking up a coin has a 50% chance to spawn a bomb"}, -- Burnt Penny
	{"51", "Flat Penny", "{{Key}} Picking up a coin has a 50% chance to spawn a key"}, -- Flat Penny
	{"52", "Counterfeit Penny", "{{Coin}} Picking up a coin has a 50% chance to add another coin to the counter"}, -- Counterfeit Penny
	{"53", "Tick", "{{HealingRed}} Heals 1 heart when entering a {{BossRoom}} Boss Room#-15% boss health#{{Warning}} Once picked up, it can't be removed#Only removeable with {{Trinket41}} Match Stick or gulping"}, -- Tick
	{"54", "Isaac's Head", "Familiar with piercing tears#Deals 3.5 damage per tear"}, -- Isaac's Head
	{"55", "Maggy's Faith", "{{EternalHeart}} Entering a new floor grants +1 Eternal Heart"}, -- Maggy's Faith
	{"56", "Judas' Tongue", "{{DevilRoom}} Reduces all devil deal prices to 1 heart container#Doesn't reduce 3 Soul Heart prices"}, -- Judas' Tongue
	{"57", "???'s Soul", "Familiar that bounces around the room#Shoots in the same direction as Isaac#Deals 3.5 damage per tear"}, -- ???'s Soul
	{"58", "Samson's Lock", "{{Timer}} Killing an enemy has a 1/15 chance to grant ↑ {{Damage}} +0.5 damage for the room#{{Luck}} 100% chance at 10 luck"}, -- Samson's Lock
	{"59", "Cain's Eye", "Entering a new floor has a 25% chance to reveal map icons#{{Luck}} 100% chance at 3 luck"}, -- Cain's Eye
	{"60", "Eve's Bird Foot", "{{Collectible117}} Killing an enemy has a 5% chance to spawn a Dead Bird#{{Luck}} 100% chance at 8 luck"}, -- Eve's Bird Foot
	{"61", "The Left Hand", "{{RedChest}} Turns all chests into Red Chests"}, -- The Left Hand
	{"62", "Shiny Rock", "Crawlspace rocks and tinted rocks blink every 10 seconds"}, -- Shiny Rock
	{"63", "Safety Scissors", "{{Bomb}} Turns Troll Bombs into bomb pickups"}, -- Safety Scissors
	{"64", "Rainbow Worm", "Grants a random worm effect every 3 seconds"}, -- Rainbow Worm
	{"65", "Tape Worm", "↑ {{Range}} x2 Range multiplier#↓ x0.5 Tear height"}, -- Tape Worm
	{"66", "Lazy Worm", "↑ {{Range}} +4 Range#↑ +2 Tear height#↓ {{Shotspeed}} -0.4 Shot speed"}, -- Lazy Worm
	{"67", "Cracked Dice", "Taking damage has a 50% chance to trigger one of these effects:#{{Collectible105}} D6#{{Collectible406}} D8#{{Collectible386}} D12 #{{Collectible166}} D20"}, -- Cracked Dice
	{"68", "Super Magnet", "Isaac attracts pickups and enemies"}, -- Super Magnet
	{"69", "Faded Polaroid", "Randomly camouflages Isaac#{{Confusion}} Confuses enemies"}, -- Faded Polaroid
	{"70", "Louse", "Occasionally spawns a blue spider in hostile rooms"}, -- Louse
	{"71", "Bob's Bladder", "Isaac's bombs leave damaging creep"}, -- Bob's Bladder
	{"72", "Watch Battery", "{{Battery}} 6.66% chance for the room clear reward to be a battery#{{Battery}} +10% chance for random pickups to be a battery#{{Battery}} 5% chance to add 1 charge to held active item when clearing a room"}, -- Watch Battery
	{"73", "Blasting Cap", "{{Bomb}} 10% chance for exploding bombs to drop a bomb pickup"}, -- Blasting Cap
	{"74", "Stud Finder", "{{LadderRoom}} +0.5% chance to reveal a crawlspace when breaking a rock"}, -- Stud Finder
	{"75", "Error", "Grants a random trinket effect every room"}, -- Error
	{"76", "Poker Chip", "↑ 50% chance for chests to spawn extra pickups#↓ 50% chance for chests to contain a single fly"}, -- Poker Chip
	{"77", "Blister", "Increases knockback"}, -- Blister
	{"78", "Second Hand", "Status effects applied to enemies last twice as long"}, -- Second Hand
	{"79", "Endless Nameless", "Using a {{Rune}} rune, {{Card}} card or {{Pill}} pill has a 25% chance to spawn a copy of that rune, card or pill"}, -- Endless Nameless
	{"80", "Black Feather", "↑ {{Damage}} +0.2 Damage for each \"Evil up\" item held"}, -- Black Feather
	{"81", "Blind Rage", "Invincibility frames after taking damage last twice as long"}, -- Blind Rage
	{"82", "Golden Horse Shoe", "{{TreasureRoom}} Future Treasure Rooms have +15% chance to let Isaac choose between two items"}, -- Golden Horse Shoe
	{"83", "Store Key", "{{Shop}} Lets Isaac open Shops for free"}, -- Store Key
	{"84", "Rib of Greed", "{{Coin}} 5% more coins and fewer hearts from room clear rewards#Greed and Super Greed no longer appear in {{Shop}} Shops or {{SecretRoom}} Secret Rooms"}, -- Rib of Greed
	{"85", "Karma", "{{DonationMachine}} Using a Donation Machine has a 33% chance to:#{{HealingRed}} Heal 1 heart (40%)#{{Coin}} Give 1 coin (40%)#{{Luck}} Grant +1 luck (15%)#{{Beggar}} Spawn a Beggar (5%)"}, -- Karma
	{"86", "Lil Larva", "Destroying poop spawns 1 blue fly"}, -- Lil Larva
	{"87", "Mom's Locket", "{{HealingRed}} Using a key heals half a heart#{{Heart}} Turns half hearts into full hearts"}, -- Mom's Locket
	{"88", "NO!", "Prevents active items from spawning"}, -- NO!
	{"89", "Child Leash", "Familiars stay closer to Isaac"}, -- Child Leash
	{"90", "Brown Cap", "Poop explodes for 100 damage when destroyed"}, -- Brown Cap
	{"91", "Meconium", "33% chance for Black Poops to spawn#{{BlackHeart}} Destroying Black Poop has a 5% chance to spawn a Black Heart"}, -- Meconium
	{"92", "Cracked Crown", "↑ {{Tears}} x0.8 Tear delay#↑ x1.33 Stat multiplier for the stats that are above 1 {{Speed}} speed, 3.5 {{Damage}} damage, 23.75 {{Range}} range, 1 {{Shotspeed}} shot speed"}, -- Cracked Crown
	{"93", "Used Diaper", "15% chance per room for all fly enemies to become friendly"}, -- Used Diaper
	{"94", "Fish Tail", "Doubles all blue fly / spider spawns"}, -- Fish Tail
	{"95", "Black Tooth", "{{Poison}} 3% chance to shoot poison tooth tears#The tooth deals 2x Isaac's damage"}, -- Black Tooth
	{"96", "Ouroboros Worm", "↑ {{Range}} +4 Range#↑ +2 Tear height#Spectral tears#Chance for homing tears#{{Luck}} 100% chance at 9 luck#Isaac's tears move quickly in a spiral pattern"}, -- Ouroboros Worm
	{"97", "Tonsil", "Taking damage 12-20 times spawns a projectile blocking familiar#Caps at 2 familiars"}, -- Tonsil
	{"98", "Nose Goblin", "10% chance to shoot homing sticky tears#{{Damage}} Boogers deal Isaac's damage once per second#Boogers stick for 60 seconds"}, -- Nose Goblin
	{"99", "Super Ball", "10% chance to shoot bouncing tears"}, -- Super Ball
	{"100", "Vibrant Bulb", "Holding a fully charged active item grants:#↑ {{Speed}} +0.25 Speed#↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +0.5 Damage#↑ {{Range}} +0.75 Range#↑ {{Shotspeed}} +0.1 Shot speed#↑ {{Luck}} +1 Luck"}, -- Vibrant Bulb
	{"101", "Dim Bulb", "Holding a completely uncharged active item grants:#↑ {{Speed}} +0.5 Speed#↑ {{Tears}} +0.4 Tears#↑ {{Damage}} +1.5 Damage#↑ {{Range}} +1.5 Range#↑ {{Shotspeed}} +0.3 Shot speed#↑ {{Luck}} +2 Luck"}, -- Dim Bulb
	{"102", "Fragmented Card", "{{SecretRoom}} +1 extra Secret Room per floor while held"}, -- Fragmented Card
	{"103", "Equality!", "Turns single pickups into double pickups when Isaac's {{Coin}} coin, {{Bomb}} bomb and {{Key}} key counts are equal"}, -- Equality!
	{"104", "Wish Bone", "2% chance to get destroyed and spawn a pedestal item when hit"}, -- Wish Bone
	{"105", "Bag Lunch", "{{Collectible22}} 2% chance to get destroyed and spawn Lunch when hit"}, -- Bag Lunch
	{"106", "Lost Cork", "Increases the radius of friendly creep"}, -- Lost Cork
	{"107", "Crow Heart", "Taking damage depletes Red Hearts before Soul/Black Hearts#This red heart damage does not reduce Devil/Angel Room chances"}, -- Crow Heart
	{"108", "Walnut", "Getting hit by 1-9 explosions destroys the trinket and drops a random {{UnknownHeart}} heart, {{Coin}} coin, {{Key}} key and {{Trinket}} trinket#Taking damage isn't required"}, -- Walnut
	{"109", "Duct Tape", "Familiars are stuck in one spot and cannot move"}, -- Duct Tape
	{"110", "Silver Dollar", "{{Shop}} Shops appear in the Womb"}, -- Silver Dollar
	{"111", "Bloody Crown", "{{TreasureRoom}} Treasure Rooms appear in the Womb"}, -- Bloody Crown
	{"112", "Pay To Win", "{{RestockMachine}} Restock boxes always spawn in {{TreasureRoom}} Treasure Rooms"}, -- Pay To Win
	{"113", "Locust of War", "Entering a hostile room spawns an exploding attack fly #The fly deals 2x Isaac's damage + explosion damage"}, -- Locust of War
	{"114", "Locust of Pestilence", "{{Poison}} Entering a hostile room spawns a poison attack fly#The fly deals 2x Isaac's damage"}, -- Locust of Pestilence
	{"115", "Locust of Famine", "{{Slow}} Entering a hostile room spawns a slowing attack fly#The fly deals 2x Isaac's damage"}, -- Locust of Famine
	{"116", "Locust of Death", "Entering a hostile room spawns an attack fly#The fly deals 4x Isaac's damage"}, -- Locust of Death
	{"117", "Locust of Conquest", "Entering a hostile room spawns 1-4 attack flies#Each fly deals 2x Isaac's damage"}, -- Locust of Conquest
	{"118", "Bat Wing", "{{Timer}} Killing an enemy has a 5% chance to grant flight for the room"}, -- Bat Wing
	{"119", "Stem Cell", "{{HealingRed}} Entering a new floor heals half a heart"}, -- Stem Cell
	{"120", "Hairpin", "{{Battery}} Entering an uncleared boss room fully recharges active items"}, -- Hairpin
	{"121", "Wooden Cross", "{{Collectible313}} Negates the first damage taken on the floor"}, -- Wooden Cross
	{"122", "Butter!", "Using an active item drops it on a pedestal on the ground#Taking damage has a 2% chance to drop one of Isaac's passive items"}, -- Butter!
	{"123", "Filigree Feather", "Angel bosses drop angel items instead of Key Pieces"}, -- Filigree Feather
	{"124", "Door Stop", "The last door used stays open"}, -- Door Stop
	{"125", "Extension Cord", "Connects all familiars with beams of electricity#The beams deal 6 damage"}, -- Extension Cord
	{"126", "Rotten Penny", "Picking up a coin spawns a blue fly"}, -- Rotten Penny
	{"127", "Baby-Bender", "Grants all familiars homing shots"}, -- Baby-Bender
	{"128", "Finger Bone", "{{EmptyBoneHeart}} Taking damage has a 2% chance to grant a Bone Heart"}, -- Finger Bone
}
local descriptionsOfCards = {
{"1", "0 - The Fool", "Teleports Isaac to the first room of the floor"}, -- 0 - The Fool
	{"2", "I - The Magician", "{{Timer}} Homing tears for the room"}, -- I - The Magician
	{"3", "II - The High Priestess", "Mom's Foot stomps on an enemy#Mom's Foot stomps Isaac if there are no enemies"}, -- II - The High Priestess
	{"4", "III - The Empress", "{{Timer}} Receive for the room:#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +1.5 Damage"}, -- III - The Empress
	{"5", "IV - The Emperor", "{{BossRoom}} Teleports Isaac to the Boss Room"}, -- IV - The Emperor
	{"6", "V - The Hierophant", "{{SoulHeart}} Spawns 2 Soul Hearts"}, -- V - The Hierophant
	{"7", "VI - The Lovers", "{{Heart}} Spawns 2 Red Hearts"}, -- VI - The Lovers
	{"8", "VII - The Chariot", "{{Timer}} Receive for 6 seconds:#↑ {{Speed}} +0.28 Speed#Invincibility#Isaac can't shoot but deals 40 contact damage per second"}, -- VII - The Chariot
	{"9", "VIII - Justice", "Spawns a random {{UnknownHeart}} heart, {{Coin}} coin, {{Bomb}} bomb and {{Key}} key"}, -- VIII - Justice
	{"10", "IX - The Hermit", "{{Shop}} Teleports Isaac to the Shop"}, -- IX - The Hermit
	{"11", "X - Wheel of Fortune", "Spawns a {{Slotmachine}} Slot Machine or {{FortuneTeller}} Fortune Machine"}, -- X - Wheel of Fortune
	{"12", "XI - Strength", "{{Timer}} Receive for the room:#↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +0.3 Damage#↑ {{Damage}} x1.5 Damage multiplier#↑ {{Range}} +5.25 Range#↑ +0.5 Tear height"}, -- XI - Strength
	{"13", "XII - The Hanged Man", "{{Timer}} Flight for the room"}, -- XII - The Hanged Man
	{"14", "XIII - Death", "Deals 40 damage to all enemies in the room"}, -- XIII - Death
	{"15", "XIV - Temperance", "{{DonationMachine}} Spawns a Blood Donation Machine"}, -- XIV - Temperance
	{"16", "XV - The Devil", "{{Timer}} Receive for the room:#↑ {{Damage}} +2 Damage"}, -- XV - The Devil
	{"17", "XVI - The Tower", "Spawns 6 Troll Bombs"}, -- XVI - The Tower
	{"18", "XVII - The Stars", "{{TreasureRoom}} Teleports Isaac to the Treasure Room"}, -- XVII - The Stars
	{"19", "XVIII - The Moon", "{{SecretRoom}} Teleports Isaac to the Secret Room"}, -- XVIII - The Moon
	{"20", "XIX - The Sun", "{{HealingRed}} Full health#Deals 100 damage to all enemies#{{Timer}} Full mapping effect for the floor (except {{SuperSecretRoom}} Super Secret Room)"}, -- XIX - The Sun
	{"21", "XX - Judgement", "Spawns a Beggar or Devil Beggar#2% chance to spawn a special Beggar"}, -- XX - Judgement
	{"22", "XXI - The World", "{{Timer}} Full mapping effect for the floor (except {{SuperSecretRoom}} Super Secret Room)"}, -- XXI - The World
	{"23", "2 of Clubs", "{{Bomb}} Doubles Isaac's number of bombs"}, -- 2 of Clubs
	{"24", "2 of Diamonds", "{{Coin}} Doubles Isaac's number of coins"}, -- 2 of Diamonds
	{"25", "2 of Spades", "{{Key}} Doubles Isaac's number of keys"}, -- 2 of Spades
	{"26", "2 of Hearts", "{{HealingRed}} Doubles Isaac's number of Red Hearts {{ColorSilver}}(not containers){{CR}}"}, -- 2 of Hearts
	{"27", "Ace of Clubs", "{{Bomb}} Turns all pickups into random bombs"}, -- Ace of Clubs
	{"28", "Ace of Diamonds", "{{Coin}} Turns all pickups into random coins"}, -- Ace of Diamonds
	{"29", "Ace of Spades", "{{Key}} Turns all pickups into random keys"}, -- Ace of Spades
	{"30", "Ace of Hearts", "{{UnknownHeart}} Turns all pickups into random hearts"}, -- Ace of Hearts
	{"31", "Joker", "{{AngelDevilChance}} Teleports Isaac to the Devil or Angel Room"}, -- Joker
	{"32", "Hagalaz", "Destroy all rocks in the room"}, -- Hagalaz
	{"33", "Jera", "Duplicates all pickups in room"}, -- Jera
	{"34", "Ehwaz", "Spawns a trapdoor to the next floor#{{LadderRoom}} 8% chance for a crawlspace trapdoor"}, -- Ehwaz
	{"35", "Dagaz", "{{SoulHeart}} +1 Soul Heart#{{CurseCursed}} Removes all curses for the floor"}, -- Dagaz
	{"36", "Ansuz", "{{Timer}} Full mapping effect for the floor"}, -- Ansuz
	{"37", "Perthro", "Rerolls all pedestal items in the room"}, -- Perthro
	{"38", "Berkano", "Summons 3 blue spiders and 3 blue flies"}, -- Berkano
	{"39", "Algiz", "{{Timer}} Makes Isaac invincible for 30 seconds"}, -- Algiz
	{"40", "Blank Rune", "Triggers a random rune effect#25% chance to duplicate itself when used"}, -- Blank Rune
	{"41", "Black Rune", "Deals 40 damage to all enemies#Converts all pedestal items in the room into random stat ups#Converts all pickups in the room into blue flies"}, -- Black Rune
	{"42", "Chaos Card", "Using the card throws it in the direction Isaac is moving#Instantly kills ANY enemy it touches (except Delirium)"}, -- Chaos Card
	{"43", "Credit Card", "Makes all items and pickups in a {{Shop}} Shop or {{DevilRoom}} Devil Room free"}, -- Credit Card
	{"44", "Rules Card", "Displays \"helpful\" tips on use"}, -- Rules Card
	{"45", "A Card Against Humanity", "Fills the whole room with poop"}, -- A Card Against Humanity
	{"46", "Suicide King", "Instantly kills Isaac and spawns 10 pickups or items on the floor#Spawned items will use the current room's item pool"}, -- Suicide King
	{"47", "Get Out Of Jail Free Card", "Open all doors in the room"}, -- Get Out Of Jail Free Card
	{"48", "? Card", "Uses Isaac's active item for free"}, -- ? Card
	{"49", "Dice Shard", "Rerolls all item pedestals and pickups in the room"}, -- Dice Shard
	{"50", "Emergency Contact", "Two of Mom's Hands come down and grab an enemy each"}, -- Emergency Contact
	{"51", "Holy Card", "{{HolyMantle}} Holy Mantle shield for the room (prevents damage once)#25% chance to spawn another Holy Card"}, -- Holy Card
	{"52", "Huge Growth", "{{Timer}} Receive for the room:#↑ {{Damage}} +7 Damage#↑ {{Range}} +30 Range#Size up#Allows Isaac to destroy rocks by walking into them"}, -- Huge Growth
	{"53", "Ancient Recall", "{{Card}} Spawns 3 random cards"}, -- Ancient Recall
	{"54", "Era Walk", "{{Timer}} Receive for the room:#↑ {{Speed}} +0.5 Speed#↓ {{Shotspeed}} -1 Shot speed#{{Slow}} Slow down enemies"}, -- Era Walk
}
local descriptionsOfPills = {
	{"0", "Bad Gas", "{{Poison}} Isaac farts and poisons nearby enemies"}, -- Bad Gas
	{"1", "Bad Trip", "{{Warning}} Deals 1 heart of damage to Isaac#Becomes a Full Health pill at 1 heart or less"}, -- Bad Trip
	{"2", "Balls of Steel", "{{SoulHeart}} +2 Soul Hearts"}, -- Balls of Steel
	{"3", "Bombs are Key", "Swaps Isaac's number of {{Bomb}} bombs and {{Key}} keys"}, -- Bombs are Key
	{"4", "Explosive Diarrhea", "Isaac quickly spawns 5 lit bombs"}, -- Explosive Diarrhea
	{"5", "Full Health", "{{HealingRed}} Fully heals all heart containers"}, -- Full Health
	{"6", "Health Down", "↓ {{EmptyHeart}} -1 Health#Becomes a Health Up pill at 0 or 1 heart containers"}, -- Health Down
	{"7", "Health Up", "↑ {{EmptyHeart}} +1 Empty heart container"}, -- Health Up
	{"8", "I Found Pills", "No effect"}, -- I Found Pills
	{"9", "Puberty", "No effect#Eating 3 grants the Adult transformation:#↑ {{Heart}} +1 Health"}, -- Puberty
	{"10", "Pretty Fly", "+1 Fly orbital"}, -- Pretty Fly
	{"11", "Range Down", "↓ {{Range}} -2 Range"}, -- Range Down
	{"12", "Range Up", "↑ {{Range}} +2.5 Range"}, -- Range Up
	{"13", "Speed Down", "↓ {{Speed}} -0.12 Speed"}, -- Speed Down
	{"14", "Speed Up", "↑ {{Speed}} +0.15 Speed"}, -- Speed Up
	{"15", "Tears Down", "↓ {{Tears}} -0.28 Tears"}, -- Tears Down
	{"16", "Tears Up", "↑ {{Tears}} +0.35 Tears"}, -- Tears Up
	{"17", "Luck Down", "↓ {{Luck}} -1 Luck"}, -- Luck Down
	{"18", "Luck Up", "↑ {{Luck}} +1 Luck"}, -- Luck Up
	{"19", "Telepills", "Teleports Isaac to a random room#{{ErrorRoom}} Small chance to teleport Isaac to the I AM ERROR room"}, -- Telepills
	{"20", "48 Hour Energy!", "{{Battery}} Fully recharges the active item#{{Battery}} Spawns 1-2 batteries"}, -- 48 Hour Energy!
	{"21", "Hematemesis", "{{Warning}} Drains all but one heart container#{{Heart}} Spawns 1-4 Red Hearts"}, -- Hematemesis
	{"22", "Paralysis", "Prevents Isaac from moving and shooting for 2 seconds"}, -- Paralysis
	{"23", "I can see forever!", "{{SecretRoom}} Opens all secret room entrances on the floor"}, -- I can see forever!
	{"24", "Pheromones", "{{Charm}} Charms all enemies in the room"}, -- Pheromones
	{"25", "Amnesia", "{{CurseLost}} Hides the map for the floor"}, -- Amnesia
	{"26", "Lemon Party", "Spawns a large puddle on the ground which damages enemies"}, -- Lemon Party
	{"27", "R U A Wizard?", "{{Timer}} Isaac shoots diagonally for 30 seconds"}, -- R U A Wizard?
	{"28", "Percs!", "{{Timer}} Reduces all damage taken to half a heart for the room"}, -- Percs!
	{"29", "Addicted!", "{{Timer}} Increases all damage taken to a full heart for the room"}, -- Addicted!
	{"30", "Re-Lax", "Isaac spawns poop behind him for 2 seconds"}, -- Re-Lax
	{"31", "???", "{{CurseMaze}} Curse of the Maze effect for the floor"}, -- ???
	{"32", "One makes you larger", "Increases Isaac's size#Doesn't affect his hitbox"}, -- One makes you larger
	{"33", "One makes you small", "Decreases Isaac's size#Also decreases his hitbox"}, -- One makes you small
	{"34", "Infested!", "Spawns 1 blue spider for each poop in the room"}, -- Infested!
	{"35", "Infested?", "Spawn 1 blue spider for each enemy in the room#Spawns 1-3 blue spiders if there are no enemies in the room"}, -- Infested?
	{"36", "Power Pill!", "{{Timer}} Receive for 6.5 seconds:#Invincibility#Isaac can't shoot but deals 40 contact damage per second#{{HealingRed}} Killing 2 enemies heals half a heart#{{Fear}} Fears all enemies in the room"}, -- Power Pill!
	{"37", "Retro Vision", "{{Timer}} Pixelates the screen 3 times over 30 second"}, -- Retro Vision
	{"38", "Friends Till The End!", "Spawns 3 blue flies"}, -- Friends Till The End!
	{"39", "X-Lax", "Spawns a pool of slippery creep"}, -- X-Lax
	{"40", "Something's wrong...", "{{Slow}} Spawns a pool of slowing creep"}, -- Something's wrong...
	{"41", "I'm Drowsy...", "{{Slow}} Slows all enemies in the room"}, -- I'm Drowsy...
	{"42", "I'm Excited!!", "Speeds up all enemies in the room"}, -- I'm Excited!!
	{"43", "Gulp!", "{{Trinket}} Consumes Isaac's trinket and grants its effects permanently"}, -- Gulp!
	{"44", "Horf!", "{{Collectible149}} Shoots one Ipecac tear"}, -- Horf!
	{"45", "Feels like I'm walking on sunshine!", "{{Timer}} Receive for 6 seconds:#Invincibility#Isaac can't shoot (No contact damage)"}, -- Feels like I'm walking on sunshine!
	{"46", "Vurp!", "Spawns the last pill used before Vurp!"}, -- Vurp!
}

--these for repent
local repCollectibles = {
	[2] = {"2", "The Inner Eye", "↓ {{Tears}} x0.51 Fire rate multiplier#Isaac shoots 3 tears at once"}, -- The Inner Eye
	[5] = {"5", "My Reflection", "↑ {{Damage}} +1.5 Damage#↑ {{Range}} +1.5 Range#↑ {{Range}} x2 Range multiplier#↑ {{Shotspeed}} x1.6 Shot speed multiplier#↓ {{Luck}} -1 Luck#Tears get a boomerang effect"}, -- My Reflection
	[6] = {"6", "Number One", "↑ {{Tears}} +1.5 Tears#↓ {{Range}} -1.5 Range#↓ {{Range}} x0.8 Range multiplier"}, -- Number One
	[12] = {"12", "Magic Mushroom", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +0.3 Damage#↑ {{Damage}} x1.5 Damage multiplier#↑ {{Range}} +2.5 Range#Size up#{{HealingRed}} Full health"}, -- Magic Mushroom
	[13] = {"13", "The Virus", "↑ {{Speed}} +0.2 Speed#{{Poison}} Touching enemies poisons them#Isaac deals 48 contact damage per second"}, -- The Virus
	[14] = {"14", "Roid Rage", "↑ {{Speed}} +0.3 Speed#↑ {{Range}} +2.5 Range"}, -- Roid Rage
	[18] = {"18", "A Dollar", "{{Coin}} +100 Coins"}, -- A Dollar
	[22] = {"22", "Lunch", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Lunch
	[23] = {"23", "Dinner", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Dinner
	[24] = {"24", "Dessert", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Dessert
	[25] = {"25", "Breakfast", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Breakfast
	[26] = {"26", "Rotten Meat", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Rotten Meat
	[29] = {"29", "Mom's Underwear", "↑ {{Range}} +2.5 Range#Spawns 3-6 blue flies"}, -- Mom's Underwear
	[30] = {"30", "Mom's Heels", "↑ {{Range}} +2.5 Range#Isaac deals 24 contact damage per second"}, -- Mom's Heels
	[31] = {"31", "Mom's Lipstick", "↑ {{Range}} +3.75 Range#{{UnknownHeart}} Spawns 1 random heart"}, -- Mom's Lipstick
	[37] = {"37", "Mr. Boom", "Drops a large bomb below Isaac which deals 185 damage"}, -- Mr. Boom
	[40] = {"40", "Kamikaze!", "Causes a big explosion at Isaac's location#Deals 185 damage"}, -- Kamikaze!
	[41] = {"41", "Mom's Pad", "{{Fear}} Fears all enemies in the room for 5 seconds#Spawns a blue fly"}, -- Mom's Pad
	[42] = {"42", "Bob's Rotten Head", "Using the item and firing in a direction throws the head#{{Poison}} The head explodes where it lands and creates a poison cloud#Deals Isaac's damage + 185"}, -- Bob's Rotten Head
	[46] = {"46", "Lucky Foot", "↑ {{Luck}} +1 Luck#Better chance to win while gambling#Increases room clearing drop chance#Turns bad pills into good ones"}, -- Lucky Foot
	[49] = {"49", "Shoop da Whoop!", "The next shot is replaced with a beam#It deals 24x Isaac's damage over 0.83 seconds"}, -- Shoop da Whoop!
	[52] = {"52", "Dr. Fetus", "↓ {{Tears}} x0.4 Fire rate multiplier#{{Bomb}} Isaac shoots bombs instead of tears#{{Damage}} Those bombs deal 10x Isaac's tear damage#If that results in over 60 damage, they instead deal 5x damage +30"}, -- Dr. Fetus
	[53] = {"53", "Magneto", "Pickups are attracted to Isaac#Opens chests from 2 tiles away, ignoring damage of Spike Chests"}, -- Magneto
	[55] = {"55", "Mom's Eye", "50% chance to shoot an extra tear backwards#{{Luck}} 100% chance at 5 luck"}, -- Mom's Eye
	[59] = {"59", "The Book of Belial", "{{AngelDevilChance}} +12.5% Devil/Angel Room chance while held#{{Timer}} Receive for the room:#↑ {{Damage}} +2 Damage"}, -- The Book of Belial (Judas' Birthright)
	[62] = {"62", "Charm of the Vampire", "↑ {{Damage}} +0.3 Damage#{{HealingRed}} Killing 13 enemies heals half a heart"}, -- Charm of the Vampire
	[67] = {"67", "Sister Maggy", "Shoots normal tears#Deals 6 damage per tear"}, -- Sister Maggy
	[69] = {"69", "Chocolate Milk", "{{Chargeable}} Chargeable tears#{{Damage}} Damage scales with charge time, up to 4x"}, -- Chocolate Milk
	[70] = {"70", "Growth Hormones", "↑ {{Speed}} +0.2 Speed#↑ {{Damage}} +1 Damage"}, -- Growth Hormones
	[71] = {"71", "Mini Mush", "↑ {{Speed}} +0.3 Speed#↑ {{Range}} +2.5 Range#↑ Size down"}, -- Mini Mush
	[72] = {"72", "Rosary", "↑ {{Tears}} +0.5 Tears#{{SoulHeart}} +3 Soul Hearts#{{Collectible33}} The Bible is added to all item pools"}, -- Rosary
	[78] = {"78", "Book of Revelations", "{{SoulHeart}} +1 Soul Heart#{{AngelDevilChance}} +17.5% Devil/Angel Room chance while held#Using the item replaces the floor's boss with a horseman"}, -- Book of Revelations
	[79] = {"79", "The Mark", "↑ {{Speed}} +0.2 Speed#↑ {{Damage}} +1 Damage#{{BlackHeart}} +1 Black Heart"}, -- The Mark
	[80] = {"80", "The Pact", "↑ {{Tears}} +0.7 Tears#↑ {{Damage}} +0.5 Damage#{{BlackHeart}} +2 Black Hearts"}, -- The Pact
	[83] = {"83", "The Nail", "Upon use:#{{HalfBlackHeart}} + Half Black Heart#{{Timer}} Receive for the room:#↑ {{Damage}} +2 Damage#↓ {{Speed}} -0.18 Speed#Isaac deals 40 contact damage per second#Allows Isaac to destroy rocks by walking into them"}, -- The Nail
	[84] = {"84", "We Need To Go Deeper!", "Opens a trapdoor to the next floor#{{LadderRoom}} Opens a crawlspace if used on a decorative floor tile (grass, small rocks, papers, gems, etc.)"}, -- We Need To Go Deeper!
	[87] = {"87", "Loki's Horns", "25% chance to shoot in 4 directions#{{Luck}} 100% chance at 15 luck"}, -- Loki's Horns
	[91] = {"91", "Spelunker Hat", "Rooms on the map are revealed from further away#{{SecretRoom}} Can also reveal Secret and Super Secret Rooms#Prevents damage from falling projectiles"}, -- Spelunker Hat
	[98] = {"98", "The Relic", "{{SoulHeart}} Spawns 1 Soul Heart every 7-8 rooms"}, -- The Relic
	[101] = {"101", "The Halo", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +0.3 Damage#↑ {{Range}} +1.5 Range#{{HealingRed}} Heals 1 heart"}, -- The Halo
	[106] = {"106", "Mr. Mega", "↑ x1.85 Bomb damage#{{Bomb}} +5 Bombs"}, -- Mr. Mega
	[107] = {"107", "The Pinking Shears", "{{Timer}} Receive for the room:#Flight#Isaac's body separates from his head and attacks enemies with 23.5 contact damage per second"}, -- The Pinking Shears
	[110] = {"110", "Mom's Contacts", "↑ {{Range}} +1.5 Range#20% chance to shoot petrifying tears#{{Luck}} 50% chance at 20 luck"}, -- Mom's Contacts
	[114] = {"114", "Mom's Knife", "Isaac's tears are replaced by a throwable knife#{{Damage}} The knife deals 2x Isaac's damage while held and caps at 6x damage at 1/3 charge#Charging further only increases throwing range#Damage reduces to 2x when returning to Isaac"}, -- Mom's Knife
	[115] = {"115", "Ouija Board", "↑ {{Tears}} +0.5 Tears#Spectral tears"}, -- Ouija Board
	[118] = {"118", "Brimstone", "↓ {{Tears}} x0.33 Fire rate multiplier#{{Chargeable}} Isaac's tears are replaced by a chargeable blood beam#{{Damage}} It deals 9x Isaac's damage over 0.63 seconds"}, -- Brimstone
	[121] = {"121", "Odd Mushroom (Large)", "↑ {{Heart}} +1 Health#↑ {{Damage}} +1 Damage#↑ {{Range}} +1.5 Range#↓ {{Speed}} -0.2 Speed"}, -- Odd Mushroom (Large)
	[123] = {"123", "Monster Manual", "{{Timer}} Spawns a random familiar for the floor"}, -- Monster Manual
	[126] = {"126", "Razor Blade", "↑ {{Damage}} +1.2 Damage for the room#{{Warning}} Deals 1 heart of damage to Isaac#After the first use in a room, deals half a heart instead#{{Heart}} Removes Red Hearts first"}, -- Razor Blade
	[129] = {"129", "Bucket of Lard", "↑ {{Heart}} +2 Health#↓ {{Speed}} -0.2 Speed"}, -- Bucket of Lard
	[138] = {"138", "Stigmata", "↑ {{Heart}} +1 Health#↑ {{Damage}} +0.3 Damage#{{HealingRed}} Heals 1 heart"}, -- Stigmata
	[139] = {"139", "Mom's Purse", "{{Trinket}} Spawns 1 random trinket#{{Trinket}} Isaac can hold 2 trinkets"}, -- Mom's Purse
	[140] = {"140", "Bob's Curse", "{{Bomb}} +5 Bombs#{{Poison}} Isaac's bombs create a cloud of poison#{{Poison}} Poison immunity"}, -- Bob's Curse
	[142] = {"142", "Scapular", "{{SoulHeart}} Isaac gains 1 Soul Heart when damaged down to half a heart#Can only happen once per room#Exiting and re-entering the room allows the effect to trigger again#{{Warning}} Doesn't trigger from health donations"}, -- Scapular
	[147] = {"147", "Notched Axe", "Using the item makes Isaac hold the axe#Holding the axe allows Isaac to break rocks, secret room entrances and damage enemies#Landing a hit with the axe reduces its charge#Entering a new floor fully recharges the axe"}, -- Notched Axe
	[148] = {"148", "Infestation", "Taking damage spawns 2-6 blue flies"}, -- Infestation
	[149] = {"149", "Ipecac", "↑ {{Damage}} +40 Damage#↓ {{Tears}} x0.33 Fire rate multiplier#↓ {{Range}} x0.8 Range multiplier#↓ {{Shotspeed}} -0.2 Shot speed#Isaac's tears are fired in an arc#{{Poison}} The tears explode and poison enemies where they land"}, -- Ipecac
	[152] = {"152", "Technology 2", "↓ {{Tears}} x0.67 Fire rate multiplier#Replaces Isaac's right eye tears with a continuous laser#{{Damage}} The laser deals 2x Isaac's damage per second"}, -- Technology 2
	[153] = {"153", "Mutant Spider", "↓ {{Tears}} x0.42 Fire rate multiplier#Isaac shoots 4 tears at once"}, -- Mutant Spider
	[155] = {"155", "The Peeper", "↑ {{Damage}} x1.35 Damage multiplier for the left eye#Floats around the room#Deals 17.1 contact damage per second"}, -- The Peeper
	[158] = {"158", "Crystal Ball", "Spawns a {{SoulHeart}} Soul Heart, {{Rune}} rune or {{Card}} card#{{Timer}} Full mapping effect for the floor (except {{SuperSecretRoom}} Super Secret Room)#While held:#{{PlanetariumChance}} +15% Planetarium chance#{{PlanetariumChance}} +100% if a {{TreasureRoom}} Treasure Room was skipped"}, -- Crystal Ball
	[169] =	{"169", "Polyphemus", "↑ {{Damage}} +4 Damage#↑ {{Damage}} x2 Damage multiplier#↓ {{Tears}} x0.42 Fire rate multiplier#Tears pierce killed enemies if there is leftover damage"}, -- Polyphemus
	[171] = {"171", "Spider Butt", "{{Slow}} Slows down enemies for 4 seconds#Deals 10 damage to all enemies#Enemies killed by the item spawn blue spiders"}, -- Spider Butt
	[172] = {"172", "Sacrificial Dagger", "Orbital#Blocks enemy shots#Deals 112.5 contact damage per second"}, -- Sacrificial Dagger
	[173] = {"173", "Mitre", "{{SoulHeart}} 33% chance that Red Hearts spawn as Soul Hearts instead"}, -- Mitre
	[176] = {"176", "Stem Cells", "↑ {{Heart}} +1 Health#↑ {{Shotspeed}} +0.16 Shot speed#{{HealingRed}} Heals 1 heart"}, -- Stem Cells
	[178] = {"178", "Holy Water", "{{Throwable}} Launches itself in the direction Isaac shoots#Breaks and deals 7 damage upon hitting an enemy#Leaves a pool of petrifying + damaging creep"}, -- Holy Water
	[180] = {"180", "The Black Bean", "Isaac farts multiple times when damaged#{{Poison}} The farts leave poison clouds and deflects projectiles"}, -- The Black Bean
	[182] = {"182", "Sacred Heart", "↑ {{Heart}} +1 Health#↑ {{Damage}} x2.3 Damage multiplier#↑ {{Damage}} +1 Damage#↓ {{Tears}} -0.4 Tears#↓ {{Shotspeed}} -0.25 Shot speed#{{HealingRed}} Full health#Homing tears"}, -- Sacred Heart
	[184] = {"184", "Holy Grail", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#Flight"}, -- Holy Grail
	[186] = {"186", "Blood Rights", "Deals 40 damage to every enemy#{{Warning}} Deals 1 heart of damage to Isaac#After the first use in a room, deals half a heart instead#{{Heart}} Removes Red Hearts first"}, -- Blood Rights
	[189] = {"189", "SMB Super Fan", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.2 Speed#↑ {{Tears}} +0.2 Tears#↑ {{Damage}} +0.3 Damage#↑ {{Range}} +2.5 Range#{{HealingRed}} Full health"}, -- SMB Super Fan
	[192] = {"192", "Telepathy for Dummies", "{{Timer}} Receive for the room:#↑ {{Range}} +3 Range#Homing tears"}, -- Telepathy for Dummies
	[193] = {"193", "MEAT!", "↑ {{Heart}} +1 Health#↑ {{Damage}} +0.3 Damage#{{HealingRed}} Heals 1 heart"}, -- MEAT!
	[194] = {"194", "Magic 8 Ball", "↑ {{Shotspeed}} +0.16 Shot speed#{{Card}} Spawns a card#{{PlanetariumChance}} +15% Planetarium chance"}, -- Magic 8 Ball
	[197] = {"197", "Jesus Juice", "↑ {{Damage}} +0.5 Damage#↑ {{Range}} +1.5 Range"}, -- Jesus Juice
	[203] = {"203", "Humbleing Bundle", "Pickups have a 50% chance to be doubled"}, -- Humbleing Bundle
	[205] = {"205", "Sharp Plug", "{{Battery}} Using an uncharged active item fully recharges it at the cost of half a heart per missing charge#{{Heart}} Removes Red Hearts first"}, -- Sharp Plug
	[206] = {"206", "Guillotine", "↑ {{Tears}} +0.5 Fire rate#↑ {{Damage}} +1 Damage#Isaac's head becomes an orbital that shoots, doesn't take damage and deals 56 contact damage per second"}, -- Guillotine
	[211] = {"211", "Spiderbaby", "Taking damage spawns 3-5 blue spiders"}, -- Spiderbaby
	[214] = {"214", "Anemic", "↑ {{Range}} +1.5 Range#{{Timer}} When taking damage Isaac leaves a trail of blood creep for the room#The creep deals 6 damage per second"}, -- Anemic
	[218] = {"218", "Placenta", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#{{HealingRed}} 50% chance to heal half a heart every minute"}, -- Placenta
	[219] = {"219", "Old Bandage", "↑ {{EmptyHeart}} +1 Empty heart container#{{Heart}} Taking damage has a 20% chance to spawn a Red Heart"}, -- Old Bandage
	[222] =	{"222", "Anti-Gravity", "↑ {{Tears}} +1 Fire rate#Holding the fire buttons causes tears to hover in mid-air#Releasing the fire buttons shoots them in the direction they were fired"}, -- Anti-Gravity
	[223] = {"223", "Pyromaniac", "{{Bomb}} +5 Bombs#Immunity to explosions and fire#{{HealingRed}} Getting hit by explosions heals half a heart"}, -- Pyromaniac
	[224] = {"224", "Cricket's Body", "↑ {{Tears}} +0.5 Fire rate#↓ {{Range}} x0.8 Range multiplier#Tears split in 4 on hit#Split tears deal half damage"}, -- Cricket's Body
	[225] = {"225", "Gimpy", "{{SoulHeart}} Taking damage has a 8% chance to spawn a Soul Heart#{{Luck}} +2% chance per luck#{{HalfHeart}} Enemies have a chance to drop a half Red Heart on death"}, -- Gimpy
	[226] = {"226", "Black Lotus", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#{{SoulHeart}} +1 Soul Heart#{{BlackHeart}} +1 Black Heart"}, -- Black Lotus
	[228] = {"228", "Mom's Perfume", "↑ {{Tears}} +0.5 Fire rate#{{Fear}} 15% chance to shoot fear tears"}, -- Mom's Perfume
	[229] =	{"229", "Monstro's Lung", "↓ {{Tears}} x0.23 Fire rate multiplier#{{Chargeable}} Tears are charged and released in a shotgun style attack"}, -- Monstro's Lung
	[230] = {"230", "Abaddon", "↑ {{Speed}} +0.2 Speed#↑ {{Damage}} +1.5 Damage#{{BlackHeart}} Converts all heart containers into Black Hearts#{{BlackHeart}} +2 Black Hearts#{{Fear}} 15% chance to shoot fear tears"}, -- Abaddon
	[232] = {"232", "Stop Watch", "↑ {{Speed}} +0.3 Speed#{{Slow}} Enemies are permanently slowed down to 80% of their attack and movement speed"}, -- Stop Watch
	[233] = {"233", "Tiny Planet", "↑ {{Range}} +6.5 Range#Spectral tears#Isaac's tears orbit around him"}, -- Tiny Planet
	[245] = {"245", "20/20", "↓ {{Damage}} x0.8 Damage multiplier#Isaac shoots 2 tears at once"}, -- 20/20
	[248] = {"248", "Hive Mind", "Blue spiders and flies deal double damage#Spider and fly familiars become stronger"}, -- Hive Mind
	[253] = {"253", "Magic Scab", "↑ {{Heart}} +1 Health#↑ {{Luck}} +1 Luck#{{HealingRed}} Heals 1 heart"}, -- Magic Scab
	[254] = {"254", "Blood Clot", "↑ {{Damage}} +1 Damage for the left eye#↑ {{Range}} +2.75 Range for the left eye"}, -- Blood Clot
	[256] = {"256", "Hot Bombs", "{{Bomb}} +5 Bombs#{{Burning}} Isaac's bombs deal contact damage#{{Burning}} Isaac's bombs leave a flame where they explode#{{Burning}} Fire immunity (except projectiles)"}, -- Hot Bombs
	[261] = {"261", "Proptosis", "↑ {{Damage}} +0.5 Damage#↓ Tears deal less damage the longer they are airborne#Tears deal 3x damage at point blank range and no damage after 0.8 seconds"}, -- Proptosis
	[262] = {"262", "Missing Page 2", "{{BlackHeart}} +1 Black Heart#Taking damage down to 1 heart damages all enemies in the room#{{Collectible35}} Black Hearts and Necronomicon-like effects deal double damage"}, -- Missing Page 2
	[263] = {"263", "Clear Rune", "{{Rune}} Spawns 1 rune on pickup#{{Rune}} Triggers the effect of the rune Isaac holds without using it"}, -- Clear Rune (Repentance item)
	[264] = {"264", "Smart Fly", "Orbital#Attacks enemies when Isaac takes damage#Deals 6.5 contact damage per second"}, -- Smart Fly
	[272] = {"272", "BBF", "Friendly exploding fly#The explosion deals 100 damage#{{Warning}} The explosion can hurt Isaac"}, -- BBF
	[273] = {"273", "Bob's Brain", "Dashes in the direction Isaac is shooting#Explodes when it hits an enemy#{{Poison}} The explosion deals 100 damage and poisons enemies#{{Warning}} The explosion can hurt Isaac"}, -- Bob's Brain
	[274] = {"274", "Best Bud", "Taking damage spawns one midrange orbital for the room#It deals 150 contact damage per second"}, -- Best Bud
	[275] = {"275", "Lil Brimstone", "{{Chargeable}} Familiar that charges and shoots a {{Collectible118}} blood beam#It deals 24 damage over 0.63 seconds"}, -- Lil Brimstone
	[276] = {"276", "Isaac's Heart", "Isaac becomes invincible#Spawns a heart familiar that follows Isaac#The heart charges up when Isaac fires and releases a burst of tears when he stops#{{Warning}} If the heart familiar gets hit, Isaac takes damage"}, -- Isaac's Heart
	[278] = {"278", "Dark Bum", "{{Heart}} Picks up nearby Red Hearts#Spawns a Black Heart, rune, card, pill, or spider for every 1.5 hearts picked up"}, -- Dark Bum
	[280] = {"280", "Sissy Longlegs", "Randomly spawns blue spiders in hostile rooms#{{Charm}} Charms enemies it comes in contact with"}, -- Sissy Longlegs
	[283] = {"283", "D100", "Duplicates 1 pickup in the room#Rerolls Isaac's speed, tears, damage, range and passive items#Rerolls all pedestal items, pickups and rocks in the room#Restarts the room, respawns all enemies and devolves them"}, -- D100
	[285] = {"285", "D10", "Devolves all enemies in the room#For instance, all Red Flies become Black Flies"}, -- D10
	[286] = {"286", "Blank Card", "Triggers the effect of the card Isaac holds without using it"}, -- Blank Card
	[287] = {"287", "Book of Secrets", "Highlights tinted and crawlspace rocks in the room#{{Timer}} Receive one of these effects for the floor:#{{Collectible54}} Treasure Map#{{Collectible21}} Compass #{{Collectible246}} Blue Map#Only grants effects not already active#{{Collectible76}} If all effects are active, grants X-Ray Vision"}, -- Book of Secrets
	[288] = {"288", "Box of Spiders", "Spawn 4-8 blue spiders"}, -- Box of Spiders
	[289] = {"289", "Red Candle", "Throws a red flame#It deals contact damage, blocks enemy tears, and disappears when it has dealt damage or blocked shots 4 times or after 10 seconds"}, -- Red Candle
	[291] = {"291", "Flush!", "Turns all non-boss enemies into poop#Instantly kills poop enemies and bosses#Extinguishes fire places and fills the room with water#Turns lava pits into walkable ground"}, -- Flush!
	[292] = {"292", "Satanic Bible", "{{BlackHeart}} +1 Black Heart#{{DevilRoom}} Using the item before a boss fight makes the boss reward a devil deal#Purchasing these devil deals has the same consequences as those in Devil Rooms#Does not affect item pedestals in The Void floor"}, -- Satanic Bible
	[293] = {"293", "Head of Krampus", "{{Collectible118}} Shoot a 4-way blood beam#They each deal 200 damage over 1.33 seconds"}, -- Head of Krampus
	[294] = {"294", "Butter Bean", "Knocks back nearby enemies and projectiles#Enemies pushed into obstacles take 10 damage"}, -- Butter Bean
	[295] = {"295", "Magic Fingers", "Deals 2x Isaac's damage + 10 to all enemies in the room#{{Coin}} Costs 1 coin"}, -- Magic Fingers
	[296] = {"296", "Converter", "{{Heart}} Converts 1 Soul or Black Heart into 1 heart container"}, -- Converter
	-- NOTE FOR LOCALIZERS: There is code to highlight the text of your current floor
	-- For it to work, only use line breaks or semicolons to separate floor details, and use the same order as English
	[297] = {"297", "Pandora's Box", "{{NoLB}}Spawns rewards based on floor:#B1: 2{{SoulHeart}}; B2: 2{{Bomb}} + 2{{Key}}#{{NoLB}}C1: Boss item; C2: C1 + 2{{SoulHeart}}#D1: 4{{SoulHeart}}; D2: 20{{Coin}}#W1: 2 Boss items#W2: {{Collectible33}} The Bible#???/Void: Nothing#Sheol: Devil item + 1{{BlackHeart}}#Cathe: Angel item + 1{{EternalHeart}}#{{NoLB}}Dark Room: Unlocks {{Collectible523}} Moving Box#Chest: 1{{Coin}}#Home: {{Collectible580}} Red Key"}, -- Pandora's Box
	[300] = {"300", "Aries", "↑ {{Speed}} +0.25 Speed#Moving above 0.85 Speed makes Isaac immune to contact damage and deals 25 damage to enemies"}, -- Aries
	[307] = {"307", "Capricorn", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.1 Speed#↑ {{Tears}} +0.5 Fire rate#↑ {{Damage}} +0.5 Damage#↑ {{Range}} +0.75 Range#+1 {{Coin}} coin, {{Bomb}} bomb and {{Key}} key#{{HealingRed}} Heals 1 heart"}, -- Capricorn
	[308] = {"308", "Aquarius", "Isaac leaves a trail of creep#{{Damage}} The creep deals 66% of Isaac's damage per second and inherits his tear effects"}, -- Aquarius
	[309] =	{"309", "Pisces", "↑ {{Tears}} +0.5 Fire rate#↑ {{Tearsize}} +0.12 Tear size#Increases tear knockback"}, -- Pisces
	[310] =	{"310", "Eve's Mascara", "↑ {{Damage}} x2 Damage multiplier#↓ {{Tears}} x0.66 Tears multiplier#↓ {{Shotspeed}} -0.5 Shot speed"}, -- Eve's Mascara
	[314] = {"314", "Thunder Thighs", "↑ {{Heart}} +1 Health#↓ {{Speed}} -0.4 Speed#{{HealingRed}} Heals 1 heart#Isaac can destroy rocks by walking into them"}, -- Thunder Thighs
	[315] = {"315", "Strange Attractor", "Isaac's tears attract enemies, pickups and trinkets#The attraction effect is much stronger at the end of the tears' path"}, -- Strange Attractor
	[316] = {"316", "Cursed Eye", "Charged wave of 5 tears#{{Warning}} Taking damage while partially charged teleports Isaac to a random room"}, -- Cursed Eye
	[319] = {"319", "Cain's Other Eye", "Shoots tears in random directions with the same effects as Isaac#{{Damage}} Deals 75% of Isaac's damage"}, -- Cain's Other Eye
	[320] = {"320", "???'s Only Friend", "Controllable fly#Deals 15 contact damage per second"}, -- ???'s Only Friend
	[323] = {"323", "Isaac's Tears", "Shoots 8 tears in all directions#The tears copy Isaac's tear effects, plus 5 damage#Recharges by shooting tears"}, -- Isaac's Tears
	[325] = {"325", "Scissors", "{{Timer}} Isaac's head turns into a stationary familiar for the room#The body is controlled separately and gushes blood tears in the direction Isaac is shooting"}, -- Scissors
	[326] = {"326", "Breath of Life", "Holding down the USE button empties the charge bar#Isaac is temporarily invincible when the charge bar is empty#Isaac summons light beams on contact with enemies when invincible#If damage is blocked with perfect timing, shoot a 4-way holy beam and gain a brief shield#{{Warning}} Holding it for too long deals damage to Isaac"}, -- Breath of Life
	[328] = {"328", "The Negative", "↑ {{Damage}} +1 Damage#Taking damage at half a Red Heart or none damages all enemies in the room"}, -- The Negative
	[330] = {"330", "Soy Milk", "↑ {{Tears}} x5.5 Fire rate multiplier#↓ {{Damage}} x0.2 Damage multiplier#↓ {{Tearsize}} -0.3 Tear size#Drastically reduces knockback"}, -- Soy Milk
	[331] = {"331", "Godhead", "↑ {{Damage}} +0.5 Damage#↓ {{Tears}} -0.3 Tears#↓ {{Shotspeed}} -0.3 Shot speed#Homing tears#Tears gain an aura that deals 60 damage per second"}, -- Godhead
	[336] = {"336", "Dead Onion", "↑ {{Tearsize}} +0.22 Tear size#↓ {{Range}} -1.5 Range#↓ {{Shotspeed}} -0.4 Shot speed#Piercing + spectral tears"}, -- Dead Onion
	[339] = {"339", "Safety Pin", "↑ {{Range}} +2.5 Range#↑ {{Shotspeed}} +0.16 Shot speed#{{BlackHeart}} +1 Black Heart"}, -- Safety Pin
	[342] = {"342", "Blue Cap", "↑ {{Heart}} +1 Health#↑ {{Tears}} +0.7 Tears#↓ {{Shotspeed}} -0.16 Shot speed#{{HealingRed}} Heals 1 heart"}, -- Blue Cap
	[344] = {"344", "Match Book", "{{BlackHeart}} +1 Black Heart#{{Bomb}} Spawns 3 bombs#{{Trinket41}} Spawns Match Stick"}, -- Match Book
	[345] = {"345", "Synthoil", "↑ {{Damage}} +1 Damage#↑ {{Range}} +2.5 Range"}, -- Synthoil
	[346] = {"346", "A Snack", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- A Snack
	[349] = {"349", "Wooden Nickel", "{{Coin}} 59% chance to spawn a random coin"}, -- Wooden Nickel
	[352] = {"352", "Glass Cannon", "{{Damage}} Shoots a large piercing spectral tear that does 10x Isaac's damage#{{Warning}} While held, taking damage:#↓ Removes an extra 2 hearts of health#↓ Breaks the cannon for a few rooms#↑ {{Range}} +1.5 Range and leaves a blood trail for the room#The extra damage can't kill Isaac#Self-damage does not trigger the effect"}, -- Glass Cannon
	[354] = {"354", "Crack Jacks", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#{{Trinket}} Spawns a trinket"}, -- Crack Jacks
	[355] = {"355", "Mom's Pearls", "↑ {{Range}} +2.5 Range#↑ {{Luck}} +1 Luck#{{SoulHeart}} +1 Soul Heart"}, -- Mom's Pearls
	[360] = {"360", "Incubus", "Shoots tears with the same effects as Isaac#{{Damage}} Deals 75% of Isaac's damage"}, -- Incubus
	[365] = {"365", "Lost Fly", "Moves along walls/obstacles in the room#Deals 30 contact damage per second#Nearby enemies target the fly"}, -- Lost Fly
	[366] = {"366", "Scatter Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs scatter into 4-5 tiny bombs"}, -- Scatter Bombs
	[367] = {"367", "Sticky Bombs", "{{Bomb}} +5 Bombs#{{Slow}} Isaac's bombs stick to enemies and leave white slowing creep#Killing an enemy with a bomb spawns blue spiders"}, -- Sticky Bombs
	[368] =	{"368", "Epiphora", "↑ {{Tears}} Shooting in one direction gradually increases fire rate up to 200% and decreases accuracy"}, -- Epiphora
	[369] = {"369", "Continuum", "↑ {{Range}} +3 Range#Spectral tears#Tears can travel through one side of the screen and come out the other side"}, -- Continuum
	[370] = {"370", "Mr. Dolly", "↑ {{Tears}} +0.7 Tears#↑ {{Range}} +2.5 Range#{{UnknownHeart}} Spawns 3 random hearts"}, -- Mr. Dolly
	[374] = {"374", "Holy Light", "10% chance to shoot holy tears, which spawn a beam of light on hit#{{Luck}} 50% chance at 9 luck#{{Damage}} The beams deals 3x Isaac's damage"}, -- Holy Light
	[375] = {"375", "Host Hat", "Grants immunity to explosions and falling projectiles#25% chance to reflect enemy shots"}, -- Host Hat
	[376] = {"376", "Restock", "Buying an item from a Shop restocks it instantly#Restocked items increase in price each time"}, -- Restock
	[380] = {"380", "Pay To Play", "{{Coin}} +5 Coins#Locked blocks, doors and chests must be opened with coins instead of keys"}, -- Pay To Play
	[382] = {"382", "Friendly Ball", "Can be thrown at enemies to capture them#Using the item after capturing an enemy spawns the capture as a friendly companion#Walking over the ball after a capture instantly recharges the item"}, -- Friendly Ball
	[384] = {"384", "Lil Gurdy", "{{Chargeable}} Launches and bounces around the room with speed based on charge amount#Deals 5-20 contact damage per hit depending on speed"}, -- Lil Gurdy
	[386] = {"386", "D12", "Rerolls any obstacle into another random obstacle (e.g. poop, pots, TNT, red poop, stone blocks etc.)#Small chance to reroll obstacles into buttons, killswitches, crawlspaces or trapdoors"}, -- D12
	[389] = {"389", "Rune Bag", "{{Rune}} Spawns a random rune or Soul Stone every 7-8 rooms"}, -- Rune Bag
	[391] = {"391", "Betrayal", "Enemies can hit each other with their projectiles, and start infighting"}, -- Betrayal
	[393] = {"393", "Serpent's Kiss", "{{Poison}} 15% chance to shoot poison tears#{{Poison}} Poison enemies on contact#{{BlackHeart}} Enemies killed by contact poison have a chance to drop a Black Heart on death"}, -- Serpent's Kiss
	[394] = {"394", "Marked", "↑ {{Tears}} +0.7 Tears#↑ {{Range}} +3 Range#Isaac automatically shoots tears at a movable red target on the ground#Familiars shoot towards the target too#You can stop shooting and reset the target's location by pressing the drop button ({{ButtonRT}})"}, -- Marked
	[395] = {"395", "Tech X", "Isaac's tears are replaced by a chargeable laser ring#Ring size and damage increases up to 100% with charge time"}, -- Tech X
	[397] = {"397", "Tractor Beam", "↑ {{Tears}} +1 Fire rate#↑ {{Range}} +2.5 Range#↑ {{Shotspeed}} +0.16 Shot speed#Isaac's tears always travel along a beam of light in front of him"}, -- Tractor Beam
	[399] = {"399", "Maw of the Void", "{{Chargeable}} Firing tears for 2.35 seconds and releasing the fire button creates a black brimstone ring around Isaac#It deals 30x Isaac's damage over 2 seconds"}, -- Maw of the Void
	[401] = {"401", "Explosivo", "25% chance to shoot sticky tears#Sticky tears grow and explode after a few seconds, dealing Isaac's damage +60"}, -- Explosivo
	[404] = {"404", "Farting Baby", "Blocks projectiles#When hit, 10% chance to fart and {{Charm}} charm, {{Poison}} poison or knockback enemies#The farts deal 5-6 damage"}, -- Farting Baby
	[405] = {"405", "GB Bug", "{{Throwable}} Throwable (double-tap shoot)#Rerolls enemies and pickups it comes in contact with"}, -- GB Bug
	[407] = {"407", "Purity", "↑ Boosts one of Isaac's stats depending on the color of the aura#Taking damage removes the effect, and grants a new effect in the next room#{{ColorYellow}}Yellow{{CR}} = ↑ {{Speed}} +0.5 Speed#{{ColorBlue}}Blue{{CR}} = ↑ {{Tears}} +2 Fire rate#{{ColorRed}}Red{{CR}} = ↑ {{Damage}} +4 Damage#{{ColorOrange}}Orange{{CR}} = ↑ {{Range}} +3 Range"}, -- Purity
	[408] = {"408", "Athame", "25% chance for a black brimstone ring to spawn around killed enemies#It deals 30x Isaac's damage over 2 seconds#{{Luck}} +2.5% chance per luck"}, -- Athame
	[415] = {"415", "Crown Of Light", "{{SoulHeart}} +2 Soul Hearts#If Isaac has no damaged heart containers:#↑ {{Damage}} x2 Damage multiplier#↓ {{Shotspeed}} -0.3 Shot speed#Taking any damage removes the effect for the room"}, -- Crown Of Light
	[416] = {"416", "Deep Pockets", "{{Coin}} If clearing a room would yield no reward, spawns 1-3 coins#{{Coin}} Increases the coin cap to 999"}, -- Deep Pockets
	[417] = {"417", "Succubus", "Bounces around the room surrounded by a damaging aura that deals 7.5-10 damage per second#↑ {{Damage}} x1.5 Damage multiplier while standing in the aura"}, -- Succubus
	[419] = {"419", "Teleport 2.0", "Teleports Isaac to a room that has not been cleared yet#Hierarchy: {{Room}}>{{BossRoom}}>{{SuperSecretRoom}}>{{Shop}}>{{TreasureRoom}}>{{SacrificeRoom}}> {{DiceRoom}}>{{Library}}>{{CursedRoom}}>{{MiniBoss}}>{{ChallengeRoom}}{{BossRushRoom}}>{{IsaacsRoom}}{{BarrenRoom}}> {{ArcadeRoom}}>{{ChestRoom}}>{{Planetarium}}>{{SecretRoom}}>{{DevilRoom}}{{AngelRoom}}>{{ErrorRoom}}"}, -- Teleport 2.0
	[421] = {"421", "Kidney Bean", "{{Charm}} Charms all enemies in close range"}, -- Kidney Bean
	[422] = {"422", "Glowing Hourglass", "Brings Isaac back to the previous room and reverses all actions done in the room the item was used in#The rewind can be used three times per floor#{{Collectible66}} Acts as The Hourglass when out of rewinds, which slows enemies down for 8 seconds"}, -- Glowing Hourglass
	[426] = {"426", "Obsessed Fan", "Mimics Isaac's movement on a 0.66 second delay#Deals 30 contact damage per second"}, -- Obsessed Fan
	[430] = {"430", "Papa Fly", "Mimics Isaac's movement on a 0.66 second delay#{{Damage}} Shoots tears at nearby enemies that deal Isaac's damage"}, -- Papa Fly
	[431] = {"431", "Multidimensional Baby", "Mimics Isaac's movement on a 0.66 second delay#Tears that pass through it are doubled and gain a range + shot speed boost"}, -- Multidimensional Baby
	[432] = {"432", "Glitter Bombs", "{{Bomb}} +5 Bombs#{{Charm}} Bombs have a 63% chance to drop a random pickup and a 15% chance to charm enemies when they explode#The pickup spawn chance goes down by 1% for each spawn this floor"}, -- Glitter Bombs
	[433] = {"433", "My Shadow", "A small shadow follows Isaac#{{Timer}} When an enemy touches the shadow a friendly black charger spawns for the room#The charger deals 8.7 damage per hit"}, -- My Shadow
	[437] = {"437", "D7", "Restarts a room and respawns all enemies#Can be used to get multiple room clear rewards from a single room"}, -- D7
	[440] = {"440", "Kidney Stone", "Isaac occasionally stops firing and charges an attack that releases a burst of tears and a kidney stone"}, -- Kidney Stone
	[442] = {"442", "Dark Prince's Crown", "While at 1 full Red Heart:#↑ {{Tears}} +2 Fire rate#↑ {{Range}} +1.5 Range#↑ {{Shotspeed}} +0.2 Shot speed"}, -- Dark Prince's Crown
	[444] = {"444", "Lead Pencil", "Isaac shoots a cluster of tears every 15 tears"}, -- Lead Pencil
	[448] = {"448", "Shard of Glass", "Upon taking damage:#{{Heart}} 25% chance to spawn a Red Heart#{{BleedingOut}} Isaac bleeds, spewing tears in the direction he is shooting#The bleeding does half a Red Heart of damage every 20 seconds#The bleeding stops if a Red Heart is healed, all Red Hearts are empty, or the next damage would kill Isaac"}, -- Shard of Glass
	[450] = {"450", "Eye of Greed", "{{Damage}} Every 20 tears, Isaac shoots a coin tear that deals x1.5 +10 damage#Enemies hit with the coin turn into gold#{{Coin}} Killing a gold enemy drops 1-3 coins#{{Warning}} Firing a coin tear costs 1 coin"}, -- Eye of Greed
	[451] = {"451", "Tarot Cloth", "{{Card}} Spawns a card#{{Card}} Tarot card effects are doubled or enhanced"}, -- Tarot Cloth
	[453] = {"453", "Compound Fracture", "↑ {{Range}} +1.5 Range#Tears shatter into 1-3 bone shards upon hitting anything"}, -- Compound Fracture
	[455] = {"455", "Dad's Lost Coin", "↑ {{Range}} +2.5 Range#{{Luck}} Spawns a Lucky Penny"}, -- Dad's Lost Coin
	[456] = {"456", "Midnight Snack", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Midnight Snack
	[459] = {"459", "Sinus Infection", "20% chance to shoot a sticky booger#{{Damage}} Boogers deal Isaac's damage once a second and stick for 10 seconds#{{Luck}} Not affected by luck"}, -- Sinus Infection
	[462] = {"462", "Eye of Belial", "↑ {{Range}} +1.5 Range#Piercing tears#Hitting an enemy makes the tear homing and doubles its damage"}, -- Eye of Belial
	[464] = {"464", "Glyph of Balance", "{{SoulHeart}} +2 Soul Hearts#Room clear rewards and champion enemy drops become whatever pickup Isaac needs the most"}, -- Glyph of Balance
	[468] = {"468", "Shade", "Follows Isaac's movement on a 0.66 second delay#Deals 75 contact damage per second#After it deals 666 damage, it is absorbed by Isaac, increasing his contact damage"}, -- Shade
	[472] = {"472", "King Baby", "Other familiars follow it and automatically shoot at enemies#Stops moving when Isaac shoots#Teleports back to Isaac when he stops shooting"}, -- King Baby
	[474] = {"474", "Broken Glass Cannon", "Using the item turns it back into Glass Cannon"}, -- Broken Glass Cannon
	[476] =	{"476", "D1", "Duplicates a random pickup in the room#Duplicated pickups may not be identical to the original"}, -- D1
	[477] = {"477", "Void", "Consumes all pedestal items in the room#Active items: Their effects activate with every future use of Void#↑ Passive items grant two random stat ups"}, -- Void
	[487] = {"487", "Potato Peeler", "{{EmptyHeart}} Removes 1 heart container for: #↑ {{Damage}} +0.2 Damage#{{Collectible73}} A Cube of Meat#{{Timer}} Receive for the room:#↑ {{Range}} +1.5 Range#{{Collectible214}} Leave a trail of blood creep"}, -- Potato Peeler
	[489] = {"489", "D Infinity", "Can be made to act as any die item (except {{Collectible723}} Spindown Dice) with the drop button ({{ButtonRT}})#Charge time varies based on the last die used and updates with every use"}, -- D Infinity
	[491] = {"491", "Acid Baby", "{{Pill}} Spawns a random pill every 7 rooms#{{Poison}} Using a pill poisons all enemies in the room"}, -- Acid Baby
	[493] = {"493", "Adrenaline", "↑ {{Damage}} Damage up for every empty heart container#The more empty heart containers, the bigger the bonus for each new one"}, -- Adrenaline
	[494] = {"494", "Jacob's Ladder", "Tears spawn a spark of electricity on impact#Sparks deal half of Isaac's damage#Sparks can arc to up to 4 other enemies"}, -- Jacob's Ladder
	[495] = {"495", "Ghost Pepper", "8% chance to shoot a blue fire that blocks enemy shots and deals contact damage#{{Luck}} 50% chance at 10 luck#Fires shrink and disappear after 2 seconds"}, -- Ghost Pepper
	[496] = {"496", "Euthanasia", "3.33% chance to shoot a needle#{{Luck}} 25% chance at 13 luck#Needles kill normal enemies instantly, bursting them into 10 tears#{{Damage}} Needles deal 3x Isaac's damage against bosses"}, -- Euthanasia
	[497] = {"497", "Camo Undies", "{{Confusion}} Entering a room camouflages Isaac and confuses all enemies until a tear is shot#↑ {{Speed}} +0.5 Speed while cloaked#Uncloaking deals damage around Isaac and grants a very brief fire rate and damage up"}, -- Camo Undies
	[500] = {"500", "Sack of Sacks", "Spawns a sack every 7-8 rooms"}, -- Sack of Sacks
	[501] = {"501", "Greed's Gullet", "{{Heart}} +1 Heart container for every 25 coins Isaac has"}, -- Greed's Gullet
	[503] = {"503", "Little Horn", "5% chance to shoot a tear that summons a Big Horn hand#{{Luck}} 20% chance at 15 luck#The hand instantly kills enemies and deals 36 damage to bosses#Isaac deals 7 contact damage per second"}, -- Little Horn
	[504] = {"504", "Brown Nugget", "Spawns a fly that shoots at enemies#Each shot deals 3.5 damage"}, -- Brown Nugget
	[506] = {"506", "Backstabber", "{{BleedingOut}} Hitting an enemy in the back deals double damage and causes bleeding, which makes enemies leave creep and take damage when they move"}, -- Backstabber
	[507] = {"507", "Sharp Straw", "{{Damage}} Deals Isaac's damage + 10% of the enemy's max health to all enemies#{{HalfHeart}} Dealing damage with the Straw can spawn half hearts"}, -- Sharp Straw
	[508] = {"508", "Mom's Razor", "{{BleedingOut}} Orbital that causes bleeding, which makes enemies take damage when they move#{{Damage}} Deals 1.5x Isaac's damage per second"}, -- Mom's Razor
	[509] = {"509", "Bloodshot Eye", "Orbital that shoots a tear every 0.33 seconds to nearby enemies#Deals 3.5 damage per tear#Deals 20 contact damage per second"}, -- Bloodshot Eye
	[514] = {"514", "Broken Modem", "Causes some enemies and projectiles to briefly pause at random intervals#Paused projectiles disappear#25% chance to double room clear rewards"}, -- Broken Modem
	[517] = {"517", "Fast Bombs", "{{Bomb}} +7 Bombs#Removes the delay between bomb placements#Bombs don't deal knockback to each other"}, -- Fast Bombs
	[522] = {"522", "Telekinesis", "Stops all enemy projectiles that come close to Isaac for 3 seconds and throws them away from him afterwards#Pushes close enemies away during the effect"}, -- Telekinesis
	[523] = {"523", "Moving Box", "Stores up to 10 pickups and items from the current room#Using the item again drops everything back on the floor#Allows Isaac to move things between rooms"}, -- Moving Box
	[524] = {"524", "Technology Zero", "Isaac's tears are connected with beams of electricity#Electricity deals 4.5x Isaac's damage per second"}, -- Technology Zero
	[531] = {"531", "Haemolacria", "↑ {{Damage}} +1 Damage#↑ {{Damage}} x1.5 Damage multiplier#↓ {{Tears}} x0.33 Fire rate multiplier#↓ {{Range}} x0.8 Range multiplier#Isaac's tears fly in an arc and burst into smaller tears on impact"}, -- Haemolacria
	[543] = {"543", "Hallowed Ground", "Taking damage spawns a white poop#While inside the poop's aura:#↑ {{Tears}} x2.5 Fire rate multiplier#↑ {{Damage}} x1.2 Damage multiplier#Homing tears#Chance to block damage"}, -- Hallowed Ground
	[549] =	{"549", "Brittle Bones", "{{EmptyBoneHeart}} Replaces all of Isaac's Red Heart containers with 6 empty Bone Hearts#Upon losing a Bone Heart:#↑ {{Tears}} +0.4 Fire rate#Shoots 8 bone tears in all directions"}, -- Brittle Bones
	[552] = {"552", "Mom's Shovel", "Spawns a trapdoor to the next floor#{{LadderRoom}} Spawns a crawlspace if used on a decorative floor tile (grass, small rocks, papers, gems, etc.)#{{Warning}} Use the shovel on the mound of dirt in the \"Dark Room\""}, -- Mom's Shovel
	[553] = {"553", "Mucormycosis", "25% chance to shoot a sticky spore tear#{{Luck}} Not affected by luck#{{Poison}} Spores blow up after 2.5 seconds, dealing damage, poisoning nearby enemies and releasing more spores"}, -- Mucormycosis
	[554] = {"554", "2Spooky", "{{Fear}} Fears enemies in a small radius around Isaac"}, -- 2Spooky
	[555] = {"555", "Golden Razor", "{{Coin}} +5 coins on pickup#{{Timer}} Pay 5 {{Coin}} coins and receive for the room:#↑ {{Damage}} +1.2 Damage"}, -- Golden Razor
	[556] = {"556", "Sulfur", "{{Timer}} {{Collectible118}} Brimstone for the room#Using it multiple times in one room grants increased damage and a larger beam"}, -- Sulfur
	[557] = {"557", "Fortune Cookie", "Grants one of the following rewards:#A fortune#{{SoulHeart}} A Soul Heart#{{Rune}} A Rune or Soul Stone#{{Card}} A Tarot card#{{Trinket}} A Trinket"}, -- Fortune Cookie
	[558] = {"558", "Eye Sore", "Chance to shoot 1-3 extra tears in random directions#{{Luck}} Not affected by luck"}, -- Eye Sore
	[559] = {"559", "120 Volt", "Repeatedly zaps nearby enemies#{{Damage}} Electricity deals up to 3.75x Isaac's damage per second#Sparks can arc to up to 4 other enemies"}, -- 120 Volt
	[560] = {"560", "It Hurts", "{{Timer}} When taking damage, receive for the room:#↑ {{Tears}} +1.2 Fire rate on the first hit#↑ {{Tears}} +0.4 Fire rate for each additional hit#Releases a ring of 10 tears around Isaac"}, -- It Hurts
	[561] = {"561", "Almond Milk", "↑ {{Tears}} x4 Fire rate multiplier#↓ {{Damage}} x0.3 Damage multiplier#↓ {{Tearsize}} -0.16 Tear size#Tears gain random worm trinket effects and some item effects"}, -- Almond Milk
	[562] = {"562", "Rock Bottom", "↑ Prevents stats from being lowered for the rest of the run"}, -- Rock Bottom
	[563] = {"563", "Nancy Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs explode with random effects"}, -- Nancy Bombs
	[564] = {"564", "A Bar of Soap", "↑ {{Tears}} +0.5 Tears#↑ {{Shotspeed}} +0.2 Shot speed"}, -- A Bar of Soap
	[565] = {"565", "Blood Puppy", "Chases enemies#After killing 15 enemies, it deals more damage, spawns a half Red Heart every 10 kills, but tries to hurt Isaac#After killing 40 enemies, it deals even more damage, spawns full Red Hearts, and can destroy rocks#Dealing enough damage to it returns it to its first phase"}, -- Blood Puppy
	[566] = {"566", "Dream Catcher", "{{HalfSoulHeart}} +1 half Soul Heart when entering a new floor#The stage transition nightmare reveals the next floor's boss fight and Treasure Room item"}, -- Dream Catcher
	[567] = {"567", "Paschal Candle", "↑ {{Tears}} Clearing a room without taking damage grants +0.4 Fire rate#Caps at +2 Fire rate {{ColorSilver}}(5 rooms){{CR}}"}, -- Paschal Candle
	[568] = {"568", "Divine Intervention", "Double-tapping a fire key creates a shield#The shield lasts 1 second, pushes enemies away and reflects enemy projectiles and lasers"}, -- Divine Intervention
	[569] = {"569", "Blood Oath", "{{Warning}} Entering a new floor drains all of Isaac's Red Hearts, but grants speed and damage bonuses for each heart lost#Each half heart lost counts as an individual hit for on-hit effects"}, -- Blood Oath
	[570] = {"570", "Playdough Cookie", "Each of Isaac's tears have a different color and status effect"}, -- Playdough Cookie
	[571] = {"571", "Orphan Socks", "↑ {{Speed}} +0.3 Speed#{{SoulHeart}} +2 Soul Hearts#Immune to creep and floor spikes"}, -- Orphan Socks
	[572] = {"572", "Eye of the Occult", "↑ {{Damage}} +1 Damage#↑ {{Range}} +2 Range#↓ {{Shotspeed}} -0.16 Shot speed#Isaac's tears can be controlled in mid-air"}, -- Eye of the Occult
	[573] = {"573", "Immaculate Heart", "↑ {{Heart}} +1 Health#↑ {{Damage}} x1.2 Damage multiplier#{{HealingRed}} Full health#20% chance to shoot an extra orbiting spectral tear"}, -- Immaculate Heart
	[574] = {"574", "Monstrance", "Isaac is surrounded by a damaging aura#The closer enemies are to Isaac, the more damage the aura deals to them"}, -- Monstrance
	[575] = {"575", "The Intruder", "{{Slow}} Buries itself in Isaac's head and shoots 4 extra slowing tears that deal 1.5 damage#Taking damage can make the spider exit the head and chase enemies"}, -- The Intruder
	[576] = {"576", "Dirty Mind", "All Dip (small poop) enemies are friendly#Destroying poop spawns 1-4 Dips#Dip type depends on the poop type#Rocks may be replaced with poop"}, -- Dirty Mind
	[577] = {"577", "Damocles", "Hangs a sword above Isaac's head, which doubles all pedestal items#Does not double items that have a price or come from chests#{{Warning}} After taking any damage, the sword has an extremely low chance to instantly kill Isaac every frame#Invincibility effects can prevent the death"}, -- Damocles
	[578] = {"578", "Free Lemonade", "Creates a large pool of yellow creep#The creep deals 24 damage per second"}, -- Free Lemonade
	[579] = {"579", "Spirit Sword", "Instead of shooting tears, swing a sword#{{Damage}} The sword deals 3x Isaac's damage +3.5 and swings as fast as the fire button is tapped#{{Chargeable}} Charging does a spin attack + projectile shot#Shoots projectiles with swings at full health"}, -- Spirit Sword
	[580] = {"580", "Red Key", "Creates a red room adjacent to a regular room, indicated by a door outline#Red Rooms can be special rooms#{{ErrorRoom}} Entering a room outside the 13x13 floor map teleports Isaac to the I AM ERROR room"}, -- Red Key
	[581] = {"581", "Psy Fly", "Chases and deflects enemy projectiles#Deals 15 contact damage per second"}, -- Psy Fly
	[582] = {"582", "Wavy Cap", "↑ {{Tears}} +0.75 Fire rate#↓ {{Speed}} -0.03 Speed#Distorts the screen#Takes longer to recharge each use#Leaving or clearing rooms reduces the effects"}, -- Wavy Cap
	[583] = {"583", "Rocket in a Jar", "{{Bomb}} +5 Bombs#Placing a bomb while shooting fires a rocket in that direction instead"}, -- Rocket in a Jar
	[584] = {"584", "Book of Virtues", "{{AngelChance}} +12.5% Angel Room chance while held#Spawns an orbital wisp familiar that shoots spectral tears but can be destroyed#Can be combined with a second active item to create special wisps#{{AngelRoom}} Turns the first Devil Room into an Angel Room#{{AngelRoom}} Allows Angel Rooms to spawn after taking a Devil deal"}, -- Book of Virtues
	[585] = {"585", "Alabaster Box", "Must be charged by picking up Soul Hearts, then spawns:#{{SoulHeart}} Three Soul Hearts#{{AngelRoom}} Two Angel Room items#{{DevilRoom}} Only spawns 2 Soul Hearts and 1 Angel item if a Devil deal was taken previously"}, -- Alabaster Box
	[586] = {"586", "The Stairway", "Spawns a ladder in the first room of every floor that leads to a unique {{AngelRoom}} Angel Room shop with items and pickups"}, -- The Stairway
	[587] = {"587", "", "<Item does not exist>"},
	[588] = {"588", "Sol", "{{BossRoom}} Reveals the location of the Boss Room#{{Timer}} When the floor boss is defeated, receive for the floor:#↑ {{Damage}} +3 Damage#↑ {{Luck}} +1 Luck#{{Card20}} The Sun effect#{{Battery}} Fully recharges the active item#{{CurseBlind}} Removes any curses"}, -- Sol
	[589] = {"589", "Luna", "Adds an extra {{SecretRoom}} Secret Room and {{SuperSecretRoom}} Super Secret Room to each floor#Reveals one Secret Room each floor#{{Timer}} Secret Rooms contain a beam of light that grant for the floor:#↑ {{Tears}} +0.5 Fire rate#↑ {{Tears}} Additional +0.5 Fire rate from the first beam per floor#{{HalfSoulHeart}} Half a Soul Heart"}, -- Luna
	[590] = {"590", "Mercurius", "↑ {{Speed}} +0.4 Speed#Most doors stay permanently open"}, -- Mercurius
	[591] = {"591", "Venus", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart#{{Charm}} Charms nearby enemies"}, -- Venus
	[592] = {"592", "Terra", "↑ {{Damage}} +1 Damage#Replaces Isaac's tears with rocks#Rocks deal variable damage, can destroy obstacles and have increased knockback"}, -- Terra
	[593] = {"593", "Mars", "Double-tapping a movement key makes Isaac dash#{{Damage}} During a dash, Isaac is invincible and deals 4x his damage +8#{{Timer}} 3 seconds cooldown"}, -- Mars
	[594] = {"594", "Jupiter", "↑ {{EmptyHeart}} +2 Empty heart containers#↓ {{Speed}} -0.3 Speed#{{HealingRed}} Heals half a heart#{{Speed}} Speed builds up to +0.5 while standing still#{{Poison}} Moving releases poison clouds#{{Poison}} Poison immunity"}, -- Jupiter
	[595] = {"595", "Saturnus", "Entering a room causes 7 tears to orbit Isaac#Those tears last for 13 seconds and deal 1.5x Isaac's damage +5#Enemy projectiles have a chance to orbit Isaac"}, -- Saturnus
	[596] = {"596", "Uranus", "{{Freezing}} Isaac shoots ice tears that freeze enemies on death#Touching a frozen enemy makes it slide away and explode into 10 ice shards"}, -- Uranus
	[597] = {"597", "Neptunus", "{{Tears}} Not shooting builds up a tear bonus over 3 seconds#The tear bonus decreases as Isaac shoots"}, -- Neptunus
	[598] = {"598", "Pluto", "↑ {{Tears}} +0.7 Tears#Significantly shrinks Isaac, allowing him to squeeze between objects#Projectiles can pass over him"}, -- Pluto
	[599] = {"599", "Voodoo Head", "{{CursedRoom}} Spawns an additional Curse Room each floor#Improves Curse Room layouts and rewards#{{Coin}} Spawns a coin in every Curse Room"}, -- Voodoo Head
	[600] = {"600", "Eye Drops", "↑ {{Tears}} x1.4 Fire rate multiplier for the left eye"}, -- Eye Drops
	[601] = {"601", "Act of Contrition", "↑ {{Tears}} +0.7 Tears#{{EternalHeart}} +1 Eternal Heart#{{AngelChance}} Allows Angel Rooms to spawn even after taking a devil deal#Taking Red Heart damage doesn't reduce Devil/Angel Room chance as much"}, -- Act of Contrition
	[602] = {"602", "Member Card", "{{Shop}} Opens a trapdoor in every Shop#The trapdoor leads to an underground shop that sells trinkets, runes, cards, special hearts and items from any pool"}, -- Member Card
	[603] = {"603", "Battery Pack", "{{Battery}} Spawns 2-4 batteries#{{Battery}} Fully recharges the active item"}, -- Battery Pack
	[604] = {"604", "Mom's Bracelet", "Allows Isaac to pick up and throw rocks, TNT, poops, friendly Dips, Hosts and other obstacles#Allows carrying them between rooms"}, -- Mom's Bracelet
	[605] = {"605", "The Scooper", "↑ {{Damage}} x1.35 Damage multiplier for the right eye#{{Timer}} Summons a Peeper familiar for the room, which leaves a trail of red creep and deals 36 contact damage per second"}, -- The Scooper
	[606] = {"606", "Ocular Rift", "5% chance to shoot tears that create rifts where they land#{{Luck}} 20% chance at 15 luck#Rifts do 3x Isaac's damage per second and pull in nearby enemies, pickups, and projectiles"}, -- Ocular Rift
	[607] = {"607", "Boiled Baby", "Shoots chaotic bursts of tears in all directions#Deals 3.5 or 5.25 damage per tear"}, -- Boiled Baby
	[608] = {"608", "Freezer Baby", "Shoots petrifying tears that deal 3.5 damage#{{Freezing}} Freezes enemies upon killing them"}, -- Freezer Baby
	[609] = {"609", "Eternal D6", "Rerolls all pedestal items in the room#Has a 25% chance to delete items instead of rerolling them"}, -- Eternal D6
	[610] = {"610", "Bird Cage", "Leaps on the enemy that deals the first damage to Isaac in a room#Deals 45 damage and releases a rock wave#Chases enemies afterwards for 6.5 contact damage per second"}, -- Bird Cage
	[611] = {"611", "Larynx", "Isaac screams, damages and knocks back nearby enemies#The scream gets stronger the more charges the item has"}, -- Larynx
	[612] = {"612", "Lost Soul", "Dies in one hit and respawns at the start of the next floor#If it is brought alive to the next floor, it can spawn:#{{SoulHeart}} 3 Soul Hearts#{{EternalHeart}} 2 Eternal Hearts#{{TreasureRoom}} A Treasure Room item#{{AngelRoom}} An Angel Room item"}, -- Lost Soul
	[613] = {"613", "", "<Item does not exist>"},
	[614] = {"614", "Blood Bombs", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 4 hearts#{{HalfHeart}} If Isaac has no bombs, one can be placed at the cost of half a heart#Isaac's bombs leave red creep#"}, -- Blood Bombs
	[615] = {"615", "Lil Dumpy", "Deflects an enemy or projectile right before Isaac would take damage from it#Chance to deflect projectiles near it#Needs to be touched after deflecting to be reactivated"}, -- Lil Dumpy
	[616] = {"616", "Bird's Eye", "8% chance to shoot a red fire that blocks enemy shots and deals contact damage#{{Luck}} 50% chance at 10 luck#Fires disappear after blocking 4 shots, dealing damage 4 times or after 10 seconds"}, -- Bird's Eye
	[617] = {"617", "Lodestone", "{{Magnetize}} 17% chance to shoot magnetizing tears#{{Luck}} 100% chance at 5 luck#Magnetized enemies attract nearby pickups, projectiles and enemies"}, -- Lodestone
	[618] = {"618", "Rotten Tomato", "{{Bait}} 17% chance to shoot tears that mark enemies#{{Luck}} 100% chance at 5 luck#Marked enemies are targeted by other enemies"}, -- Rotten Tomato
	[619] = {"619", "Birthright", "Has a different effect for each character"}, -- Birthright
	[620] = {"620", "", "<Item does not exist>"},
	[621] = {"621", "Red Stew", "↑ {{Damage}} +21.6 Damage#{{HealingRed}} Full health#The damage up wears off over 3 minutes#Killing enemies while the effect is active extends it"}, -- Red Stew
	[622] = {"622", "Genesis", "Removes all of Isaac's items and pickups#Teleports Isaac to a bedroom with pickups and chests#For every item removed, Isaac can choose between 3 items from the same pool#Leaving the bedroom takes Isaac to the next floor"}, -- Genesis
	[623] = {"623", "Sharp Key", "{{Key}} +5 Keys#Throws one of Isaac's keys in the direction he shoots#Thrown keys deal damage, destroy obstacles, and open doors#Enemies killed with keys can spawn the contents of a chest, including items"}, -- Sharp Key
	[624] = {"624", "Booster Pack", "{{Card}} Spawns 5 random cards"}, -- Booster Pack
	[625] = {"625", "Mega Mush", "Gigantifies Isaac and grants:#↑ {{Damage}} x4 Damage multiplier#↑ {{Range}} +2 Range#↓ {{Tears}} -1.9 Tears#Invincibility#Ability to crush enemies and obstacles#{{Timer}} Lasts for 30 seconds and persists between rooms and floors"}, -- Mega Mush
	[626] = {"626", "Knife Piece 1", "Turns into a throwable knife that deals 25 damage when combined with {{Collectible627}} Knife Piece 2#The knife can open a door made of flesh"}, -- Knife Piece 1
	[627] = {"627", "Knife Piece 2", "Turns into a throwable knife that deals 25 damage when combined with {{Collectible626}} Knife Piece 1#The knife can open a door made of flesh"}, -- Knife Piece 2
	[628] = {"628", "Death Certificate", "Teleports Isaac to a floor that contains every item in the game#Choosing an item from this floor teleports Isaac back to the room he came from"}, -- Death Certificate
	[629] = {"629", "Bot Fly", "Shoots shielded tears to destroy enemy projectiles#Deals 3 contact damage per second"}, -- Bot Fly
	[630] = {"630", "", "<Item does not exist>"},
	[631] = {"631", "Meat Cleaver", "Splits all enemies in the room into 2 smaller versions with 40% health#Enemies that naturally split (like Envy) take enough damage to split instead#Deals 25 damage to enemies that can't be split"}, -- Meat Cleaver
	[632] = {"632", "Evil Charm", "↑ {{Luck}} +2 Luck#Immune to {{Burning}} burn, {{Confusion}} confusion, {{Fear}} fear, and {{Poison}} poison effects"}, -- Evil Charm
	[633] = {"633", "Dogma", "↑ {{Speed}} +0.1 Speed#↑ {{Damage}} +2 Damage#Flight and one-time {{HolyMantleSmall}} Holy Mantle shield#{{Heart}} Heals Isaac with Red and Soul Hearts if he has less than 6 hearts"}, -- Dogma
	[634] = {"634", "Purgatory", "Red cracks spawn on the ground in hostile rooms#Walking over the cracks summons homing exploding ghosts"}, -- Purgatory
	[635] = {"635", "Stitches", "Spawns a familiar that moves in the direction Isaac shoots#On use, Isaac swaps places with the familiar and becomes briefly invincible#Teleporting onto things can damage or destroy them"}, -- Stitches
	[636] = {"636", "R Key", "Restarts the entire run#All items, trinkets, stats and pickups collected are kept#The timer does not reset"}, -- R Key
	[637] = {"637", "Knockout Drops", "{{Confusion}} 10% chance to shoot a fist that inflicts confusion and extreme knockback#{{Luck}} 100% chance at 9 luck#Enemies take damage when they get knocked into a wall/obstacle"}, -- Knockout Drops
	[638] = {"638", "Eraser", "Throws an eraser that instantly kills an enemy#Prevents the erased enemy from spawning for the rest of the run#Deals 15 damage to bosses#Can only be used once per floor"}, -- Eraser
	[639] = {"639", "Yuck Heart", "{{RottenHeart}} +1 Rotten Heart"}, -- Yuck Heart
	[640] = {"640", "Urn of Souls", "Spews a stream of flames#Killing an enemy adds a charge to the urn"}, -- Urn of Souls
	[641] = {"641", "Akeldama", "Creates a chain of tears behind Isaac in hostile rooms#The tears deal 3.5 damage"}, -- Akeldama
	[642] = {"642", "Magic Skin", "Spawns an item from the current room's item pool#{{BrokenHeart}} Turns 1 heart container or 1 Bone Heart or 2 Soul Hearts into a Broken Heart#{{Warning}} Replaces future items if Isaac isn't holding it {{ColorSilver}}(33% after 1 use, 50% after 2, 100% after 3)#Lower chance if Magic Skin is on a pedestal on the current floor"}, -- Magic Skin
	[643] = {"643", "Revelation", "{{SoulHeart}} +2 Soul Hearts#Flight#{{Chargeable}} Chargeable high damage holy beam#Does not replace Isaac's tears"}, -- Revelation
	[644] = {"644", "Consolation Prize", "↑ Increases Isaac's lowest stat out of Speed, Fire rate, Damage, and Range#Spawns either 3 {{Coin}} coins, 1 {{Bomb}} bomb, or 1 {{Key}} key depending on what Isaac has the least of"}, -- Consolation Prize
	[645] = {"645", "Tinytoma", "Large orbital that blocks shots#Deals 3.5 contact damage per second#Splits into smaller versions of itself upon taking 3 hits#The smaller versions break into blue spiders#Respawns 5 seconds after fully disappearing"}, -- Tinytoma
	[646] = {"646", "Brimstone Bombs", "{{Bomb}} +5 Bombs#{{Collectible118}} Isaac's bombs release a 4-way blood beam#The beams don't hurt Isaac"}, -- Brimstone Bombs
	[647] = {"647", "4.5 Volt", "Clearing rooms no longer charges active items#Dealing damage to enemies slowly fills up the charge bar#Damage needed per charge increases each floor"}, -- 4.5 Volt
	[648] = {"648", "", "<Item does not exist>"},
	[649] = {"649", "Fruity Plum", "Propels herself diagonally around the room, firing tears in her path that deal 3 damage#Deals 6 contact damage per second"}, -- Fruity Plum
	[650] = {"650", "Plum Flute", "{{Timer}} Summons a friendly Baby Plum in the room for 10 seconds"}, -- Plum Flute
	[651] = {"651", "Star of Bethlehem", "Slowly travels from the first room of the floor to the {{BossRoom}} Boss Room#Moves faster if you're ahead of it, and slower if you're behind it#Standing in its aura grants:#↑ {{Tears}} x2.5 Tears multiplier#↑ {{Damage}} x1.8 Damage multiplier#Homing tears#50% chance to ignore damage"}, -- Star of Bethlehem
	[652] = {"652", "Cube Baby", "Can be kicked around by walking into it#{{Slow}} Slows and deals up to 17.5 contact damage depending on speed#{{Freezing}} Freezes enemies it kills"}, -- Cube Baby
	[653] = {"653", "Vade Retro", "Holding the item causes non-ghost enemies to spawn small red ghosts on death#Using the item causes the ghosts to explode#Using the item also kills any ghost enemies (including bosses) that have less than 50% HP left"}, -- Vade Retro
	[654] = {"654", "False PHD", "{{BlackHeart}} +1 Black Heart#{{Pill}} Identifies all pills#Converts all good pills into bad pills#↑ {{Damage}} Eating a stat down pill grants +0.6 damage#{{BlackHeart}} Eating other bad pills spawns a Black Heart"}, -- False PHD
	[655] = {"655", "Spin to Win", "Passively grants an orbital that blocks enemy shots and deals 10.5 contact damage per second#Using the item grants:#↑ {{Speed}} +0.5 Speed#Increases speed and damage of orbitals"}, -- Spin to Win
	[656] = {"656", "Damocles", "Hangs a sword above Isaac's head, which doubles all pedestal items#Does not double items that have a price or come from chests#{{Warning}} After taking any damage, the sword has an extremely low chance to instantly kill Isaac every frame#Invincibility effects can prevent the death"}, -- Damocles (hidden passive version)
	[657] = {"657", "Vasculitis", "Enemies explode into tears upon death, which inherit the effects of Isaac's tears"}, -- Vasculitis
	[658] = {"658", "Giant Cell", "Taking damage spawns a Minisaac#Minisaacs chase and shoot at nearby enemies"}, -- Giant Cell
	[659] = {"659", "Tropicamide", "↑ {{Range}} +2.5 Range#↑ {{Tearsize}} +0.22 Tear size"}, -- Tropicamide
	[660] = {"660", "Card Reading", "Spawns two portals in the first room of each floor#Leaving the room despawns the portals#{{Blank}} {{ColorRed}}Red: {{CR}}{{BossRoom}} Boss Room#{{Blank}} {{ColorYellow}}Yellow: {{CR}}{{TreasureRoom}} Item Room#{{Blank}} {{ColorBlue}}Blue: {{CR}}{{SecretRoom}} Secret Room"}, -- Card Reading
	[661] = {"661", "Quints", "Killing an enemy spawns a stationary familiar in its place#Caps at 5 familiars"}, -- Quints
	[662] = {"662", "", "<Item does not exist>"},
	[663] = {"663", "Tooth and Nail", "1 second of invincibility every 6 seconds#Isaac flashes right before the effect triggers"}, -- Tooth and Nail
	[664] = {"664", "Binge Eater", "↑ {{Heart}} +1 Health#{{HealingRed}} Full health#Item pedestals cycle between their item and a food item#Picking up a food item grants:#{{HealingRed}} Heal 2 hearts#↑ {{Damage}} Temporary +3.6 damage#↑ 2 permanent stat ups (depending on the food)#↓ {{Speed}} -0.03 speed"}, -- Binge Eater
	[665] = {"665", "Guppy's Eye", "Reveals the contents of {{Chest}} chests, {{GrabBag}} sacks, shopkeepers, and fireplaces before they're opened or destroyed"}, -- Guppy's Eye
	[666] = {"666", "", "<Item does not exist>"},
	[667] = {"667", "Strawman", "{{Bomb}} +1 Bomb#{{Player14}} Spawns Keeper as a second character#When he dies, spawns blue spiders and permanently removes Strawman and any item that he has picked up from the inventory#{{DevilRoom}} Devil Room items cost coins while Strawman is alive#{{Warning}} Strawman can pick up story items"}, -- Strawman
	[668] = {"668", "Dad's Note", "Begins the Ascent#Trinkets left in previous {{TreasureRoom}} Treasure or {{BossRoom}} Boss Rooms turn into {{Card78}} Cracked Keys"}, -- Dad's Note
	[669] = {"669", "Sausage", "↑ {{Heart}} +1 Health#↑ {{Speed}} +0.2 Speed#↑ {{Tears}} +0.5 Tears#↑ {{Damage}} +0.5 Damage#↑ {{Range}} +2.5 Range#↑ {{Shotspeed}} +0.16 Shot speed#↑ {{Luck}} +1 Luck#{{HealingRed}} Full health#↑ {{AngelDevilChance}} +6.9% Devil/Angel Room chance#↑ {{PlanetariumChance}} +6.9% Planetarium chance"}, -- Sausage
	[670] = {"670", "Options?", "Allows Isaac to choose from two different room clear rewards"}, -- Options?
	[671] = {"671", "Candy Heart", "↑ Healing with {{Heart}} Red Hearts grants random permanent stat ups#{{Heart}} Spawns a Red Heart"}, -- Candy Heart
	[672] = {"672", "A Pound of Flesh", "{{DevilRoom}} Devil Room items cost coins#{{Shop}} Shop items cost hearts#Consumables in Shops are surrounded by spikes"}, -- A Pound of Flesh
	[673] = {"673", "Redemption", "{{DevilRoom}} Entering a new floor after visiting a Devil Room and not taking any item/pickup grants:#↑ {{Damage}} +1 Damage#{{SoulHeart}} +1 Soul Heart"}, -- Redemption
	[674] = {"674", "Spirit Shackles", "Taking fatal damage transforms Isaac into a ghost chained to his dead body and allows him to continue to fight with half a heart#If the ghost survives, Isaac revives after 10 seconds#Must be recharged by picking up a Soul Heart"}, -- Spirit Shackles
	[675] = {"675", "Cracked Orb", "Taking damage:#Unlocks all locked doors in the room#Reveals a random room on the map#Destroys all tinted and crawlspace rocks"}, -- Cracked Orb
	[676] = {"676", "Empty Heart", "{{EmptyHeart}} +1 Empty heart container when at 1 Red Heart or less at the start of a new floor"}, -- Empty Heart
	[677] = {"677", "Astral Projection", "{{Timer}} Taking damage in an uncleared room grants for the fight:#Spectral tears#Flight#Negates the next damage taken#Stops time for 2 seconds#Greatly increases speed and fire rate for 2 seconds"}, -- Astral Projection
	[678] = {"678", "C Section", "{{Chargeable}} Replaces Isaac's tears with a charge attack that shoots homing, spectral fetus tears#{{Damage}} Fetus tears deal about 2.8x Isaac's damage per second"}, -- C Section
	[679] = {"679", "Lil Abaddon", "{{Collectible399}} Familiar that charges and unleashes a Maw of the Void circle#It deals 52.5 damage over 1 second"}, -- Lil Abaddon
	[680] = {"680", "Montezuma's Revenge", "{{Chargeable}} Firing charges up a short-ranged high damage backwards beam#Does not replace Isaac's tears"}, -- Montezuma's Revenge
	[681] = {"681", "Lil Portal", "Deals contact damage and flies forward#Consumes pickups in its path#Each pickup consumed increases its size, damage, and spawns a blue fly#Consuming four pickups spawns a portal to an unexplored room"}, -- Lil Portal
	[682] = {"682", "Worm Friend", "Sometimes bursts out of the ground and grabs an enemy#Grabbed enemies take 8 damage per second, are slowed and cannot move"}, -- Worm Friend
	[683] = {"683", "Bone Spurs", "Enemies spawn bone shards on death#Bones block projectiles and deal contact damage"}, -- Bone Spurs
	[684] = {"684", "Hungry Soul", "Killing an enemy has a chance to spawn a ghost#Ghosts chase enemies, deal contact damage and explode after 5 seconds#Isaac doesn't take damage from the explosion"}, -- Hungry Soul
	[685] = {"685", "Jar of Wisps", "Spawns a random wisp#Spawns one additional wisp with each use, up to 12"}, -- Jar of Wisps
	[686] = {"686", "Soul Locket", "↑ Picking up {{SoulHeart}} Soul Hearts grants random permanent stat ups#{{SoulHeart}} Spawns a Soul Heart"}, -- Soul Locket
	[687] = {"687", "Friend Finder", "Spawns a random friendly monster that mimics Isaac's movements and attacks"}, -- Friend Finder
	[688] = {"688", "Inner Child", "+1 Life#Upon death:#Respawns Isaac in the same room with half a heart#↑ {{Speed}} +0.2 Speed#↑ Massive size down"}, -- Inner Child
	[689] = {"689", "Glitched Crown", "Item pedestals quickly cycle between 5 random items"}, -- Glitched Crown
	[690] = {"690", "Belly Jelly", "Enemies bounce off of Isaac#50% chance to negate contact damage#50% chance to deflect enemy projectiles"}, -- Belly Jelly
	[691] = {"691", "Sacred Orb", "Prevents Quality {{Quality0}}/{{Quality1}} items from spawning#Quality {{Quality2}} items have a 33% chance to be rerolled"}, -- Sacred Orb
	[692] = {"692", "Sanguine Bond", "Spawns a set of spikes in the {{DevilRoom}} Devil Room#Taking damage on the spikes grants:#35%: Nothing#33%: ↑ {{Damage}} +0.5 Damage#15%: 6 {{Coin}} pennies#10%: 2 {{BlackHeart}} Black Hearts#5%: {{DevilRoom}} Random Devil item#2%: Leviathan transformation"}, -- Sanguine Bond
	[693] = {"693", "The Swarm", "Grants 8 orbital flies#Clearing a room spawns a new fly#Flies turn into blue flies after blocking a shot"}, -- The Swarm
	[694] = {"694", "Heartbreak", "↑ {{Damage}} +0.25 Damage for each Broken Heart#{{BrokenHeart}} +3 Broken Hearts#{{BrokenHeart}} Every fatal hit grants +2 Broken Hearts#Isaac dies at 12 Broken Hearts"}, -- Heartbreak
	[695] = {"695", "Bloody Gust", "When taking damage, receive for the floor:#↑ {{Speed}} Speed up#↑ {{Tears}} Fire rate up#Caps at +1.02 speed and +3 fire rate"}, -- Bloody Gust
	[696] = {"696", "Salvation", "Isaac is surrounded by a halo#Enemies that stand in the halo for too long are hit by a cross-shaped beam of light#Taking damage increases the size of the halo for the floor"}, -- Salvation
	[697] = {"697", "Vanishing Twin", "Entering a boss room spawns a clone of the boss#Defeating the clone spawns an extra item#The clone is slower and has 75% health"}, -- Vanishing Twin
	[698] = {"698", "Twisted Pair", "Two familiars that shoot tears with the same stats and effects as Isaac#{{Damage}} They deal 37.5% of Isaac's damage"}, -- Twisted Pair
	[699] = {"699", "Azazel's Rage", "{{Collectible118}} Clearing 4 rooms fires a large Brimstone beam upon entering the next room"}, -- Azazel's Rage
	[700] = {"700", "Echo Chamber", "Using a {{Rune}} rune, {{Card}} card or {{Pill}} pill also uses a copy of the last 3 runes/cards/pills used after picking up Echo Chamber"}, -- Echo Chamber
	[701] = {"701", "Isaac's Tomb", "Spawns an {{DirtyChest}} Old Chest at the start of every floor#Old Chests require a key to unlock and can contain {{SoulHeart}} Soul Hearts, {{Trinket}} trinkets or Mom, Dad and Angel items"}, -- Isaac's Tomb
	[702] = {"702", "Vengeful Spirit", "Taking damage spawns an orbital wisp#Wisps shoot tears, do not block shots and disappear on the next floor#Caps at 6 wisps"}, -- Vengeful Spirit
	[703] = {"703", "Esau Jr.", "Swaps between the current character and Esau Jr.#Esau Jr. has {{BlackHeart}} 3 Black Hearts, {{Damage}} +2 Damage, flight, and random items equal to the number of items the player has the first time this item is used#Characters have independent items and health#{{Warning}} Dying as either character ends the run"}, -- Esau Jr.
	[704] = {"704", "Berserk!", "{{Battery}} Charges with damage dealt#{{Timer}} Receive for 5 seconds:#↑ {{Speed}} +0.4 Speed#↓ {{Tears}} x0.5 Fire rate multiplier#↑ {{Tears}} +2 Fire rate#↑ {{Damage}} +3 Damage#Restricts attacks to a melee that reflects shots#{{Timer}} Each kill increases the duration by 1 second and grants brief invincibility"}, -- Berserk!
	[705] = {"705", "Dark Arts", "{{Timer}} Receive for 1 second (or until shooting):↑ {{Speed}} +1 Speed#Isaac can pass through enemies/projectiles and paralyzes them#When the effect ends, damages paralyzed enemies, removes paralyzed projectiles and creates a blast at Isaac's location#The attacks and blast are more powerful the more enemies/projectiles have been hit"}, -- Dark Arts
	[706] = {"706", "Abyss", "Consumes all item pedestals in the room and spawns a locust familiar for each one#Locusts deal Isaac's damage 2-3 times an attack#Some items spawn a special locust when consumed"}, -- Abyss
	[707] = {"707", "Supper", "↑ {{Heart}} +1 Health#{{HealingRed}} Heals 1 heart"}, -- Supper
	[708] = {"708", "Stapler", "↑ {{Damage}} +1 Damage#All of Isaac's tears are shot from the right eye"}, -- Stapler
	[709] = {"709", "Suplex!", "Isaac dashes in the direction he moves#Dashing into an enemy or boss picks it up and slams it into the ground#Slam deals damage and spawns rock waves based on Isaac's size#You're invincible during the dash and slam"}, -- Suplex!
	[710] = {"710", "Bag of Crafting", "Collects up to 8 pickups which cannot be dropped#Using the item with 8 pickups in the bag crafts an item#Item quality is based on the quality of the pickups"}, -- Bag of Crafting
	[711] = {"711", "Flip", "Entering a room with item pedestals displays a ghostly second item on the pedestals#Using the item flips the real and ghostly item#Using Flip after taking the first item allows Isaac to pick up the other item#{{Warning}} Ghostly items alone on pedestals disappear after leaving the room"}, -- Flip
	[712] = {"712", "Lemegeton", "Spawns an orbital that grants a random item's effect#The items have a 25% chance to be from the current room's item pool and 75% chance to be from the Treasure, Boss or Shop pools"}, -- Lemegeton
	[713] = {"713", "Sumptorium", "Removes half a heart and creates a clot#Clots copy Isaac's tears#Each type of heart generates a clot with different HP, damage and tear effect"}, -- Sumptorium
	[714] = {"714", "Recall", "Retrieves the Forgotten's body from any distance#The Soul is invincible while the Forgotten is returning"}, -- Recall
	[715] = {"715", "Hold", "Using the item when empty stores the next poop inside#Using the item with a poop inside uses that poop"}, -- Hold
	[716] = {"716", "Keeper's Sack", "Spawns 3 {{Coin}} coins and 1 {{Key}} key#{{Shop}} Spending 3 coins grants either:#↑ {{Speed}} +0.03 Speed#↑ {{Damage}} +0.5 Damage#↑ {{Range}} +0.25 Range"}, -- Keeper's Sack
	[717] = {"717", "Keeper's Kin", "Rocks and other obstacles spawn 2 blue spiders when destroyed#Rocks can occasionally spawn blue spiders in hostile rooms"}, -- Keeper's Kin
	[718] = {"718", "", "<Item does not exist>"},
	[719] = {"719", "Keeper's Box", "{{Shop}} Spawns a random Shop item/pickup to be purchased"}, -- Keeper's Box
	[720] = {"720", "Everything Jar", "Spawns pickups based on the number of charges#Charge Rewards:#{{Blank}} 1:{{PoopPickup}} 2:{{Coin}} 3:{{Bomb}} 4:{{Key}}#{{Blank}} 5:{{Heart}} 6:{{Pill}} 7:{{Card}} 8:{{SoulHeart}}#{{Blank}} 9:{{GoldenHeart}} 10:{{GoldenKey}} 11:{{GoldenBomb}}#{{Blank}} Triggers a powerful random effect at 12 charges"}, -- Everything Jar
	[721] = {"721", "TMTRAINER", "Causes all future items to be glitched#Glitched items have completely random effects"}, -- TMTRAINER
	[722] = {"722", "Anima Sola", "Chains down the nearest enemy for 5 seconds#Chained enemies cannot move or attack"}, -- Anima Sola
	[723] = {"723", "Spindown Dice", "Rerolls all items in the room by decreasing their internal ID by one"}, -- Spindown Dice
	[724] = {"724", "Hypercoagulation", "{{Heart}} Taking damage drops a half or full Red Heart depending on how much Isaac lost#The hearts launch out and despawn after 1.5 seconds"}, -- Hypercoagulation
	[725] = {"725", "IBS", "Dealing enough damage causes Isaac to flash red#Releasing the fire button while Isaac is flashing either:#Throws a random poop#Creates buffing creep#{{Poison}} Farts a poison cloud#Spawns 5 live bombs"}, -- IBS
	[726] = {"726", "Hemoptysis", "Double-tapping a fire button makes Isaac sneeze blood#The sneeze deals 1.5x Isaac's damage#1 second cooldown#{{BrimstoneCurse}} Affected enemies take extra damage from Brimstone beams"}, -- Hemoptysis
	[727] = {"727", "Ghost Bombs", "{{Bomb}} +5 Bombs#Isaac's bombs spawn ghosts that chase enemies#Ghosts deal 2x Isaac's damage per second and explode after 10 seconds"}, -- Ghost Bombs
	[728] = {"728", "Gello", "A demon familiar bursts out of Isaac for the room#The demon shoots towards the nearest enemy, mimicing Isaac's tears, stats and effects#{{Damage}} Its tears deal 75% of Isaac's damage"}, -- Gello
	[729] = {"729", "Decap Attack", "Throws Isaac's head in a direction#The head deals contact damage and shoots tears from where it lands#Using the item again or stepping on the head reattaches it"}, -- Decap Attack
	[730] = {"730", "Glass Eye", "↑ {{Damage}} +0.75 Damage#↑ {{Luck}} +1 Luck"}, -- Glass Eye
	[731] = {"731", "Stye", "↑ {{Damage}} x1.28 Damage multiplier for the right eye#↑ {{Range}} +6.5 Range for the right eye#↓ {{Shotspeed}} -0.3 Shot speed for the right eye"}, -- Stye
	[732] = {"732", "Mom's Ring", "↑ {{Damage}} +1 Damage#{{Rune}} Spawns a random rune or soul stone"}, -- Mom's Ring
}
local repCards = {
	[2] = {"2", "I - The Magician", "{{Timer}} Receive for the room:#↑ {{Range}} +3 Range#Homing tears"}, -- I - The Magician
	[12] = {"12", "XI - Strength", "{{Timer}} Receive for the room:#↑ {{Heart}} +1 Health#↑ {{Speed}} +0.3 Speed#↑ {{Damage}} +0.3 Damage#↑ {{Damage}} x1.5 Damage multiplier#↑ {{Range}} +2.5 Range"}, -- XI - Strength
	[16] = {"16", "XV - The Devil", "{{Timer}} Receive for the room:#↑ {{Damage}} +2 Damage"}, -- XV - The Devil
	[18] = {"18", "XVII - The Stars", "{{TreasureRoom}} Teleports Isaac to the Treasure Room#{{Planetarium}} If there is a Planetarium, it teleports there instead"}, -- XVII - The Stars
	[27] = {"27", "Ace of Clubs", "{{Bomb}} Turns all pickups, chests and non-boss enemies into random bombs"}, -- Ace of Clubs
	[28] = {"28", "Ace of Diamonds", "{{Coin}} Turns all pickups, chests and non-boss enemies into random coins"}, -- Ace of Diamonds
	[29] = {"29", "Ace of Spades", "{{Key}} Turns all pickups, chests and non-boss enemies into random keys"}, -- Ace of Spades
	[30] = {"30", "Ace of Hearts", "{{UnknownHeart}} Turns all pickups, chests and non-boss enemies into random hearts"}, -- Ace of Hearts
	[34] = {"34", "Ehwaz", "Spawns a trapdoor to the next floor#{{LadderRoom}} Spawns a crawlspace if used on a decorative floor tile (grass, small rocks, papers, gems, etc.)"}, -- Ehwaz
	[39] = {"39", "Algiz", "{{Timer}} Makes Isaac invincible for 20 seconds"}, -- Algiz
	[42] = {"42", "Chaos Card", "Using the card throws it in the direction Isaac is moving#Instantly kills ANY enemy it touches (except Delirium or the Beast)"}, -- Chaos Card
	[51] = {"51", "Holy Card", "{{HolyMantle}} A one-use Holy Mantle shield (prevents damage once)"}, -- Holy Card
	[52] = {"52", "Huge Growth", "{{Timer}} Receive for the room:#↑ {{Damage}} +7 Damage#↑ {{Range}} +3 Range#Size up#Allows Isaac to destroy rocks by walking into them"}, -- Huge Growth
	[55] = {"55", "Rune Shard", "{{Rune}} Activates a random rune effect#The rune effect is weaker"}, -- Rune Shard
	[56] = {"56", "0 - The Fool?", "Drops all of Isaac's hearts but one and all of his pickups on the floor#Coins and bombs are dropped as {{Collectible74}} The Quarter or {{Collectible19}} Boom! if possible"}, -- 0 - The Fool?
	[57] = {"57", "I - The Magician?", "{{Timer}} Grants an aura that repels enemies and projectiles for 60 seconds"}, -- I - The Magician?
	[58] = {"58", "II - The High Priestess?", "{{Timer}} Mom's Foot tries to stomp Isaac for 60 seconds"}, -- II - The High Priestess?
	[59] = {"59", "III - The Empress?", "{{Timer}} Receive for 60 seconds:#↑ {{Heart}} +2 Health#↑ {{Tears}} +1.5 Fire rate#↓ {{Speed}} -0.1 Speed"}, -- III - The Empress?
	[60] = {"60", "IV - The Emperor?", "Teleports Isaac to an extra Boss room that can be defeated for an item#The boss is chosen from two floors deeper than the current one"}, -- IV - The Emperor?
	[61] = {"61", "V - The Hierophant?", "{{EmptyBoneHeart}} Spawns 2 Bone Hearts"}, -- V - The Hierophant?
	[62] = {"62", "VI - The Lovers?", "Spawns an item from the current room's item pool#{{BrokenHeart}} Converts 1 heart container or 2 Soul Hearts into a Broken Heart"}, -- VI - The Lovers?
	[63] = {"63", "VII - The Chariot?", "{{Timer}} Receive for 10 seconds:#↑ {{Tears}} x4 Fire rate multiplier#Invincible but can't move"}, -- VII - The Chariot?
	[64] = {"64", "VIII - Justice?", "{{GoldenChest}} Spawns 2-4 golden chests"}, -- VIII - Justice?
	[65] = {"65", "IX - The Hermit?", "{{Coin}} Turns all pickups and items in the room into a number of coins equal to their Shop value#If there is nothing to turn, spawns a Penny instead"}, -- IX - The Hermit?
	[66] = {"66", "X - Wheel of Fortune?", "{{DiceRoom}} Triggers a random Dice Room effect"}, -- X - Wheel of Fortune?
	[67] = {"67", "XI - Strength?", "{{Timer}} Enemies in the room are {{Slow}} slowed and take double damage for 30 seconds"}, -- XI - Strength?
	[68] = {"68", "XII - The Hanged Man?", "{{Timer}} Receive for 30 seconds:#↓ {{Speed}} -0.1 Speed#Triple shot#{{Coin}} Killed enemies drop coins"}, -- XII - The Hanged Man?
	[69] = {"69", "XIII - Death?", "{{Collectible545}} Activates Book of the Dead#Spawns Bone entities for each enemy killed in room"}, -- XIII - Death?
	[70] = {"70", "XIV - Temperance?", "{{Pill}} Forces Isaac to eat 5 random pills"}, -- XIV - Temperance?
	[71] = {"71", "XV - The Devil?", "{{Timer}} Receive for 60 seconds:#{{Collectible33}} Activates The Bible (flight)#{{Collectible390}} Seraphim familiar#{{MomsHeart}} Kills Mom's Foot and Mom's Heart instantly#{{Warning}} Kills Isaac when used on Satan"}, -- XV - The Devil?
	[72] = {"72", "XVI - The Tower?", "Spawns 7 clusters of random rocks and obstacles#Clusters often contain Tinted Rocks"}, -- XVI - The Tower?
	[73] = {"73", "XVII - The Stars?", "Removes Isaac's oldest collected passive item (ignoring starting items)#Spawns 2 random items from the current room's item pool"}, -- XVII - The Stars?
	[74] = {"74", "XVIII - The Moon?", "{{UltraSecretRoom}} Teleports Isaac to the Ultra Secret Room#Pathway back will be made of red rooms"}, -- XVIII - The Moon?
	[75] = {"75", "XIX - The Sun?", "{{Timer}} Receive for the floor:#↑ {{Damage}} +1.5 Damage#Flight and spectral tears#{{BoneHeart}} Converts heart containers into Bone Hearts (reverts)#{{CurseDarkness}} Curse of Darkness"}, -- XIX - The Sun?
	[76] = {"76", "XX - Judgement?", "{{RestockMachine}} Spawns a Restock Machine"}, -- XX - Judgement?
	[77] = {"77", "XXI - The World?", "{{LadderRoom}} Spawns a trapdoor to a crawlspace"}, -- XXI - The World?
	[78] = {"78", "Cracked Key", "{{Collectible580}} Single-use Red Key"}, -- Cracked Key
	[79] = {"79", "Queen of Hearts", "{{Heart}} Spawns 1-20 Red Hearts"}, -- Queen of Hearts
	[80] = {"80", "Wild Card", "Copies the effect of your most recently used pill, card, rune, soul stone or activated item"}, -- Wild Card
	[81] = {"81", "Soul of Isaac", "Makes all item pedestals in the room cycle between two different items"}, -- Soul of Isaac
	[82] = {"82", "Soul of Magdalene", "{{Timer}} Effect lasts for the room:#{{HalfHeart}} Enemies killed drop half Red Hearts that disappear after 2 seconds"}, -- Soul of Magdalene
	[83] = {"83", "Soul of Cain", "Opens all doors in the room#{{Collectible580}} Creates red rooms on every wall possible"}, -- Soul of Cain
	[84] = {"84", "Soul of Judas", "{{Collectible705}} Activates Dark Arts with a 3 second duration#Temporary ↑ {{Damage}} damage up for every enemy/projectile hit"}, -- Soul of Judas
	[85] = {"85", "Soul of ???", "{{Poison}} Causes 8 poison farts with brown creep, then quickly spawns 7 Butt Bombs#Standing on the creep grants:#↑ {{Tears}} +1.5 Fire rate#↑ {{Damage}} +1 Damage"}, -- Soul of ???
	[86] = {"86", "Soul of Eve", "{{Timer}} 14 Dead Bird familiars fly in and attack enemies for the room"}, -- Soul of Eve
	[87] = {"87", "Soul of Samson", "{{Collectible704}} Activates Berserk! for 10 seconds#{{Timer}} Each kill increases the duration by 1 second"}, -- Soul of Samson
	[88] = {"88", "Soul of Azazel", "{{Collectible441}} Fires a Mega Blast beam for 7.5 seconds"}, -- Soul of Azazel
	[89] = {"89", "Soul of Lazarus", "Isaac dies and immediately revives at half a heart#This item is automatically used upon taking fatal damage (acts as an extra life)"}, -- Soul of Lazarus
	[90] = {"90", "Soul of Eden", "Rerolls item pedestals and pickups in the room#The rerolled items come from random item pools"}, -- Soul of Eden
	[91] = {"91", "Soul of the Lost", "{{Player10}} Turns the player into The Lost for the room#Allows taking one {{DevilRoom}} Devil Room item for free#Allows entering the Mausoleum or Gehenna door for free"}, -- Soul of the Lost
	[92] = {"92", "Soul of Lilith", "Permanently grants a random familiar"}, -- Soul of Lilith
	[93] = {"93", "Soul of the Keeper", "{{Coin}} Spawns 1-25 random coins"}, -- Soul of the Keeper
	[94] = {"94", "Soul of Apollyon", "Spawns 15 random locusts"}, -- Soul of Apollyon
	[95] = {"95", "Soul of the Forgotten", "{{Player16}} Spawns The Forgotten as a secondary character for the room"}, -- Soul of the Forgotten
	[96] = {"96", "Soul of Bethany", "{{Collectible584}} Spawns 6 random Book of Virtues wisps"}, -- Soul of Bethany
	[97] = {"97", "Soul of Jacob and Esau", "{{Player20}} Spawns Esau as a secondary character for the room#He spawns with as many passive items as the player"}, -- Soul of Jacob and Esau
}
local repPills = {
	[3] = {"3", "Bombs are Key", "Swaps Isaac's number of {{Bomb}} bombs and {{Key}} keys#Golden bombs and keys are also swapped"}, -- Bombs are Key
	[11] = {"11", "Range Down", "↓ {{Range}} -1 Range"}, -- Range Down
	[12] = {"12", "Range Up", "↑ {{Range}} +1.25 Range"}, -- Range Up
	[37] = {"37", "Retro Vision", "{{Timer}} Pixelates the screen for 30 seconds"},
	[41] = {"41", "I'm Drowsy...", "{{Slow}} Slows Isaac and all enemies in the room"}, -- I'm Drowsy...
	[42] = {"42", "I'm Excited!!", "{{Timer}} Speeds up Isaac and all enemies in the room#Triggers again after 30 and 60 seconds"}, -- I'm Excited!!
	[47] = {"47", "Shot speed Down", "↓ {{Shotspeed}} -0.15 Shot speed"}, -- Shot speed Down
	[48] = {"48", "Shot speed Up", "↑ {{Shotspeed}} +0.15 Shot speed"}, -- Shot speed Up
	[49] = {"49", "Experimental Pill", "↑ Increases 1 random stat#↓ Decreases 1 random stat"}, -- Experimental Pill
	[9999] = {"", "Golden Pill", "Random pill effect#Has a chance to destroy itself with each use"}, -- golden Pill
}
local repTrinkets = {
	[10] = {"10", "Wiggle Worm", "↑ {{Tears}} +0.4 Tears#Spectral tears#Isaac's tears move in waves"}, -- Wiggle Worm
	[11] = {"11", "Ring Worm", "↑ {{Tears}} +0.47 Tears#Spectral tears#Isaac's tears move in spirals with high speed"}, -- Ring Worm
	[15] = {"15", "Lucky Rock", "{{Coin}} Destroying rocks has a 33% chance to spawn a coin"},-- Lucky Rock
	[16] = {"16", "Mom's Toenail", "Mom's Foot stomps a random spot in the room every 20 seconds"}, -- Mom's Toenail
	[24] = {"24", "Butt Penny", "{{Coin}} 20% higher chance for coins to spawn from poop#{{Poison}} Picking up coins makes Isaac fart, which poisons and knocks back enemies and projectiles"}, -- Butt Penny
	[26] = {"26", "Hook Worm", "↑ {{Tears}} +0.4 Tears#↑ {{Range}} +1.5 Range#Spectral tears#Isaac's tears move in angular patterns"}, -- Hook Worm
	[32] = {"32", "Liberty Cap", "25% chance for a random mushroom effect per room"}, -- Liberty Cap
	[33] = {"33", "Umbilical Cord", "{{HalfHeart}} Having half a Red Heart or less grants {{Collectible100}} Little Steven#{{Collectible318}} Taking damage has a high chance to spawn a Gemini familiar for the room"}, -- Umbilical Cord
	[39] = {"39", "Cancer", "↑ {{Tears}} +1 Fire rate"}, -- Cancer
	[48] = {"48", "A Missing Page", "Taking damage has a 5% chance to deal 80 damage to all enemies in the room#{{Collectible35}} Black Hearts and Necronomicon-like effects deal double damage"}, -- A Missing Page
	[49] = {"49", "Bloody Penny", "{{HalfHeart}} Picking up a coin has a 25% chance to spawn a half Red Heart#Higher chance from nickels and dimes"}, -- Bloody Penny
	[50] = {"50", "Burnt Penny", "{{Bomb}} Picking up a coin has a 25% chance to spawn a bomb#Higher chance from nickels and dimes"}, -- Burnt Penny
	[51] = {"51", "Flat Penny", "{{Key}} Picking up a coin has a 25% chance to spawn a key#Higher chance from nickels and dimes"}, -- Flat Penny
	[65] = {"65", "Tape Worm", "↑ {{Range}} +3 Range"}, -- Tape Worm
	[66] = {"66", "Lazy Worm", "↓ {{Shotspeed}} -0.5 Shot speed"}, -- Lazy Worm
	[67] = {"67", "Cracked Dice", "Taking damage has a 50% chance to trigger one of these effects:#{{Collectible105}} D6#{{Collectible406}} D8#{{Collectible285}} D10#{{Collectible386}} D12#{{Collectible166}} D20"}, -- Cracked Dice
	[69] = {"69", "Faded Polaroid", "Randomly camouflages Isaac#{{Confusion}} Confuses enemies#Can be used to open the \"Strange Door\" in \"Depths II\""}, -- Faded Polaroid
	[80] = {"80", "Black Feather", "↑ {{Damage}} +0.5 Damage for each \"Evil up\" item held"}, -- Black Feather
	[92] = {"92", "Cracked Crown", "↑ x1.33 Stat multiplier (except fire rate) for the stats that are above 1 {{Speed}} speed, 2.73 {{Tears}} tears, 3.5 {{Damage}} damage, 6.5 {{Range}} range, 1 {{Shotspeed}} shot speed"}, -- Cracked Crown
	[96] = {"96", "Ouroboros Worm", "↑ +0.4 Tears#↑ {{Range}} +1.5 Range#Spectral tears#Chance for homing tears#{{Luck}} 100% chance at 9 luck#Isaac's tears move quickly in a spiral pattern"}, -- Ouroboros Worm
	[98] = {"98", "Nose Goblin", "5% chance to shoot homing sticky tears#{{Damage}} Boogers deal Isaac's damage once per second#Boogers stick for 10 seconds"}, -- Nose Goblin
	[101] = {"101", "Dim Bulb", "Holding a completely uncharged active item grants:#↑ {{Speed}} +0.5 Speed#↑ {{Tears}} +0.5 Tears#↑ {{Damage}} +1.5 Damage#↑ {{Range}} +1.5 Range#↑ {{Shotspeed}} +0.3 Shot speed#↑ {{Luck}} +2 Luck"}, -- Dim Bulb
	[107] = {"107", "Crow Heart", "Taking damage depletes Red Hearts before Soul/Black Hearts#{{Warning}} The Red Heart damage can lower your Devil/Angel Room chance"}, -- Crow Heart
	[110] = {"110", "Silver Dollar", "{{Shop}} Shops appear in the Womb and Corpse"}, -- Silver Dollar
	[111] = {"111", "Bloody Crown", "{{TreasureRoom}} Treasure Rooms appear in the Womb and Corpse"}, -- Bloody Crown
	[119] = {"119", "Stem Cell", "{{HealingRed}} Entering a new floor heals half of Isaac's empty Red/Bone Hearts#{{HealingRed}} Heals half a heart minimum"}, -- Stem Cell
	[125] = {"125", "Extension Cord", "Connects all familiars with beams of electricity#The beams deal 6 damage"}, -- Extension Cord
	[128] = {"128", "Finger Bone", "{{EmptyBoneHeart}} Taking damage has a 4% chance to grant a Bone Heart"}, -- Finger Bone
	[129] = {"129", "Jawbreaker", "{{Damage}} 10% chance to shoot teeth that deal 3.2x Isaac's damage#{{Luck}} 100% chance at 9 luck"}, -- Jawbreaker
	[130] = {"130", "Chewed Pen", "{{Slow}} 10% chance to shoot slowing tears#{{Luck}} 100% chance at 18 luck"}, -- Chewed Pen
	[131] = {"131", "Blessed Penny", "{{HalfSoulHeart}} Picking up a coin has a 17% chance to spawn a half Soul Heart#Higher chance from nickels and dimes"}, -- Blessed Penny
	[132] = {"132", "Broken Syringe", "25% chance to get a random syringe effect each room"}, -- Broken Syringe
	[133] = {"133", "Short Fuse", "Isaac's bombs explode faster"}, -- Short Fuse
	[134] = {"134", "Gigante Bean", "Increases fart size"}, -- Gigante Bean
	[135] = {"135", "A Lighter", "{{Burning}} Entering a room has a 20% chance to burn random enemies"}, -- A Lighter
	[136] = {"136", "Broken Padlock", "Doors, key blocks and golden chests can be opened with explosions#Explosions can also open the \"Strange Door\" in \"Depths II\""}, -- Broken Padlock
	[137] = {"137", "Myosotis", "Entering a new floor spawns up to 4 uncollected pickups from the previous floor in the starting room"}, -- Myosotis
	[138] = {"138", "'M", "Using an active item rerolls it"}, -- 'M
	[139] = {"139", "Teardrop Charm", "{{Luck}} +4 Luck towards luck-based tear effects"}, -- Teardrop Charm
	[140] = {"140", "Apple of Sodom", "Picking up Red Hearts can convert them into blue spiders#Works even while at full health#Effect may consume hearts needed for healing"}, -- Apple of Sodom
	[141] = {"141", "Forgotten Lullaby", "Doubles the fire rate of familiars"}, -- Forgotten Lullaby
	[142] = {"142", "Beth's Faith", "{{Collectible584}} Entering a new floor spawns 4 Book of Virtues wisps"}, -- Beth's Faith
	[143] = {"143", "Old Capacitor", "{{Battery}} Prevents active item from charging by clearing a room#{{Battery}} Clearing a room has a 20% chance to spawn a battery#{{Luck}} 33% chance at 5 luck"}, -- Old Capacitor
	[144] = {"144", "Brain Worm", "Tears turn 90 degrees to target enemies that they may have missed"}, -- Brain Worm
	[145] = {"145", "Perfection", "↑ {{Luck}} +10 Luck up#Taking damage destroys the trinket"}, -- Perfection
	[146] = {"146", "Devil's Crown", "{{RedTreasureRoom}} Treasure Room items are replaced with devil deals"}, -- Devil's Crown
	[147] = {"147", "Charged Penny", "{{Battery}} Picking up a coin has a 17% chance to add 1 charge to the active item#Higher chance from nickels and dimes"}, -- Charged Penny
	[148] = {"148", "Friendship Necklace", "All familiars orbit around Isaac"}, -- Friendship Necklace
	[149] = {"149", "Panic Button", "Right before taking damage, uses the active item if it is charged"}, -- Panic Button
	[150] = {"150", "Blue Key", "Locked doors can be opened for free, but Isaac has to clear a room from the Hush floor before accessing the room behind them"}, -- Blue Key
	[151] = {"151", "Flat File", "Retracts most spikes, rendering them harmless#Also affects {{CursedRoom}} Curse Room doors, mimics and any spike obstacle"}, -- Flat File
	[152] = {"152", "Telescope Lens", "{{PlanetariumChance}} +9% Planetarium chance#Additional +15% chance if a Planetarium hasn't been entered yet#Planetariums can spawn in the Womb and Corpse"}, -- Telescope Lens
	[153] = {"153", "Mom's Lock", "25% chance for a random Mom item effect each room"}, -- Mom's Lock
	[154] = {"154", "Dice Bag", "50% chance per new room to grant a single use die consumable item#The die disappears when leaving#The die does not take up a pill/card slot"}, -- Dice Bag
	[155] = {"155", "Holy Crown", "Spawns a {{TreasureRoom}} Treasure Room and {{Shop}} Shop in Cathedral"}, -- Holy Crown
	[156] = {"156", "Mother's Kiss", "{{Heart}} +1 Heart container while held"}, -- Mother's Kiss
	[157] = {"157", "Torn Card", "Every 15 shots, Isaac shoots an {{Collectible149}} Ipecac + {{Collectible5}} My Reflection tear with a very high range value"}, -- Torn Card
	[158] = {"158", "Torn Pocket", "Taking damage makes Isaac drop 2 of his coins, keys or bombs#The pickups can be replaced with other variants, such as golden keys, nickels, dimes, etc."}, -- Torn Pocket
	[159] = {"159", "Gilded Key", "{{Key}} +1 Key on pickup#{{GoldenChest}} Replaces all chests (except Old/Mega) with golden chests#{{GoldenChest}} Golden chests can contain extra cards, pills or trinkets"}, -- Gilded Key
	[160] = {"160", "Lucky Sack", "{{GrabBag}} Entering a new floor spawns a sack"}, -- Lucky Sack
	[161] = {"161", "Wicked Crown", "Spawns a {{TreasureRoom}} Treasure Room and {{Shop}} Shop in Sheol"}, -- Wicked Crown
	[162] = {"162", "Azazel's Stump", "{{Player7}} Clearing a room has a 50% chance to turn the player into Azazel#{{Timer}} Effect lasts until clearing and leaving another room"}, -- Azazel's Stump
	[163] = {"163", "Dingle Berry", "All Dip (small poop) enemies are friendly#Clearing a room spawns 1 random Dip"}, -- Dingle Berry
	[164] = {"164", "Ring Cap", "{{Bomb}} Spawns 1 extra bomb for each bomb placed"}, -- Ring Cap
	[165] = {"165", "Nuh Uh!", "On Womb and beyond, replaces all coin and key spawns with a bomb, heart, pill, card, trinket, battery, or enemy fly"}, -- Nuh Uh!
	[166] = {"166", "Modeling Clay", "50% chance to grant the effect of a random passive item each room"}, -- Modeling Clay
	[167] = {"167", "Polished Bone", "Clearing a room has a 25% chance to spawn a friendly Bony"}, -- Polished Bone
	[168] = {"168", "Hollow Heart", "{{EmptyBoneHeart}} Entering a new floor grants +1 Bone Heart"}, -- Hollow Heart
	[169] = {"169", "Kid's Drawing", "{{Guppy}} Counts as 1 item towards the Guppy transformation while held"}, -- Kid's Drawing
	[170] = {"170", "Crystal Key", "{{Collectible580}} Clearing a room has a 33% chance to create a Red Key room#Lower chance to occur when in a red room"}, -- Crystal Key
	[171] = {"171", "Keeper's Bargain", "{{DevilRoom}} 50% chance for devil deals to cost coins instead of hearts"}, -- Keeper's Bargain
	[172] = {"172", "Cursed Penny", "Picking up a coin teleports Isaac to a random room#Can teleport to secret rooms"}, -- Cursed Penny
	[173] = {"173", "Your Soul", "{{DevilRoom}} Allows Isaac to take 1 Devil Room item for free#{{Warning}} The free Devil deal still affects Angel Room chance"}, -- Your Soul
	[174] = {"174", "Number Magnet", "{{DevilChance}} +10% Devil Room chance#Prevents Krampus from appearing in Devil Rooms#Devil Rooms are special variants with more deals, Black Hearts and enemies"}, -- Number Magnet
	[175] = {"175", "Strange Key", "Opens the door to the Hush floor regardless of the timer#Using {{Collectible297}} Pandora's Box consumes the key and spawns 6 items from random pools"}, -- Strange Key
	[176] = {"176", "Lil Clot", "Spawns a blood clot that mimics Isaac's movement#Copies Isaac's stats, tear effects and 35% of his damage#Respawns each room"}, -- Lil Clot
	[177] = {"177", "Temporary Tattoo", "{{Chest}} Clearing a {{ChallengeRoom}} Challenge Room spawns a chest#Clearing a {{BossRushRoom}} Boss Challenge Room spawns an item"}, -- Temporary Tattoo
	[178] = {"178", "Swallowed M80", "Taking damage has a 50% chance for Isaac to explode#Doesn't destroy Blood Donation Machines or Confessionals, while spawning pickups as if it did"}, -- Swallowed M80
	[179] = {"179", "RC Remote", "Familiars mimic Isaac's movement#Hold the drop button ({{ButtonRT}}) to keep the familiars in place"}, -- RC Remote
	[180] = {"180", "Found Soul", "Follows Isaac's movement and shoots spectral tears#Copies Isaac's stats, tear effects and 50% of his damage#Uses most active items when Isaac does#Dies in one hit#Respawns each floor"}, -- Found Soul
	[181] = {"181", "Expansion Pack", "Using an active item triggers the effect of an additional 1-2 charge active item"}, -- Expansion Pack
	[182] = {"182", "Beth's Essence", "Entering an {{AngelRoom}} Angel Room spawns 5 wisps#Donating to Beggars has a 25% chance to spawn a wisp"}, -- Beth's Essence
	[183] = {"183", "The Twins", "50% chance to duplicate a familiar each room#Grants {{Collectible8}} Brother Bobby or {{Collectible67}} Sister Maggy if Isaac has no familiars"}, -- The Twins
	[184] = {"184", "Adoption Papers", "{{Shop}} Shops sell familiars for 10 coins"}, -- Adoption Papers
	[185] = {"185", "Cricket Leg", "Killing an enemy has a 17% chance to spawn a random locust"}, -- Cricket Leg
	[186] = {"186", "Apollyon's Best Friend", "{{Collectible706}} Grants 1 Abyss locust"}, -- Apollyon's Best Friend
	[187] = {"187", "Broken Glasses", "{{TreasureRoom}} 50% chance of adding an extra blind item in Treasure Rooms#50% chance to reveal the blind item in alt path Treasure Rooms"}, -- Broken Glasses
	[188] = {"188", "Ice Cube", "Entering a room has a 20% chance to petrify random enemies#{{Freezing}} Killing a petrified enemy freezes it"}, -- Ice Cube
	[189] = {"189", "Sigil of Baphomet", "Killing an enemy makes Isaac invincible for 1 second#Invincibility stacks with successive enemy kills"}, -- Sigil of Baphomet
}

--these for repent+
local repPlusCollectibles = {
-- Change: added "Creep persists until you exit the room"
	[56] = {"56", "Lemon Mishap", "Spills a pool of creep#The creep deals 24 damage per second#Creep persists until you exit the room"}, -- Lemon Mishap
	-- Change: added "Persists between rooms if player is at 1/2 hearts"
	[117] = {"117", "Dead Bird", "Taking damage spawns a bird that attacks enemies#The bird deals 4.3 contact damage per second#Persists between rooms if player is at 1/2 hearts"}, -- Dead Bird
	-- Change: Complete rewrite
	[351] = {"351", "Mega Bean", "Deals 100 damage and petrifies all enemies in the room#{{Poison}} Deals 5 damage and poisons any enemies nearby#Can open secret rooms and break rocks"}, -- Mega Bean
	-- Change: Complete rewrite
	[436] = {"436", "Milk!", "Blocks enemy projectiles#{{Tears}} After 10 hits, it breaks and grants a Tears up for the remainder of the floor"}, -- Milk!
	-- Change: Complete rewrite
	[447] = {"447", "Linger Bean", "Firing without pause for 4 seconds spawns a poop cloud#The cloud increases its size over 10 seconds#The cloud deals less damage the bigger it gets#It can be moved by shooting it"}, -- Linger Bean
	-- Change: added " and fires radial bursts of tears"
	[470] = {"470", "Hushy", "Bounces around the room#Deals 30 contact damage per second#Stops moving when Isaac shoots#Blocks projectiles when stopped and fires radial bursts of tears"}, -- Hushy
	-- Change: added "Turns item pedestals into glitched items"
	[481] = {"481", "Dataminer", "↑ Random stat up#↓ Random stat down#{{Timer}} Random tear effects for the room#Turns item pedestals into glitched items#{{Blank}} Corrupts all sprites and music in the room"}, -- Dataminer
	-- Change: Complete rewrite
	[510] = {"510", "Delirious", "Spawns a friendly delirium version of a boss#Persists between rooms#{{Warning}} Only one boss can be active at a time#The item-charge is based on the quality of the previously spawned boss"}, -- Delirious
	-- Change: added "Tears leave a pool of creep on impact"
	[560] = {"560", "It Hurts", "{{Timer}} When taking damage, receive for the room:#↑ {{Tears}} +1.2 Fire rate on the first hit#↑ {{Tears}} +0.4 Fire rate for each additional hit#Releases a ring of 10 tears around Isaac#Tears leave a pool of creep on impact"}, -- It Hurts
	-- Change: Heals 2 hearts instead of 1/2
	[594] = {"594", "Jupiter", "↑ {{EmptyHeart}} +2 Empty heart containers#↓ {{Speed}} -0.3 Speed#{{HealingRed}} Heals 2 heart#{{Speed}} Speed builds up to +0.5 while standing still#{{Poison}} Moving releases poison clouds#{{Poison}} Poison immunity"}, -- Jupiter
	-- Change: Complete rewrite
	[632] = {"632", "Evil Charm", "↑ {{Luck}} +2 Luck#Immune to {{Burning}} fire damage, {{Confusion}} confusion, {{Fear}} fear, {{Slow}} spider-webs and {{Poison}} poison effects#Grants 1 second immunity to creep"}, -- Evil Charm
	-- Change: Complete rewrite
	[681] = {"681", "Lil Portal", "Double-tapping a fire button launches the portal#Deals contact damage when launched#Consumes pickups in its path#Each pickup consumed increases its size, damage, and spawns a blue fly#Consuming 2-3 pickups spawns a portal to a special room and the familiar disappears for the rest of the floor#The content of the room persists for the rest of the run"}, -- Lil Portal
	-- Change: Added info about the damage based on item quality
	[706] = {"706", "Abyss", "Consumes all item pedestals in the room and spawns a locust familiar for each one#Some items spawn a special locust when consumed#{{Damage}} Locusts deal Isaac's damage multiplied by the item quality consumed:#{{Quality0}} - 0.5x#{{Quality1}} - 0.75x#{{Quality2}} - 1.0x#{{Quality3}} - 1.5x#{{Quality4}} - 2.0x"}, -- Abyss
}
local repPlusTrinkets = {
-- Change: added ", {{Trinket135}} A Lighter"
	[53] = {"53", "Tick", "{{HealingRed}} Heals 1 heart when entering a {{BossRoom}} Boss Room#-15% boss health#{{Warning}} Once picked up, it can't be removed#Only removeable with {{Trinket41}} Match Stick, {{Trinket135}} A Lighter, or gulping"}, -- Tick
	-- Change: Changed "12-20 times" to "6-12 times"
	[97] = {"97", "Tonsil", "Taking damage 6-12 times spawns a projectile blocking familiar#Caps at 2 familiars"}, -- Tonsil
	-- Change: added "Bombs deal 15% more damage"
	[133] = {"133", "Short Fuse", "Isaac's bombs explode faster#Bombs deal 15% more damage"}, -- Short Fuse
	-- Change: "2%" to "5%"
	[104] = {"104", "Wish Bone", "5% chance to get destroyed and spawn a pedestal item when hit"}, -- Wish Bone
	-- Change: "2%" to "5%"
	[105] = {"105", "Bag Lunch", "{{Collectible22}} 5% chance to get destroyed and spawn Lunch when hit"}, -- Bag Lunch
}



--if you don't have any dlc, set to false (if youre on repent(not repent+) then set repentPlus to false, if on ab only, both to false
local repent  = true
local repentPlus = true

--update arrays with descriptions based on dlc contents
local function updateDescriptionsWithRepentanceContent()
    -- Update items
    if repCollectibles then
        for id, desc in pairs(repCollectibles) do
            descriptionsOfItems[id] = desc
        end
    end
    
    -- Update trinkets
    if repTrinkets then
        for id, desc in pairs(repTrinkets) do
            descriptionsOfTrinkets[id] = desc
        end
    end
    
    -- Update cards
    if repCards then
        for id, desc in pairs(repCards) do
            descriptionsOfCards[id] = desc
        end
    end
    
    -- Update pills
    if repPills then
        for id, desc in pairs(repPills) do
            descriptionsOfPills[id] = desc
        end
    end
end

-- Same function for Repentance+ content
local function updateDescriptionsWithRepentancePlusContent()
    if repPlusCollectibles then
        for id, desc in pairs(repPlusCollectibles) do
            descriptionsOfItems[id] = desc
        end
    end
    -- Repeat for trinkets
    if repPlusTrinkets then
        for id, desc in pairs(repPlusTrinkets) do
            descriptionsOfTrinkets[id] = desc
        end
    end
end

--this will be used when the game starts
local function initMod()
    if repent then
        updateDescriptionsWithRepentanceContent()
    end
    if repentPlus then
        updateDescriptionsWithRepentancePlusContent()
    end
end
initMod()

Isaac.AddCallback(nil, ModCallbacks.MC_POST_GAME_STARTED, initMod)

local DISPLAY_DISTANCE = 100 -- range to see item descs
local MAX_LINE_LENGTH = 20  -- Maximum characters per line
local DESCRIPTION_OFFSET_Y = -25  -- Starting Y offset for descriptions
-- Entity type constants
local ENTITY_TYPES = {
    PICKUP = 5,
    VARIANTS = {
        COLLECTIBLE = 100,
        TRINKET = 350,
        CARD = 300,
        PILL = 70
    }
}

-- Function to wrap text to prevent going off screen
local function wrapText(text, maxLength)
    local wrapped = {}
    local line = ""
    
    for word in text:gmatch("%S+") do
        if #line + #word + 1 <= maxLength then
            line = line .. (line ~= "" and " " or "") .. word
        else
            table.insert(wrapped, line)
            line = word
        end
    end
    
    if line ~= "" then
        table.insert(wrapped, line)
    end
    
    return table.concat(wrapped, "\n")
end

local function formatDescription(desc)
    local lines = {}
    for segment in desc:gmatch("[^#]+") do
        local wrapped = wrapText(segment, MAX_LINE_LENGTH)
        table.insert(lines, wrapped)
    end
    return table.concat(lines, "\n")
end

local function shouldShowDescriptions()
    local game = Game()
    return game:GetRoom():IsClear() -- Only show descriptions in cleared rooms
end

-- Cache game state values
local cachedEntities = {}
local lastUpdate = 0
local UPDATE_INTERVAL = 30 -- Update every 30 frames

-- A debug function to see messages in the console
local function debugLog(message)
    Isaac.ConsoleOutput("Debug: " .. message .. "\n")
end

--check whether pills are identified and items are not question marks before showing descriptions(without it it's cheaty)
local function isItemIdentified(variant, subType, player)
    local game = Game()
    if variant == ENTITY_TYPES.VARIANTS.PILL then
        return game:GetItemPool():IsPillIdentified(subType)
    elseif variant == ENTITY_TYPES.VARIANTS.COLLECTIBLE or variant == ENTITY_TYPES.VARIANTS.TRINKET then
        local level = game:GetLevel()
        return not (level:GetCurses() & LevelCurse.CURSE_OF_BLIND > 0)
    end
    return true
end

local function updateCache()
    local game = Game()
    debugLog("Updating cache")
    cachedEntities = {}
    local entities = Isaac.GetRoomEntities()
    for _, entity in ipairs(entities) do
        if entity.Type == ENTITY_TYPES.PICKUP then
            debugLog("Found pickup entity of variant: " .. entity.Variant)
            if entity.Variant == ENTITY_TYPES.VARIANTS.COLLECTIBLE or
               entity.Variant == ENTITY_TYPES.VARIANTS.TRINKET or
               entity.Variant == ENTITY_TYPES.VARIANTS.CARD or
               entity.Variant == ENTITY_TYPES.VARIANTS.PILL then
                table.insert(cachedEntities, {
                    Position = Vector(entity.Position.X, entity.Position.Y),
                    Variant = entity.Variant,
                    SubType = entity.SubType
                })
            end
        end
    end
end

--main func to show descriptions
function onRenderItemDesc()
    if not shouldShowDescriptions() then 
        debugLog("Descriptions disabled")
        return 
    end
    
    debugLog("Starting render")
    updateCache()
    local game = Game()
    local itemConfig = Isaac.GetItemConfig()
    
    for playerNum = 0, game:GetNumPlayers() - 1 do
        local player = Isaac.GetPlayer(playerNum)
        debugLog("Checking for player " .. playerNum)
        
        for _, entityData in ipairs(cachedEntities) do
            local distance = entityData.Position:Distance(player.Position)
            debugLog("Found entity at distance: " .. distance)
            
            if distance <= DISPLAY_DISTANCE then
                debugLog("Entity in range")
                if isItemIdentified(entityData.Variant, entityData.SubType, player) then
                    debugLog("Item is identified")
                    local configItem
                    local customDesc
                    
                    if entityData.Variant == ENTITY_TYPES.VARIANTS.COLLECTIBLE then
                        configItem = itemConfig:GetCollectible(entityData.SubType)
                        customDesc = descriptionsOfItems[entityData.SubType]
                        debugLog("Processing collectible")
                    elseif entityData.Variant == ENTITY_TYPES.VARIANTS.TRINKET then
                        configItem = itemConfig:GetTrinket(entityData.SubType)
                        customDesc = descriptionsOfTrinkets[entityData.SubType]
                        debugLog("Processing trinket")
                    elseif entityData.Variant == ENTITY_TYPES.VARIANTS.CARD then
                        configItem = itemConfig:GetCard(entityData.SubType)
                        customDesc = descriptionsOfCards[entityData.SubType]
                        debugLog("Processing card")
                    elseif entityData.Variant == ENTITY_TYPES.VARIANTS.PILL then
                        if game:GetItemPool():IsPillIdentified(entityData.SubType) then
                            configItem = itemConfig:GetPillEffect(entityData.SubType)
                            customDesc = descriptionsOfPills[entityData.SubType]
                            debugLog("Processing identified pill")
                        else
                            local screenPos = Isaac.WorldToScreen(entityData.Position)
                            Isaac.RenderText("???", screenPos.X - 15, screenPos.Y - 40, 1, 1, 1, 1)
                            debugLog("Processing unidentified pill")
                            goto continue
                        end
                    end
                    
                    if configItem then
                        debugLog("Rendering item description")
                        local screenPos = Isaac.WorldToScreen(entityData.Position)
                        
                        -- Draw name
                        local name = customDesc and customDesc[2] or configItem.Name
                        Isaac.RenderText(name, screenPos.X - 15, screenPos.Y - 40, 1, 1, 1, 1)
                        
                        -- Draw description
                        local descText = customDesc and formatDescription(customDesc[3]) or wrapText(configItem.Description, MAX_LINE_LENGTH)
                        
                        local yOffset = DESCRIPTION_OFFSET_Y
                        for line in (descText .. "\n"):gmatch("(.-)\n") do
                            Isaac.RenderText(line, screenPos.X - 15, screenPos.Y + yOffset, 1, 1, 1, 1)
                            yOffset = yOffset + 10
                        end
                    end
                    ::continue::
                end
            end
        end
    end
end

Isaac.AddCallback(nil, ModCallbacks.MC_POST_RENDER, onRenderItemDesc)