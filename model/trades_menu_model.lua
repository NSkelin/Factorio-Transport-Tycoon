Trades_menu_view = require("views.trades_menu_view")
Search_history = require("data.Search_history")

local Trades_menu_model = {
    trades_menu_view = Trades_menu_view:new(),
    active = false,
	search_history = Search_history:new(),
	categories = {
		traders=true,
		malls=true,
	},
	pagination ={
		pages = {},
		button_set = 1,
		max_buttons_per_set = 10,
	},
}

----------------------------------------------------------------------
-- public functions

function Trades_menu_model:new(view)
	local trades_menu_model = {
        trades_menu_view = view,
        active = false,
        search_history = Search_history:new(),
        categories = {
            traders=true,
            malls=true,
        },
		pagination ={
			pages = {},
			button_set = 1,
			max_buttons_per_set = 10,
		},
	}
	setmetatable(trades_menu_model, self)
	self.__index = self

	return trades_menu_model
end

-- re-sets the metatable of an instance
function Trades_menu_model:reset_metatable(trades_menu_model_instance)
	setmetatable(trades_menu_model_instance, self)
	self.__index = self
end

-- opens players trade menu if closed; closes players trade menu if open
function Trades_menu_model:toggle(player)
	if self.active == false then
		self:open_trades_menu(player)
	else
		self:close_trades_menu(player)
	end
end

-- open the trades menu
function Trades_menu_model:open_trades_menu(player)
	player.set_shortcut_toggled("trades", true)
	self.trades_menu_view:create(player)

	if #self.search_history >= 1 then
		local search = self.search_history[1]
		self:search_for_item(player, search, true, false)
	else
		-- create data
		self:create_view_data(player)

		-- send data to view
		self.trades_menu_view:update_trades_list(self.pagination.pages[1], self.categories.group_by_city)
		self:create_pagination_button_set(1)
	end

	self.active = true
end

-- searchs each city for entities with the item in the recipe
function Trades_menu_model:search_for_item(player, search, update_search_bar, add_to_search_history)
	-- create data
	self:create_view_data(player, search)

	-- send data to view
	self.trades_menu_view:update_trades_list(self.pagination.pages[1], self.categories.group_by_city)
	self:create_pagination_button_set(1)

	if update_search_bar then
		self.trades_menu_view:update_search_text(player, search)
	end

	if add_to_search_history then
		self.search_history:add_search(search)
	end
end

-- closes gui and resets search history
function Trades_menu_model:close_trades_menu(player)
	player.set_shortcut_toggled("trades", false)
	self.trades_menu_view:destroy(player)
	self.active = false
end

-- closes gui without reseting search history
function Trades_menu_model:minimize(player)
	player.set_shortcut_toggled("trades", not self.active)
	self.trades_menu_view:destroy(player)
	self.active = false
end

function Trades_menu_model:move_backward_in_search_history(player)
	self.search_history:remove_last_added_term()

	local new_search = Search:new("any", "")

	if #self.search_history >= 1 then
		new_search = self.search_history[1]
	end

	self:search_for_item(player, new_search, true, false)
end

---Updates the trades_menu_view with a new list of trades based on the pagination page selected
---@param page integer
function Trades_menu_model:switch_page(page)
	if page <= #self.pagination.pages and page >= 1 then
		self.trades_menu_view.trades_list.clear()
		self.trades_menu_view:add_trades_to_trades_list(self.pagination.pages[page], self.categories.group_by_city)
	end
end

