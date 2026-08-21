-- BloodShieldOverlay: always skip cinematics, movies, and talking heads.
--
-- Inspired by the event-driven approach used by Deadly Boss Mods:
--   * CINEMATIC_START       -> CinematicFrame_CancelCinematic()
--   * PLAY_MOVIE            -> MovieFrame:Hide()
--   * TALKINGHEAD_REQUESTED -> TalkingHeadFrame:Hide()
--
-- This module intentionally has no location, instance, difficulty, or
-- "seen once" filter. The preference is to skip every cinematic/movie/
-- talking head everywhere.

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

local function skipTalkingHead()
	if TalkingHeadFrame then
		TalkingHeadFrame:Hide()
	end
end

frame:RegisterEvent("CINEMATIC_START")
frame:RegisterEvent("PLAY_MOVIE")
frame:RegisterEvent("TALKINGHEAD_REQUESTED")

frame:SetScript("OnEvent", function(_, event)
	if event == "CINEMATIC_START" then
		skipCinematic()
	elseif event == "PLAY_MOVIE" then
		skipMovie()
	elseif event == "TALKINGHEAD_REQUESTED" then
		skipTalkingHead()
	end
end)
