-- MAX DarkRP custom scoreboard (Icefuse-style, job-colored rows)

local ROW_HEIGHT = 34
local HEADER_HEIGHT = 70
local WIDTH = 620

local COLOR_BG = Color(18, 22, 28, 245)
local COLOR_HEADER = Color(10, 13, 18, 255)
local COLOR_TEXT = Color(255, 255, 255, 255)
local COLOR_MONEY_UP = Color(90, 220, 110)
local COLOR_MONEY_DOWN = Color(230, 80, 80)
local FALLBACK_JOB_COLOR = Color(90, 90, 90)

local FONT_NAME = "MaxScoreboard_Name"
local FONT_JOB = "MaxScoreboard_Job"
local FONT_MONEY = "MaxScoreboard_Money"
local FONT_TITLE = "MaxScoreboard_Title"

surface.CreateFont(FONT_NAME, { font = "Roboto", size = 16, weight = 600 })
surface.CreateFont(FONT_JOB, { font = "Roboto", size = 14, weight = 500 })
surface.CreateFont(FONT_MONEY, { font = "Roboto", size = 15, weight = 700 })
surface.CreateFont(FONT_TITLE, { font = "Roboto", size = 26, weight = 800 })

local flagCache = {}
local function GetFlagMaterial(code)
	code = code or "unknown"
	if not flagCache[code] then
		local path = "max_scoreboard/flags/" .. code .. ".png"
		local mat = Material(path, "noclamp smooth")
		if mat:IsError() then
			mat = Material("max_scoreboard/flags/unknown.png", "noclamp smooth")
		end
		flagCache[code] = mat
	end
	return flagCache[code]
end

local groupCache = {}
local function GetGroupMaterial(group)
	group = group or "user"
	if not groupCache[group] then
		local path = "max_scoreboard/groups/" .. group .. ".png"
		local mat = Material(path, "noclamp smooth")
		if mat:IsError() then
			mat = Material("max_scoreboard/groups/user.png", "noclamp smooth")
		end
		groupCache[group] = mat
	end
	return groupCache[group]
end

local osCache = {}
local function GetOSMaterial(os)
	os = os or "windows"
	if not osCache[os] then
		osCache[os] = Material("max_scoreboard/os/" .. os .. ".png", "noclamp smooth")
	end
	return osCache[os]
end

local moneyHistory = {} -- [steamid64] = { last = number, trend = 1/0/-1, trendTime = CurTime() }
local playerCountry = {} -- [steamid64] = "us"
local playerOS = {} -- [steamid64] = "windows" / "linux" / "osx"

net.Receive("MaxScoreboard_CountryCode", function()
	local steamid = net.ReadString()
	local code = net.ReadString()
	playerCountry[steamid] = code
end)

net.Receive("MaxScoreboard_ClientOS", function()
	local steamid = net.ReadString()
	local os = net.ReadString()
	playerOS[steamid] = os
end)

hook.Add("InitPostEntity", "MaxScoreboard_SendOS", function()
	local os = "windows"
	if system.IsLinux() then
		os = "linux"
	elseif system.IsOSX() then
		os = "osx"
	end

	net.Start("MaxScoreboard_ClientOS")
		net.WriteString(os)
	net.SendToServer()
end)

local function GetJobColor(ply)
	if not IsValid(ply) then return FALLBACK_JOB_COLOR end
	local team = ply:Team()
	if team_colors and team_colors[team] then
		return team_colors[team]
	end
	local col = team.GetColor and team.GetColor(team)
	return col or FALLBACK_JOB_COLOR
end

local function GetJobName(ply)
	if not IsValid(ply) then return "" end
	return team.GetName(ply:Team()) or "Unknown"
end

