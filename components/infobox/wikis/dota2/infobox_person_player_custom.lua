---
-- @Liquipedia
-- wiki=dota2
-- page=Module:Infobox/Person/Player/Custom
--
-- Please see https://github.com/Liquipedia/Lua-Modules to contribute
--

local Player = require('Module:Infobox/Person')
local String = require('Module:StringUtils')
local Class = require('Module:Class')
local Namespace = require('Module:Namespace')
local Variables = require('Module:Variables')
local Page = require('Module:Page')
local YearsActive = require('Module:YearsActive')
local Matches = require('Module:Matches_Player')
local Flags = require('Module:Flags')
local Localisation = require('Module:Localisation')

local Injector = require('Module:Infobox/Widget/Injector')
local Cell = require('Module:Infobox/Widget/Cell')
local Title = require('Module:Infobox/Widget/Title')
local Center = require('Module:Infobox/Widget/Center')

local _BANNED = mw.loadData('Module:Banned')
local _ROLES = {
	['analyst'] = {category = 'Analysts', variable = 'Analyst'},
	['carry'] = {category = 'Carry players', variable = 'Carry'},
	['mid'] = {category = 'Solo middle players', variable = 'Solo Middle'},
	['solo middle'] = {category = 'Solo middle players', variable = 'Solo Middle'},
	['solomiddle'] = {category = 'Solo middle players', variable = 'Solo Middle'},
	['offlane'] = {category = 'Offlaners', variable = 'Offlaner'},
	['offlaner'] = {category = 'Offlaners', variable = 'Offlaner'},
	['observer'] = {category = 'Observers', variable = 'Observer'},
	['host'] = {category = 'Hosts', variable = 'Host'},
	['captain'] = {category = 'Captains', variable = 'Captain'},
	['journalist'] = {category = 'Journalists', variable = 'Journalist'},
	['support'] = {category = 'Support players', variable = 'Support'},
	['expert'] = {category = 'Experts', variable = 'Expert'},
	['coach'] = {category = 'Coaches', variable = 'Coach'},
	['caster'] = {category = 'Casters', variable = 'Caster'},
	['manager'] = {category = 'Managers', variable = 'Manager'},
	['streamer'] = {category = 'Streamers', variable = 'Streamer'}
}

local _title = mw.title.getCurrentTitle()
local _base_page_name = _title.baseText

local CustomPlayer = Class.new()

local CustomInjector = Class.new(Injector)

local _args

function CustomPlayer.run(frame)
	local player = Player(frame)
	_args = player.args
	player.args.informationType = player.args.informationType or 'Player'

	player.adjustLPDB = CustomPlayer.adjustLPDB
	player.createBottomContent = CustomPlayer.createBottomContent
	player.getCategories = CustomPlayer.getCategories
	player.createWidgetInjector = CustomPlayer.createWidgetInjector

	return player:createInfobox(frame)
end

function CustomInjector:parse(id, widgets)
	if id == 'status' then
		local statusContents = CustomPlayer._getStatusContents()

		local yearsActive = _args.years_active
		if String.isEmpty(yearsActive) then
			yearsActive = YearsActive.get({player = _base_page_name})
		else
			yearsActive = Page.makeInternalLink({onlyIfExists = true}, yearsActive)
		end

		local yearsActiveOrg = _args.years_active_manage
		if not String.isEmpty(yearsActiveOrg) then
			yearsActiveOrg = Page.makeInternalLink({onlyIfExists = true}, yearsActiveOrg)
		end

		return {
			Cell{name = 'Status', content = statusContents},
			Cell{name = 'Years Active (Player)', content = {yearsActive}},
			Cell{name = 'Years Active (Org)', content = {yearsActiveOrg}},
			Cell{name = 'Years Active (Coach)', content = {_args.years_active_coach}},
			Cell{name = 'Years Active (Analyst)', content = {_args.years_active_analyst}},
			Cell{name = 'Years Active (Talent)', content = {_args.years_active_talent}},
		}
	elseif id == 'history' then
		if not String.isEmpty(_args.history_iwo) then
			table.insert(widgets, Title{name = '[[Intel World Open|Intel World Open]] History'})
			table.insert(widgets, Center{content = {_args.history_iwo}})
		end
		if not String.isEmpty(_args.history_gfinity) then
			table.insert(widgets, Title{name = '[[Gfinity/Elite_Series|Gfinity Elite Series]] History'})
			table.insert(widgets, Center{content = {_args.history_gfinity}})
		end
		if not String.isEmpty(_args.history_odl) then
			table.insert(widgets, Title{name = '[[Oceania Draft League|Oceania Draft League]] History'})
			table.insert(widgets, Center{content = {_args.history_odl}})
		end
	elseif id == 'role' then
		return {
			Cell{name = 'Current Role', content = {
					CustomPlayer._createRole('role', _args.role),
					CustomPlayer._createRole('role2', _args.role2)
				}},
		}
	elseif id == 'nationality' then
		return {
			Cell{name = 'Location', content = {_args.location}},
			Cell{name = 'Nationality', content = CustomPlayer._createLocations()}
		}
	end
	return widgets
