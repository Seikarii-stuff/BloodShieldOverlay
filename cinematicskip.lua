-- BloodShieldOverlay: always skip cinematics and movies.
--
-- Inspired by the event-driven approach used by Deadly Boss Mods:
--   * CINEMATIC_START -> CinematicFrame_CancelCinematic()
--   * PLAY_MOVIE      -> MovieFrame:Hide()
--
-- This module intentionally has no location, instance, difficulty, or
-- "seen once" filter. The preference is to skip every cinematic everywhere.

local frame = CreateFrame("Frame", "BloodShieldOverlayCinematicSkip")

local function skipCinematic()
	if CinematicFrame_CancelCinematic then
		CinematicFrame_CancelCinematic()
	end
end

local function skipMovie()
	if MovieFrame then
		MovieFrame:Hide()
	end
end

frame:RegisterEvent("CINEMATIC_START")
frame:RegisterEvent("PLAY_MOVIE")

frame:SetScript("OnEvent", function(_, event)
	if event == "CINEMATIC_START" then
		skipCinematic()
	elseif event == "PLAY_MOVIE" then
		skipMovie()
	end
end)