local function UpdateMoneyTrend(ply)
	if not IsValid(ply) or not ply.getDarkRPVar then return end
	local sid = ply:SteamID64()
	local money = ply:getDarkRPVar("money") or 0
	local hist = moneyHistory[sid]
	if not hist then
		moneyHistory[sid] = { last = money, trend = 0, trendTime = 0 }
		return
	end
	if money > hist.last then
		hist.trend = 1
		hist.trendTime = CurTime()
	elseif money < hist.last then
		hist.trend = -1
		hist.trendTime = CurTime()
	end
	hist.last = money
end

local PANEL = {}

local PIN_HEIGHT = 26

function PANEL:Init()
	self:SetSize(WIDTH, ScrH() - 120)
	self:Center()
	self:SetVisible(false)
	self:SetKeyboardInputEnabled(false)
	self:SetMouseInputEnabled(true)
	self.rows = {}
	self.nextRefresh = 0
	self.pinned = false

	self.PinButton = vgui.Create("DButton", self)
	self.PinButton:SetText("")
	self.PinButton:SetSize(120, PIN_HEIGHT - 4)
	self.PinButton.Paint = function(btn, w, h)
		local bg = self.pinned and Color(90, 180, 90) or Color(60, 64, 70)
		draw.RoundedBox(4, 0, 0, w, h, bg)
		local label = self.pinned and "📌 PINNED" or "📌 PIN SCOREBOARD"
		draw.SimpleText(label, FONT_JOB, w / 2, h / 2, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)
	end
	self.PinButton.DoClick = function()
		self.pinned = not self.pinned
		if not self.pinned and not input.IsKeyDown(KEY_TAB) then
			self:SetVisible(false)
		end
	end
end

function PANEL:PerformLayout(w, h)
	if IsValid(self.PinButton) then
		self.PinButton:SetPos(w / 2 - 60, h - PIN_HEIGHT)
	end
end

function PANEL:Think()
	if CurTime() >= self.nextRefresh then
		self:Populate()
		self.nextRefresh = CurTime() + 1
	end
end

