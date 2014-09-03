local choice_wheel = setmetatable({disable_wrapping = false}, sick_wheel_mt)
local choices = { THEME:GetString("OptionTitles", "Yes"), THEME:GetString("OptionTitles", "No") }
local timeout = THEME:GetMetric("ScreenPlayAgain","TimerSeconds")
local TimeSinceStart

-- this handles user input
local function input(event)
	if not event.PlayerNumber or not event.button then
		return false
	end

	if event.type == "InputEventType_FirstPress" then
		local topscreen = SCREENMAN:GetTopScreen()
		local underlay = topscreen:GetChild("Underlay")

		if event.GameButton == "MenuRight" then
			choice_wheel:scroll_by_amount(1)
			underlay:GetChild("change_sound"):play()

		elseif event.GameButton == "MenuLeft" then
			choice_wheel:scroll_by_amount(-1)
			underlay:GetChild("change_sound"):play()

		elseif event.GameButton == "Start" then
			if not GAMESTATE:IsPlayerEnabled(event.PlayerNumber) then
				if not GAMESTATE:JoinInput(event.PlayerNumber) then
					return false
				end
			end

			underlay:GetChild("start_sound"):play()
			local choice = choice_wheel:get_actor_item_at_focus_pos().choice
			if choice == "Yes" then

				local Players =  GAMESTATE:GetHumanPlayers()

				for pn in ivalues(Players) do
					for i=1, PREFSMAN:GetPreference("SongsPerPlay") do
						GAMESTATE:AddStageToPlayer(pn)
					end
				end

				local coins = PREFSMAN:GetPreference("CoinsPerCredit")
				local premium = PREFSMAN:GetPreference("Premium")

				if premium == "Premium_DoubleFor1Credit" then
					if SL.Global.Gamestate.Style == "versus" then
						coins = coins * 2
					end

				elseif premium == "Premium_Off" then
					if SL.Global.Gamestate.Style == "versus" or SL.Global.Gamestate.Style == "double" then
						coins = coins * 2
					end
				end

				GAMESTATE:InsertCoin(-coins)

				SL.Global.Stages.Remaining = PREFSMAN:GetPreference("SongsPerPlay")
				SL.Global.ContinuesRemaining = SL.Global.ContinuesRemaining - 1


				SL.Global.ScreenAfter.PlayAgain = "ScreenSelectMusic"
			else
				SL.Global.ScreenAfter.PlayAgain = "ScreenEvaluationSummary"
			end

			topscreen:RemoveInputCallback(input)
			topscreen:StartTransitioningScreen("SM_GoToNextScreen")

		elseif event.GameButton == "Back" then
			topscreen:RemoveInputCallback(input)
			topscreen:Cancel()
		end
	end

	return false
end

-- the metatable for an item in the sort_wheel
local wheel_item_mt = {
	__index = {
		create_actors = function(self, name)
			self.name=name
			local index = tonumber((name:gsub("item","")))
			self.index = index
			local choice = choices[index]
			self.choice = choice

			local af = Def.ActorFrame{
				Name=name,

				InitCommand=function(subself)
					self.container = subself
					if choice == "No" then
						self.container:zoom(0.75)
					end
				end
			}

			af[#af+1] = LoadFont("_wendy small")..{
				Text=choices[index],
				OnCommand=function(self)
					local scaled = scale(index,1,2,-1,1)
					self:x(scaled * 100)
				end
			}

			return af
		end,

		transform = function(self, item_index, num_items, has_focus)
			self.container:finishtweening()

			if has_focus then
				self.container:accelerate(0.15)
				self.container:zoom(1)
				self.container:diffuse( GetCurrentColor() )
				self.container:glow(color("1,1,1,0.5"))
			else
				self.container:glow(color("1,1,1,0"))
				self.container:accelerate(0.15)
				self.container:zoom(0.75)
				self.container:diffuse(color("#888888"))
				self.container:glow(color("1,1,1,0"))
			end

		end,

		set = function(self, info)
			self.info= info
			if not info then return end
		end
	}
}

local t = Def.ActorFrame{
	InitCommand=function(self)
		--reset this now, otherwise it might still be set to SSM from a previous continue
		--and we don't want that if a timeout occurs
		SL.Global.ScreenAfter.PlayAgain = "ScreenEvaluationSummary"

		choice_wheel:set_info_set({""}, 2)
		self:queuecommand("Capture")
	end,
	CaptureCommand=function(self)
		SCREENMAN:GetTopScreen():AddInputCallback(input)
	end,

	-- I'm not sure why the built-in MenuTimer doesn't force a transition to the nextscreen
	-- when it runs out of time, but... it isn't.  So recursively listen for time remaining here
	-- and force a screen transition when time runs out.
	OnCommand=function(self)
		if PREFSMAN:GetPreference("MenuTimer") then
			self:queuecommand("Listen")
		end
	end,
	ListenCommand=function(self)
		local topscreen = SCREENMAN:GetTopScreen()
		local seconds = topscreen:GetChild("Timer"):GetSeconds()
		if seconds <= 0 then
			topscreen:StartTransitioningScreen("SM_GoToNextScreen")
		else
			self:sleep(0.5)
			self:queuecommand("Listen")
		end
	end,

	-- slightly darken the entire screen
	Def.Quad {
		InitCommand=cmd(FullScreen; diffuse,Color.Black; diffusealpha,0.6)
	},

	LoadFont("_wendy small")..{
		Text=THEME:GetString("ScreenPlayAgain", "Continue"),
		InitCommand=cmd(xy, _screen.cx, _screen.cy-30),
	},

	choice_wheel:create_actors( "sort_wheel", #choices, wheel_item_mt, _screen.cx, _screen.cy+50 ),

}

t[#t+1] = LoadActor( THEME:GetPathS("ScreenSelectMaster", "change") )..{ Name="change_sound", SupportPan = false }
t[#t+1] = LoadActor( THEME:GetPathS("common", "start") )..{ Name="start_sound", SupportPan = false }

return t