Search = require("data.Search")
Search_history = require("data.Search_history")
Trade_menu = require("scripts.gui")
Trades_menu_view = require("views.trades_menu_view")
Trades_menu_model = require("model.trades_menu_model")
City = require("scripts.city_generation")

DEBUG = true -- Used for debug, users should not enable
local debugCount = 0 -- Stops debugging messages
local debugMaxCount = 0 -- Maximum debug messages, 0 for infinite
local debugType = "File" -- "File" to output to a .log file, "Terminal" to output to terminal, anything else to output to in-game console

-- Writes to the final debug output method based on type selection
local function debugWriteType(text)
	if debugType == "File" then
		game.write_file("traderouteoverhaul-debug.log", text, true)
	elseif debugType == "Terminal" then
		log(text)
	else
		game.print(text)
	end
end

-- Debug writer for calling elsewhere in the program
function debugWrite(text)
	if DEBUG then
		debugCount = debugCount + 1
		if debugMaxCount == 0 or debugCount < debugMaxCount then
			debugWriteType(text)
		elseif debugCount == debugMaxCount then 
			debugWriteType("Message count at " .. debugMaxCount .. ", logging stopped")
		end
	end
end

local a = 214013 
local c = 2531011 
local M = 0x80000000
local state = settings.startup["base-item-values-seed"].value

-- Returns an integer from 0 to N - 1
function rand(N)
	state = (a * state + c) % M
	return (math.floor( N*state / M ))
end

--control.lua
global.machine_entities={}
global.city_need_map={}
minimum_city_distance = settings.global["minimum-city-distance"].value