function PANEL:Populate()
	local plys = player.GetAll()

	for _, ply in ipairs(plys) do
		UpdateMoneyTrend(ply)
	end

	table.sort(plys, function(a, b)
		local ja, jb = GetJobName(a), GetJobName(b)
		if ja == jb then
			return a:Nick() < b:Nick()
		end
		return ja < jb
	end)

	self.sortedPlayers = plys

	local totalHeight = HEADER_HEIGHT + (#plys * ROW_HEIGHT) + PIN_HEIGHT + 10
	self:SetTall(math.min(totalHeight, ScrH() - 80))
	self:Center()
	self:InvalidateLayout()
end

function PANEL:Paint(w, h)
	draw.RoundedBox(6, 0, 0, w, h, COLOR_BG)

	draw.RoundedBoxEx(6, 0, 0, w, HEADER_HEIGHT, COLOR_HEADER, true, true, false, false)
	draw.SimpleText("MAX DARKRP", FONT_TITLE, w / 2, 22, COLOR_TEXT, TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	local plyCount = #(self.sortedPlayers or {})
	draw.SimpleText(plyCount .. " players online", FONT_JOB, w / 2, 50, Color(180, 180, 180), TEXT_ALIGN_CENTER, TEXT_ALIGN_CENTER)

	if not self.sortedPlayers then return end

	local y = HEADER_HEIGHT + 4
	for _, ply in ipairs(self.sortedPlayers) do
		if not IsValid(ply) then continue end
		self:PaintRow(ply, y, w)
		y = y + ROW_HEIGHT
	end
end

function PANEL:PaintRow(ply, y, w)
	local jobColor = GetJobColor(ply)
	surface.SetDrawColor(jobColor.r, jobColor.g, jobColor.b, 235)
	surface.DrawRect(6, y, w - 12, ROW_HEIGHT - 2)

	surface.SetDrawColor(0, 0, 0, 60)
	surface.DrawOutlinedRect(6, y, w - 12, ROW_HEIGHT - 2, 1)

	local x = 14
	local midY = y + (ROW_HEIGHT - 2) / 2

	-- avatar
	if not ply.MaxAvatar then
		ply.MaxAvatar = vgui.Create("AvatarImage", self)
		ply.MaxAvatar:SetPlayer(ply, 64)
	end
	if IsValid(ply.MaxAvatar) then
		ply.MaxAvatar:SetPos(x, y + 2)
		ply.MaxAvatar:SetSize(ROW_HEIGHT - 6, ROW_HEIGHT - 6)
	end
	x = x + ROW_HEIGHT - 6 + 6

	-- SAM/CAMI usergroup icon
	local group = ply:GetUserGroup()
	if group and group ~= "user" then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(GetGroupMaterial(group))
		surface.DrawTexturedRect(x, midY - 9, 18, 18)
		x = x + 24
	end

	-- flag
	local sid = ply:SteamID64()
	local code = playerCountry[sid]
	if code then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(GetFlagMaterial(code))
		surface.DrawTexturedRect(x, midY - 8, 20, 14)
		x = x + 26
	end

	-- OS icon
	local os = playerOS[sid]
	if os then
		surface.SetDrawColor(255, 255, 255, 255)
		surface.SetMaterial(GetOSMaterial(os))
		surface.DrawTexturedRect(x, midY - 8, 16, 16)
		x = x + 22
	end

	-- mic icon
	if ply:IsSpeaking() then
		draw.SimpleText("🔊", FONT_JOB, x, midY, Color(255, 255, 255), TEXT_ALIGN_LEFT, TEXT_ALIGN_CENTER)
	end
	x = x + 20

	-- name
	draw.SimpleText(ply:Nick(), FONT_NAME, x, midY - 8, COLOR_TEXT, TEXT_ALIGN_LEFT, TEXT_ALIGN_TOP)

	-- job title under name (small)
	draw.SimpleText(GetJobName(ply), FONT_JOB, x, midY + 8, Color(20, 20, 20, 210), TEXT_ALIGN_LEFT, TEXT_ALIGN_BOTTOM)

	-- money + trend, right aligned
	local money = ply.getDarkRPVar and (ply:getDarkRPVar("money") or 0) or 0
	local moneyText = "$" .. string.Comma(math.Round(money))

	local hist = moneyHistory[sid]
	local arrow, arrowColor = "", nil
	if hist and hist.trend ~= 0 and CurTime() - hist.trendTime < 6 then
		if hist.trend == 1 then
			arrow, arrowColor = "▲", COLOR_MONEY_UP
		else
			arrow, arrowColor = "▼", COLOR_MONEY_DOWN
		end
	end

	local rightX = w - 16
	draw.SimpleText(moneyText, FONT_MONEY, rightX, midY, COLOR_TEXT, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)

	if arrowColor then
		local moneyW = surface.GetTextSize and 0 or 0
		surface.SetFont(FONT_MONEY)
		local tw = surface.GetTextSize(moneyText)
		draw.SimpleText(arrow, FONT_MONEY, rightX - tw - 6, midY, arrowColor, TEXT_ALIGN_RIGHT, TEXT_ALIGN_CENTER)
	end
end

function PANEL:OnRemove()
	for _, ply in ipairs(player.GetAll()) do
		if IsValid(ply.MaxAvatar) then
			ply.MaxAvatar:Remove()
			ply.MaxAvatar = nil
		end
	end
end

vgui.Register("MaxScoreboard", PANEL, "Panel")

local scoreboard

function GM:ScoreboardShow()
	if not IsValid(scoreboard) then
		scoreboard = vgui.Create("MaxScoreboard")
	end
	scoreboard:Populate()
	scoreboard:SetVisible(true)
	scoreboard:MakePopup()
	scoreboard:SetKeyboardInputEnabled(false)
	return true
end

function GM:ScoreboardHide()
	if IsValid(scoreboard) and not scoreboard.pinned then
		scoreboard:SetVisible(false)
	end
	return true
end