function Trades_menu_model:switch_pagination_set(direction)
	local current_set = self.pagination.button_set
	local new_set = 0
	local last_possible_set =  math.ceil(#self.pagination.pages / self.pagination.max_buttons_per_set)

	-- get the new set
	if direction == "first" then
		new_set = 1
	elseif direction == "last" then
		new_set = last_possible_set
	elseif direction == "next" then
		new_set = current_set + 1
	elseif direction == "previous" then
		new_set = current_set - 1
	end

	self:create_pagination_button_set(new_set)
end

---inverts the boolean filter and refreshes the GUI to reflect the filter changes
---@param player LuaPlayer the player this effects
---@param filter string the name of the filter
function Trades_menu_model:invert_filter(player, filter)
	self.categories[filter] = not self.categories[filter]

	-- create data
	self:create_view_data(player)

	-- send data to view
	self.trades_menu_view:update_trades_list(self.pagination.pages[1], self.categories.group_by_city)
	self:create_pagination_button_set(1)
end

----------------------------------------------------------------------
-- private functions

-- searches each city on the map for any entities matching the models filters and then
-- creates a table of data thats parsable for the trades_menu_view
function Trades_menu_model:create_view_data(player, filter)
	local cities_entities = {}
	for i, city in ipairs(global.cities) do
		local filtered_city = {}
		local city_entities = get_city_entities(city, self.categories)
		if filter then
			local filtered_entities = filter_entities_by_recipe(city_entities, filter)
			filtered_city.assembling_machines = filtered_entities
		else
			filtered_city.assembling_machines = city_entities
		end
		table.insert(cities_entities, filtered_city)
	end

	local max_group_size = settings.get_player_settings(player)["max-trades-per-page"].value
	self.pagination.pages = self:split_entities_into_groups(cities_entities, max_group_size)
end

-- group assemblers into pages and pages into groups
function Trades_menu_model:split_entities_into_groups(entities, max_group_size)
	local pages = {}
	local page = {}
	local page_count = 0

	function add_page()
		table.insert(pages, page)
		page = {}
		page_count = 0
	end

	for i, city in ipairs(entities) do

		-- if the page can hold the city without going past the max group size then add the entire city
		if #city.assembling_machines + page_count <= max_group_size then
			table.insert(page, city)
			page_count = page_count + #city.assembling_machines

		-- if the page isnt full but cant hold the entire city, partially add the city to fill the page.
		-- then create a new page and add the remaining parts of the city. if this page fills repeat
		-- until nothing remains of the city
		elseif page_count < max_group_size then
			local city_group = {assembling_machines={}}
			for n, entity in ipairs(city.assembling_machines) do
				if (page_count + #city_group.assembling_machines) < max_group_size then
					table.insert(city_group.assembling_machines, entity)
				else
					table.insert(page, city_group)
					add_page()
				end
			end
		end

		if page_count >= max_group_size then
			add_page()
		end
	end

	if page_count > 0 then -- add last page
		add_page()
	end
	return pages
end

function Trades_menu_model:create_pagination_button_set(set)
	local last_possible_set =  math.ceil(#self.pagination.pages / self.pagination.max_buttons_per_set)

	-- no results
	if last_possible_set == 0 then self.trades_menu_view:update_pagination_buttons(0,0) end
	-- invalid set
	if set < 1 or set > last_possible_set then return end
	
	-- figure out how many buttons and what their numbers are
	local button_amount = self.pagination.max_buttons_per_set
	if set == last_possible_set then
		button_amount = #self.pagination.pages % self.pagination.max_buttons_per_set
		--if there was no remainder that means it should be full
		if button_amount == 0 then button_amount = self.pagination.max_buttons_per_set end
	end
	local start_num = ((set -1) * self.pagination.max_buttons_per_set) + 1

	self.trades_menu_view:update_pagination_buttons(start_num, button_amount)
	self.pagination.button_set = set
end

-- return each assembling machine that has the item in its recipe ingredients and / or products
function filter_entities_by_recipe(entities, search)
	local filtered_entities = {}
	
	for i, assembler in ipairs(entities) do
		local recipe = assembler.get_recipe()
		if recipe_contains(recipe, search) then
			table.insert(filtered_entities, assembler)
		end
	end

	return filtered_entities
end

-- check if a recipe has an item in ingredients and / or products   
function recipe_contains(recipe, search)
	function search_recipe(search_string, list)
		for i, item in ipairs(list) do
			if string.find(item.name, search_string, 0, true) then
				return true
			end
		end
		return false
	end
	-- search products and ingredients for the item_name
	if search.item_name then
		if search_recipe(search.item_name, recipe.products) or
			search_recipe(search.item_name, recipe.ingredients) then
			return true
		else
			return false
		end
	elseif search.product_name and search.ingredient_name then
		if search_recipe(search.product_name, recipe.products) and
			search_recipe(search.ingredient_name, recipe.ingredients) then
			return true
		else
			return false
		end
	elseif search.product_name then
		return search_recipe(search.product_name, recipe.products)
	elseif search.ingredient_name then
		return search_recipe(search.ingredient_name, recipe.ingredients)
	else
		return true
	end
end

---Get entities that make up the city.
---@param city City the city the entities are coming from
---@param entity_types city_entity_types which types of entities to get
---@return table[] entities an array of entities from the city
function get_city_entities(city, entity_types)
	---@class city_entity_types
	---@field traders boolean
	---@field malls boolean
	---@field other boolean

	local entities = {}

	---Adds each entity from an array into entities array
	---@param entities_list table[]
	function add_entities(entities_list)
		for i, entity in ipairs(entities_list) do
			table.insert(entities, entity)
		end
	end

	-- Add specified entity types to entities array
	if entity_types.traders then
		add_entities(city.buildings.traders)
	end
	if entity_types.malls or false then
		add_entities(city.buildings.malls)
	end
	if entity_types.other or false then
		add_entities(city.buildings.other)
	end

	return entities
end

return Trades_menu_model