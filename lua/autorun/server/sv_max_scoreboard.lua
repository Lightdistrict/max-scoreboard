-- Server-side GeoIP lookup for the MAX DarkRP scoreboard flags

util.AddNetworkString("MaxScoreboard_CountryCode")
util.AddNetworkString("MaxScoreboard_ClientOS")

local knownOS = {} -- [steamid64] = "windows"/"linux"/"osx"

net.Receive("MaxScoreboard_ClientOS", function(len, ply)
	if not IsValid(ply) then return end
	local os = net.ReadString()
	knownOS[ply:SteamID64()] = os

	net.Start("MaxScoreboard_ClientOS")
		net.WriteString(ply:SteamID64())
		net.WriteString(os)
	net.Broadcast()
end)

hook.Add("PlayerInitialSpawn", "MaxScoreboard_ResendOS", function(newPly)
	timer.Simple(3, function()
		if not IsValid(newPly) then return end
		for sid, os in pairs(knownOS) do
			net.Start("MaxScoreboard_ClientOS")
				net.WriteString(sid)
				net.WriteString(os)
			net.Send(newPly)
		end
	end)
end)

local function LookupCountry(ply)
	if not IsValid(ply) then return end
	local ip = string.Explode(":", ply:IPAddress())[1]

	-- Skip lookups for local/LAN testing IPs
	if ip == "127.0.0.1" or ip:find("^192%.168%.") or ip:find("^10%.") then
		net.Start("MaxScoreboard_CountryCode")
			net.WriteString(ply:SteamID64())
			net.WriteString("unknown")
		net.Broadcast()
		return
	end

	http.Fetch("http://ip-api.com/json/" .. ip .. "?fields=countryCode",
		function(body)
			if not IsValid(ply) then return end
			local ok, data = pcall(util.JSONToTable, body)
			local code = (ok and data and data.countryCode) and string.lower(data.countryCode) or "unknown"

			net.Start("MaxScoreboard_CountryCode")
				net.WriteString(ply:SteamID64())
				net.WriteString(code)
			net.Broadcast()
		end,
		function(err)
			net.Start("MaxScoreboard_CountryCode")
				net.WriteString(ply:SteamID64())
				net.WriteString("unknown")
			net.Broadcast()
		end
	)
end

hook.Add("PlayerInitialSpawn", "MaxScoreboard_GeoIP", function(ply)
	timer.Simple(2, function()
		LookupCountry(ply)
	end)
end)

-- Resend all known country codes to a player who just loaded, for players already connected
hook.Add("PlayerInitialSpawn", "MaxScoreboard_ResendExisting", function(newPly)
	timer.Simple(3, function()
		if not IsValid(newPly) then return end
		for _, ply in ipairs(player.GetAll()) do
			if ply ~= newPly then
				LookupCountry(ply)
			end
		end
	end)
end)