cycles = { {1,2,3,4}, {1,2,3,4,5}, {1,2,3,4,5,6}, {{1,3,5},{2,4,6}}, {1,2,3,4,5,6,7}, {1,2,3,4,5,6,7} }
trade_map_set = { 
	{ {2,3,4}, {1,3,4}, {1,2,4}, {1,2,3} }, 
	{ {2,3}, {3,4}, {4,5}, {5,1}, {1,2} }, 
	{ {2,3,4}, {3,4}, {4,5,6}, {5,6}, {6,1,2}, {1,2} }, 
	{ {2,4}, {3,4,6}, {4,6}, {5,6}, {2,6}, {1} }, 
	{ {2,3,4}, {3,4,5}, {4,5,6}, {5,6,7}, {6,7,1}, {7,1,2}, {1,2,3} }, 
	{ {2,3}, {3,4}, {4,5}, {5,6}, {6,7}, {7,1}, {1,2} } 
}
global.trade_map = { 
	{ {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {}, {} } 
}
bad_trade_map_set = { 
	{ {}, {}, {}, {} }, 
	{ {4,5}, {5,1}, {1,2}, {2,3}, {3,4} }, 
	{ {5,6}, {5,6,1}, {1,2}, {1,2,3}, {3,4}, {3,4,5} }, 
	{ {6}, {1,5}, {2}, {1,2,3}, {4}, {2,3,4,5} }, 
	{ {5,6,7}, {6,7,1}, {7,1,2}, {1,2,3}, {2,3,4}, {3,4,5}, {4,5,6} }, 
	{ {4,5,6,7}, {5,6,7,1}, {6,7,1,2}, {7,1,2,3}, {1,2,3,4}, {2,3,4,5}, {3,4,5,6} } 
}
global.bad_trade_map = { 
	{ {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {}, {} }, 
	{ {}, {}, {}, {}, {}, {}, {} } 
}


--spawn cities on chunk generation
script.on_event({defines.events.on_chunk_generated},
   function (event)
		if math.random(1,100)>math.max(1,settings.global["probability-of-city-placement"].value) then return end
		local city_center = event.area
		local surface = event.surface
		local city = City:new()
		if city:spawn_city(surface, city_center) then
			table.insert(global.cities, city)
		end
	end
)

script.on_init(function()
	global.players = {}
	global.cities = {}
	-- removed crashsite and cutscene start, so on_player_created inventory safe
	remote.call("freeplay", "set_disable_crashsite", true)  
	
	-- Skips popup message to press tab to start playing
	remote.call("freeplay", "set_skip_intro", true)

	--game.surfaces.nauvis.always_day = true
	--end recipes
	if game.forces["player"].stack_inserter_capacity_bonus < 7 then
		game.forces["player"].stack_inserter_capacity_bonus = 7
	end
	if game.forces["player"].inserter_stack_size_bonus < 3 then
		game.forces["player"].inserter_stack_size_bonus = 3
	end
	
	--spawn starting buildings
	found = game.surfaces[1].find_non_colliding_position("rocket-silo", {0,0}, 0, 3) 
	if found then
		city = game.surfaces[1].create_entity{name="rocket-silo", position=found, force=game.forces.player} 
		--prevent removal of cities as thats game breaking
		city.destructible = false
		city.minable = false
		--prevent player from changing trades
		city.recipe_locked = true 
		city.operable =true
	end --end if

	-- need coal source
	foundcoal = game.surfaces[1].find_non_colliding_position("assembling-machine-1", {math.random(-1, 1)*8,math.random(-1, 1)*8}, 30, 8, true) 
	if foundcoal then
		city = game.surfaces[1].create_entity{name="assembling-machine-1", position=foundcoal, force=game.forces.player, recipe ="Coal"}
		--prevent removal of cities as thats game breaking
		city.destructible = false
		city.minable = false
		
		--prevent player from changing trades
		city.recipe_locked = true 
		
		city.operable =true
		table.insert(global.machine_entities, city)
	end
	foundcoal = game.surfaces[1].find_non_colliding_position("assembling-machine-1", {math.random(-1, 1)*8,math.random(-1, 1)*8}, 30, 8, true) 
	if foundcoal then
		if settings.global["start-with-trains"].value then
			city = game.surfaces[1].create_entity{name="assembling-machine-1", position=foundcoal, force=game.forces.player, recipe ="Rails"}
						--prevent removal of cities as thats game breaking
						city.destructible = false
						city.minable = false
						
						--prevent player from changing trades
						city.recipe_locked = true 
						
						city.operable =true
						table.insert(global.machine_entities, city)
		else
			city = game.surfaces[1].create_entity{name="assembling-machine-1", position=foundcoal, force=game.forces.player, recipe ="Belts"}
						--prevent removal of cities as thats game breaking
						city.destructible = false
						city.minable = false
						
						--prevent player from changing trades
						city.recipe_locked = true 
						
						city.operable =true
						table.insert(global.machine_entities, city)
		end
	end

	function shuffle (input)
		local output = input
		for n=1,#output-1 do
		 roll = rand(#output-n+1)+n
		 temp = output[n]
		 output[n] = output[roll]
		 output[roll] = temp
		end
		return output
	end
	cycles = { shuffle(cycles[1]), shuffle(cycles[2]), shuffle(cycles[3]), {shuffle(cycles[4][1]),shuffle(cycles[4][2])}, shuffle(cycles[5]), shuffle(cycles[6]) }
	cycles[4] = { cycles[4][1][1], cycles[4][2][1], cycles[4][1][2], cycles[4][2][2], cycles[4][1][3], cycles[4][2][3] }
	for i=1,#trade_map_set do
		for j=1,#trade_map_set[i] do
			for k=1,#trade_map_set[i][j] do
				table.insert(global.trade_map[i][ cycles[i][j] ], cycles[i][ trade_map_set[i][j][k] ])
				--trade_map[i][ cycles[i][j] ][k] = cycles[i][ trade_map_set[i][j][k] ]
			end
		end
	end
	for i=2,#bad_trade_map_set do
		for j=1,#bad_trade_map_set[i] do
			for k=1,#bad_trade_map_set[i][j] do
				table.insert(global.bad_trade_map[i][ cycles[i][j] ], cycles[i][ bad_trade_map_set[i][j][k] ])
				--trade_map[i][ cycles[i][j] ][k] = cycles[i][ trade_map_set[i][j][k] ]
			end
		end
	end
end)

script.on_event(defines.events.on_player_created, function(e)
	--wipe inventory as we dont want starter machines available

	local player = game.get_player(e.player_index)
	  player.clear_items_inside()
	--remove all tech on spawn (if this causes problems it should prolly be moved to init as its faction based not player based - but this ensures a player exists)
	  --game.forces["player"].disable_research()
	--given started coin
	player.insert({name="transport-belt", count=1000})
	player.insert({name="splitter", count=50})
	player.insert({name="underground-belt", count=50})
	player.insert({name="loader", count=50})
	player.insert({name="wooden-chest", count=50})
	player.insert({name="car", count=1})
	
	if settings.global["start-with-trains"].value then
		player.insert({name="rail", count=1000})
		player.insert({name="train-stop", count=10})
		player.insert({name="rail-signal", count=50})
		player.insert({name="rail-chain-signal", count=50})
		player.insert({name="locomotive", count=5})
		player.insert({name="cargo-wagon", count=5})
		player.insert({name="fast-inserter", count=50})
	end
	--set filters and bars
	player.set_active_quick_bar_page(1, 10)
	player.set_active_quick_bar_page(2, 1)
	player.set_active_quick_bar_page(3, 2)
	player.set_active_quick_bar_page(4, 3)

	--tier 1
	  player.set_quick_bar_slot(1,"stone")
	  player.set_quick_bar_slot(2,"coal")
	  player.set_quick_bar_slot(3,"copper-ore")
	  player.set_quick_bar_slot(4,"iron-ore")
	  player.set_quick_bar_slot(10, "automation-science-pack")
	--tier 2
	  player.set_quick_bar_slot(11,"copper-cable")
	  player.set_quick_bar_slot(12,"iron-stick")
	  player.set_quick_bar_slot(13,"stone-brick")
	  player.set_quick_bar_slot(14,"copper-plate")
	  player.set_quick_bar_slot(15,"iron-plate")
	  player.set_quick_bar_slot(20, "logistic-science-pack")
	  --tier 3
	  player.set_quick_bar_slot(21,"pipe")
	  player.set_quick_bar_slot(22,"steel-plate")
	  player.set_quick_bar_slot(23,"iron-gear-wheel")
	  player.set_quick_bar_slot(24,"electronic-circuit")
	  player.set_quick_bar_slot(25,"firearm-magazine")
	  player.set_quick_bar_slot(26,"stone-wall")
	  player.set_quick_bar_slot(30, "military-science-pack")
	--tier 4
	  player.set_quick_bar_slot(31,"lubricant-barrel")
	  player.set_quick_bar_slot(32,"plastic-bar")
	  player.set_quick_bar_slot(33,"petroleum-gas-barrel")
	  player.set_quick_bar_slot(34,"explosives")
	  player.set_quick_bar_slot(35,"sulfuric-acid-barrel")
	  player.set_quick_bar_slot(36,"rocket-fuel")
	  player.set_quick_bar_slot(40, "chemical-science-pack")
	--tier 5
	  player.set_quick_bar_slot(41,"engine-unit")
	  player.set_quick_bar_slot(42,"advanced-circuit")
	  player.set_quick_bar_slot(43,"low-density-structure")
	  player.set_quick_bar_slot(44,"electric-engine-unit")
	  player.set_quick_bar_slot(45,"speed-module")
	  player.set_quick_bar_slot(46,"effectivity-module")
	  player.set_quick_bar_slot(47,"productivity-module")
	  player.set_quick_bar_slot(50, "production-science-pack")
	--tier 6
	  player.set_quick_bar_slot(51,"battery")
	  player.set_quick_bar_slot(52,"electric-engine-unit")
	  player.set_quick_bar_slot(53,"logistic-robot")
	  player.set_quick_bar_slot(54,"construction-robot")
	  player.set_quick_bar_slot(55,"processing-unit")
	  player.set_quick_bar_slot(56,"rocket-control-unit")
	  player.set_quick_bar_slot(57,"atomic-bomb")
	  player.set_quick_bar_slot(60, "utility-science-pack")
	  
	--utility bar 0
	player.set_quick_bar_slot(91, "transport-belt")
	player.set_quick_bar_slot(92, "splitter")
	player.set_quick_bar_slot(93, "underground-belt")
	player.set_quick_bar_slot(94, "loader")
	player.set_quick_bar_slot(95, "wooden-chest")
	player.set_quick_bar_slot(96, "radar")
	player.set_quick_bar_slot(97, "car")
	player.set_quick_bar_slot(98, "coal")
	player.set_quick_bar_slot(99, "repair-pack")
end)

function get_city_tier(coord)
	max_tier = 1
	x = math.abs(coord.x)
	y= math.abs(coord.y)

	local factor = 1

	if x > factor*1.5*minimum_city_distance or y > factor*1.5*minimum_city_distance then max_tier = 2 end
	if x > factor*2.5*minimum_city_distance or y > factor*2.5*minimum_city_distance then max_tier = 3 end
	if x > factor*3.5*minimum_city_distance or y > factor*3.5*minimum_city_distance then max_tier = 4 end
	if x > factor*4.5*minimum_city_distance or y > factor*4.5*minimum_city_distance then max_tier = 5 end
	if x > factor*5.5*minimum_city_distance or y > factor*5.5*minimum_city_distance then max_tier = 6 end

	tier = math.random(1, max_tier)

	return tier
end


function record_city(tier, loc, science)
	table.insert(global.city_need_map, {loc=loc, tier=tier, science= science})
end

script.on_event(defines.events.on_script_path_request_finished, function(e)
	if e.path ~=nil and next(e.path) ~=nil then
	--game.get_player(1).print("path")
		pavement ={}
		for k,v in ipairs(e.path)do
		table.insert(pavement, v.position)
		--game.get_player(1).print(v.position)
		end
			tiles=
		{
		--"dry-dirt",
		--"stone-path",
		--"concrete",
		--"hazard-concrete-left",
		"refined-concrete",
		"refined-hazard-concrete-right",
		--"tutorial-grid",
		}
		for i,v in ipairs(pavement) do
		paved[i]={name = tiles[math.random(#tiles)], position = v} 
		end
		game.surfaces[1].set_tiles(paved)
	end
end)

function distance ( x1, y1, x2, y2 )
	local dx = x1 - x2
	local dy = y1 - y2
	return math.sqrt ( dx * dx + dy * dy )
end

if settings.global["map-tags"].value then
	script.on_event({defines.events.on_tick},
	   function (e)
		if e.tick > 100 and e.tick % 2 == 0 then 
			update_map()
		end
	end
	)
end

function update_map()
	if next(global.city_need_map) ~= nil then       
		v = table.remove(global.city_need_map, math.random(#global.city_need_map))
		--game.get_player(1).print(#global.city_need_map)   
		--game.get_player(1).print("Popped V"..v.loc[1])        
	
		signalID = {type = "", name = ""}               
		--if v.science then
		signalID = {type = "item",}             
		if v.tier == 1 then signalID.name = "automation-science-pack" end
		if v.tier == 2 then signalID.name = "logistic-science-pack" end
		if v.tier == 3 then signalID.name = "military-science-pack" end
		if v.tier == 4 then signalID.name = "chemical-science-pack" end
		if v.tier == 5 then signalID.name = "production-science-pack" end
		if v.tier == 6 then signalID.name = "utility-science-pack" end
		if v.tier == 7 then signalID.name = "space-science-pack" end
		tag = {position=v.loc, text = "", icon = signalID}
		--end
		--if not v.science then tag = {position=v.loc, text = ""..v.tier.."" }  end 
		valid = game.players[1].force.add_chart_tag(game.surfaces[1], tag)
		if valid == nil then table.insert(global.city_need_map,v) 
		--game.get_player(1).print("repushed V"..v.loc[1])  
		end	
	end 
end --end function

function convert_search_text_to_search_object(search_text)
	index_start, index_end = string.find(search_text, ":")
	if index_end == nil then
		local item = string.gsub(search_text, " ", "-")
		return Search:new{item_name=item}
	else
		filter = string.sub(search_text, 1, index_end - 1) -- text before ":"
		local item = string.sub(search_text, index_end + 1, -1) -- text after ":"
		item = string.gsub(search_text, " ", "-")
		if filter == "ingredients" then
			return Search:new{ingredient_name=item}
		elseif filter == "products" then
			return Search:new{product_name=item}
		end
	end

	return Search:new{item_name=""}
end

script.on_event(defines.events.on_player_joined_game, 
	function(event)
		local player = game.get_player(event.player_index)
		local view = Trades_menu_view:new()
		global.players[player.index] = {
			trades_menu_view = view,
			trades_menu_model = Trades_menu_model:new(view),
		}
	end
)

script.on_event(defines.events.on_gui_click,
	function(event)
		local player = game.get_player(event.player_index)
		local player_global = global.players[player.index]
		local elem_name = event.element.name
		local elem_tags = event.element.tags
		if elem_name == "tro_trade_menu_header_exit_button" then
			player_global.trades_menu_model:close_trades_menu(player)

		elseif elem_name == "tro_ping_button" then
			player.print("[gps=".. event.element.tags.location.x ..",".. event.element.tags.location.y .."]")

		elseif elem_name == "tro_goto_button" then
			player.zoom_to_world(event.element.tags.location, 1)
			player_global.trades_menu_model:minimize(player)

		-- handle trades menu filter changes
		elseif elem_tags.action == "toggle_filter" then
			local filter = elem_tags.filter
			player_global.trades_menu_model:invert_filter(player, filter)

		-- click on sprite buttons
		elseif elem_tags.action == "tro_filter_list" then
			local tag = event.element.tags
			local search = {}
			if event.button == 4 then -- right mouse button
				search = Search:new{ingredient_name=tag.item_name}
			elseif event.button == 2 then -- left mouse button
				search = Search:new{product_name=tag.item_name}
			end
			player_global.trades_menu_model:search_for_item(player, search, true, true)
		elseif elem_tags.action == "tro_move_back_in_search_history" then
			player_global.trades_menu_model:move_backward_in_search_history(player)

		-- pagination buttons
		elseif elem_tags.action == "switch_pagination_page" then
			player_global.trades_menu_model:switch_page(event.element.tags.page_number)
		elseif elem_name == "pagination_first_set" then
			player_global.trades_menu_model:switch_pagination_set("first")
		elseif elem_name == "pagination_previous_set" then
			player_global.trades_menu_model:switch_pagination_set("previous")
		elseif elem_name == "pagination_next_set" then
			player_global.trades_menu_model:switch_pagination_set("next")
		elseif elem_name == "pagination_last_set" then
			player_global.trades_menu_model:switch_pagination_set("last")
		end
	end
)

script.on_event(defines.events.on_lua_shortcut,
	function(event)
		local player = game.get_player(event.player_index)
		if event.prototype_name == "trades" then
			global.players[player.index].trades_menu_model:toggle(player)
		end
	end
)

script.on_event(defines.events.on_gui_text_changed,
	function(event)
		local player = game.get_player(event.player_index)
		local player_global = global.players[player.index]
		local new_search = event.element.text
		player_global.trades_menu_model:search_for_item(player, convert_search_text_to_search_object(new_search), false, false)
	end
)

script.on_event("tro_move_backwards_in_search_history",
	function(event)
		local player = game.get_player(event.player_index)
		local player_global = global.players[player.index]
		player_global.trades_menu_model:move_backward_in_search_history(player)
	end
)

script.on_event("tro_toggle_trade_menu",
	function(event)
		local player = game.get_player(event.player_index)
		local player_global = global.players[player.index]
		player_global.trades_menu:toggle(player)
	end
)

script.on_load(
	function()
		-- re-setup metatables 
		for i, player in ipairs(global.players) do
			local player_trades_menu = player.trades_menu
			if player_trades_menu == nil then break end
			Trade_menu:reset_metatable(player_trades_menu)

			local player_search_history = player_trades_menu.search_history
			if player_search_history == nil then break end
			Search_history:reset_metatable(player_search_history)
		end
	end
)

-- add trade menu if it didnt exist
script.on_configuration_changed(
	function(event)

		-- add a trade_menu to each player without one.
		for i, player in ipairs(global.players) do
			if player.trades_menu == nil then
				global.players[i] = {
					trades_menu = Trade_menu:new()
				}
			end
		end

		if global.cities == nil then
			global.cities = {}
			-- add all existing cities into one big city group
			local surface_entities = game.surfaces[1].find_entities_filtered{force="player"}

			local city = City:new()
			for i, entity in ipairs(surface_entities) do
				if entity.name == "assembling-machine-1" 
				or entity.name == "assembling-machine-2"
				or entity.name == "assembling-machine-3" then
					table.insert(city.buildings.traders, entity)

				elseif entity.name == "rocket-silo"
				or entity.name == "beacon"
				or entity.name == "lab" then
					table.insert(city.buildings.other, entity)
				end
			end
			table.insert(global.cities, city)
		end
	end
)