end

function CustomInjector:addCustomCells(widgets)
	-- TODO add hero
	return {}
end

function CustomPlayer:createWidgetInjector()
	return CustomInjector()
end

function CustomPlayer:makeAbbr(title, text)
	if String.isEmpty(title) or String.isEmpty(text) then
		return nil
	end
	return '<abbr title="' .. title .. '>' .. text .. '</abbr>'
end

function CustomPlayer:adjustLPDB(lpdbData)
	lpdbData.status = lpdbData.status or 'Unknown'

	lpdbData.extradata.role = _args.role
	lpdbData.extradata.role2 = _args.role2
	lpdbData.extradata.hero = _args.hero
	lpdbData.extradata.hero2 = _args.hero2
	lpdbData.extradata.hero3 = _args.hero3
	lpdbData.extradata['lc_id'] = _base_page_name:lower()
	lpdbData.extradata.team2 = mw.ext.TeamLiquidIntegration.resolve_redirect(
		not String.isEmpty(_args.team2link) and _args.team2link or _args.team2)

	return lpdbData
end

function CustomPlayer:createBottomContent(infobox)
	if Namespace.isMain() then
		return tostring(Matches.get({args = {noClass = true}}))
	end
end

function CustomPlayer._getStatusContents()
	local statusContents = {}
	local status
	if not String.isEmpty(_args.status) then
		status = Page.makeInternalLink({onlyIfExists = true}, _args.status) or _args.status
	end
	table.insert(statusContents, status)

	local banned = _BANNED[string.lower(_args.banned or '')]
	if not banned and not String.isEmpty(_args.banned) then
		banned = '[[Banned Players|Multiple Bans]]'
		table.insert(statusContents, banned)
	end

	local index = 2
	banned = _BANNED[string.lower(_args['banned' .. index] or '')]
	while banned do
		table.insert(statusContents, banned)
		index = index + 1
		banned = _BANNED[string.lower(_args['banned' .. index] or '')]
	end

	return statusContents
end

function CustomPlayer._createLocations()
	local countryDisplayData = {}
	local country = _args.country or _args.country1
	if String.isEmpty(country) then
		return countryDisplayData
	end

	countryDisplayData[1] = CustomPlayer:_createLocation(country)

	local index = 2
	country = _args['country2']
	while (not String.isEmpty(country)) do
		countryDisplayData[index] = CustomPlayer:_createLocation(country)
		index = index + 1
		country = _args['country' .. index]
	end

	return countryDisplayData
end

function CustomPlayer:_createLocation(country)
	if String.isEmpty(country) then
		return nil
	end
	local countryDisplay = Flags.CountryName(country)
	local demonym = Localisation.getLocalisation(countryDisplay)

	return Flags.Icon({flag = country, shouldLink = true}) .. '&nbsp;' ..
				'[[:Category:' .. countryDisplay .. '|' .. countryDisplay .. ']]'
				.. '[[Category:' .. demonym .. ' Players]]'
end

function CustomPlayer._createRole(key, role)
	if String.isEmpty(role) then
		return nil
	end

	local roleData = _ROLES[role:lower()]
	if not roleData then
		return nil
	end

	return '[[:Category:' .. roleData.category .. '|' ..
		Variables.varDefineEcho(key or 'role', roleData.variable) .. ']]'
end


return CustomPlayer
