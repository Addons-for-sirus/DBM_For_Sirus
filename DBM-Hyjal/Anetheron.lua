local mod = DBM:NewMod("Anetheron", "DBM-Hyjal")
local L   = mod:GetLocalizedStrings()

mod:SetRevision("20220518110528")
mod:SetCreatureID(17808)

mod:RegisterCombat("combat")

mod:RegisterEventsInCombat(
	"SPELL_CAST_START 317870 317872 317873 317884",
	--"SPELL_CAST_SUCCESS",
	"SPELL_AURA_APPLIED 317876 317872 317873",
	"SPELL_AURA_REFRESH 317876 317872",
	--"SPELL_AURA_REMOVED",
	"SPELL_SUMMON 317870",
	"UNIT_HEALTH"
)

local warnInferno            = mod:NewTargetNoFilterAnnounce(317870, 4)
local warnFingerofDeath      = mod:NewTargetNoFilterAnnounce(317876, 4)
local warnManaAbsorptionCast = mod:NewCastAnnounce(317884, 5, 1.5)
local warnWaveHorrorSoon     = mod:NewSoonAnnounce(317873, 3)

local specWarnTimerMoved     = mod:NewSpecialWarning("|cff71d5ff|Hspell:317873|hФир|h|r СМЕСТИЛСЯ НА 3 СЕК!")
local warnwarnInfernoSoon    = mod:NewSpecialWarningSoon(317870, "Melee", nil, nil, 4, 2)
local specWarnInfernoDeff    = mod:NewSpecialWarningDefensive(317870, "Tank", nil, nil, 1, 2)
local specWarnInferno        = mod:NewSpecialWarningMoveAway(317870, nil, nil, nil, 4, 2)
local specWarnCrimsonBarrier = mod:NewSpecialWarningDispel(317872, "MagicDispeller", nil, nil, 1, 2)
local specWarnManaAbsorption = mod:NewSpecialWarningInterrupt(317884, "HasInterrupt", nil, nil, 1, 2)
local yellFear               = mod:NewYell(317884, "Фирнуло: " .. UnitName("player"))

local timerCrimsonBarrierNext = mod:NewNextTimer(30, 317872, nil, nil, nil, 4)
local timerManaAbsorptionNext = mod:NewNextTimer(20, 317884, nil, nil, nil, 4)
local timerWaveHorror         = mod:NewCDTimer(20, 317873, nil, nil, nil, 5, nil, nil, nil, 1)
local timerFingerofDeathCD    = mod:NewCDTimer(7, 317876, nil, nil, nil, 4)
local timerInfernoCast        = mod:NewCastTimer(3, 317870, nil, nil, nil, 3)
local berserkTimer            = mod:NewBerserkTimer(600)

local warned_Inferno = false

mod:AddBoolOption("AnnounceFails", false, "announce")
local FearTargets = {}

function mod:InfernoTarget(targetname)
	if not targetname then return end
	warnInferno:Show(targetname)
	if targetname == UnitName("player") then
		specWarnInfernoDeff:Show()
	elseif self:CheckNearby(20, targetname) then
		specWarnInferno:Show()
	end
end

function mod:OnCombatStart(delay)
	DBM:FireCustomEvent("DBM_EncounterStart", 17808, "Anetheron")
	self:SetStage(1)
	timerWaveHorror:Start()
	timerCrimsonBarrierNext:Start(60)
	berserkTimer:Start()
	warned_Inferno = false
	table.wipe(FearTargets)
end

local FearFails = {}
local function FearFails1(e1, e2)
	return (FearTargets[e1] or 0) > (FearTargets[e2] or 0)
end

function mod:OnCombatEnd(wipe)
	DBM:FireCustomEvent("DBM_EncounterEnd", 17808, "Anetheron", wipe)
	if self.Options.AnnounceFails and DBM:GetRaidRank() >= 1 and self:AntiSpam(5) then
		local lFear = ""
		for k, _ in pairs(FearTargets) do
			table.insert(FearFails, k)
		end
		table.sort(FearFails, FearFails1)
		for _, v in ipairs(FearFails) do
			lFear = lFear .. " " .. v .. "(" .. (FearTargets[v] or "") .. ")"
		end
		SendChatMessage(L.Fear:format(lFear), "RAID")
		table.wipe(FearFails)
	end
end

function mod:SPELL_CAST_START(args)
	if args:IsSpellID(317870) then
		if timerWaveHorror:GetRemaining() < 2 then
			specWarnTimerMoved:Show()
			timerWaveHorror:Start(3)
		end
		timerInfernoCast:Start()
		self:BossTargetScanner(17808, "InfernoTarget", 0.05, 10)
		warned_Inferno = false
	elseif args:IsSpellID(317872) then
		specWarnCrimsonBarrier:Show()
		timerCrimsonBarrierNext:Start()
	elseif args:IsSpellID(317873) then
		warnWaveHorrorSoon:Schedule(17)
		timerWaveHorror:Start()
	elseif args:IsSpellID(317884) then
		warnManaAbsorptionCast:Show()
		specWarnManaAbsorption:Show()
		timerManaAbsorptionNext:Start()
	end
end

--[[
function mod:SPELL_CAST_SUCCESS(args)
end]]

function mod:SPELL_AURA_APPLIED(args)
	if args:IsSpellID(317876) then
		warnFingerofDeath:Show(args.destName)
		timerFingerofDeathCD:Start()
	elseif args:IsSpellID(317872) then
		specWarnCrimsonBarrier:Show()
	elseif args:IsSpellID(317873) and DBM:GetRaidUnitId(args.destName) ~= "none" and args.destName then
		FearTargets[args.destName] = (FearTargets[args.destName] or 0) + 1
		if self.Options.AnnounceFails then
			if args:IsPlayer() then
				yellFear:Yell()
			end
			SendChatMessage(L.FearOn:format(args.destName), "RAID")
		end
	end
end

mod.SPELL_AURA_REFRESH = mod.SPELL_AURA_APPLIED
--[[
function mod:SPELL_AURA_REMOVED(args)
end]]

function mod:SPELL_SUMMON(args)
	if args:IsSpellID(317870) then
		timerManaAbsorptionNext:Start()
	end
end

function mod:UNIT_HEALTH(uId)
	--local hp = self:GetUnitCreatureId(uId) == 17808
	if self:GetUnitCreatureId(uId) == 17808 and not warned_Inferno and ((DBM:GetBossHPByUnitID(uId) % 10) == 1) then
		warned_Inferno = true
		warnwarnInfernoSoon:Show()
	end
end
