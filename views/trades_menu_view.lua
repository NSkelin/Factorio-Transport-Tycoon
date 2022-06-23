Search_history = require("data.Search_history")

---@class Trades_menu_view
---@field pagination_pages table[] An array of all the pagination pages
---@field current_page number The current page being rendered inside the trades list
---@field max_pagination_buttons number The max amount of page buttons allowed to render at one time.
---@field pagination_button_set number The current set of buttons being rendered.
local Trades_menu_view = {}

----------------------------------------------------------------------
-- public functions

function Trades_menu_view:new()
	local trades_menu_view = {
		trades_list = nil,
		pagination_buttons = nil,
	}
	setmetatable(trades_menu_view, self)
	self.__index = self

	return trades_menu_view
end

-- re-sets the metatable of an instance
function Trades_menu_view:reset_metatable(trades_menu_instance)
	setmetatable(trades_menu_instance, self)
	self.__index = self
end

-- creates the entire trades_menu GUI without data
function Trades_menu_view:create(player)
	local screen_element = player.gui.screen
	local root_frame = screen_element.add{type="frame", name="tro_trade_root_frame", direction="vertical", style="tro_trades_gui"}

	self:create_title_bar(root_frame)
	self:create_filter_options(root_frame)
	self.trades_list = root_frame.add{type="scroll-pane", name="tro_trades_list", direction="vertical", style="inventory_scroll_pane"}
	self:create_pagination(root_frame)

	root_frame.auto_center = true
end

-- destroys the root gui element and all its child elements
function Trades_menu_view:destroy(player)
	local player_global = global.players[player.index]
	local screen_element = player.gui.screen
	local root_element = screen_element["tro_trade_root_frame"]

	root_element.destroy()

	-- update players state
	self.active = not self.active
end

-- changes the GUI search box text
function Trades_menu_view:update_search_text(player, search)
	local textfield = player.gui.screen["tro_trade_root_frame"]["tro_filter_bar"]["tro_trade_menu_search"]
	local text = ""

	if search.item_name then
		text = search.item_name
	elseif search.product_name then
		text = "products" .. ":" .. search.product_name
	elseif search.ingredient_name then
		text = "products" .. ":" .. search.ingredient_name
	end

	textfield.text = text
end

-- clears the old trades and adds new ones
function Trades_menu_view:update_trades_list(assemblers, group)
	self.trades_list.clear()
	if assemblers then
		self:add_trades_to_trades_list(assemblers, group)
	end
end

-- clears the old buttons and adds new ones
function Trades_menu_view:update_pagination_buttons(button_start_num, button_amount)
	self.pagination_buttons.clear()
	self:create_pagination_buttons(button_start_num, button_amount)
end

----------------------------------------------------------------------
-- private functions

function Trades_menu_view:create_title_bar(root_element)
	local header = root_element.add{type="flow", name="tro_trade_menu_header", direction="horizontal"}
	header.add{type="label", caption={"tro.trade_menu_title"}, style="frame_title"}
	local filler = header.add{type="empty-widget", style="draggable_space"}
	filler.style.height = 24
		filler.style.horizontally_stretchable = true
		filler.drag_target = root_element
	header.add{
		type = "sprite-button",
		name = "tro_trade_menu_header_exit_button",
		style = "frame_action_button",
		sprite = "utility/close_white",
		hovered_sprite = "utility/close_black",
		clicked_sprite = "utility/close_black"
	}
end

function Trades_menu_view:create_filter_options(root_element)
	filter_flow = root_element.add{type="flow", direction="horizontal", name="tro_filter_bar"}
	filter_flow.add{type="textfield", name="tro_trade_menu_search", tooltip = {"tro.trade_menu_textfield"}}
	filter_flow.add{
		type="button",
		caption="back",
		tags={action="tro_move_back_in_search_history"},
		tooltip = {"tro.trade_menu_back_but"}
	}	filter_flow.add{
		type="button",
		caption="group",
		tags={action="toggle_filter", filter="group_by_city"},
		tooltip = {"tro.group_trades_button"},
		style="tro_trade_group_button",
	}	filter_flow.add{
		type="button",
		caption="trades",
		tags={action="toggle_filter", filter="traders"},
		tooltip = {"tro.allow_trades_button"},

	}	filter_flow.add{
		type="button",
		caption="malls",
		tags={action="toggle_filter", filter="malls"},
		tooltip = {"tro.allow_malls_button"}
	}
end

function Trades_menu_view:add_trades_to_trades_list(cities, group)
	local parent_element

	for i, city in ipairs(cities) do

		-- if a user wants trades grouped by their city then keep them in a seperate flow for each city
		if group then
			parent_element = self.trades_list.add{type="frame", direction="vertical"}
		else
			parent_element = self.trades_list
		end

		-- create the trade row
		for i, assembling_machine in ipairs(city.assembling_machines) do
			self:create_trade_row(parent_element, assembling_machine)
		end
	end

	
end

-- create the ui for a trade row
function Trades_menu_view:create_trade_row(element, assembler)
	-- disassemble assembler into usable parts
	local recipe = assembler.get_recipe()
	local position = assembler.position
	local ingredients = recipe.ingredients
	local products = recipe.products

	local root = element.add{type="frame", style="tro_trade_row"}
	local trade_row_flow = root.add{type="flow", style="tro_trade_row_flow"} -- needed for vertical align (wont work on root frame)

	-- create row buttons
	trade_row_flow.add{
		type="button",
		caption="ping",
		name="tro_ping_button",
		tags={location=position}, 
		tooltip={"tro.trade_menu_ping"}
	}
	trade_row_flow.add{
		type="button",
		caption="goto",
		name="tro_goto_button",
		tags={location=position},
		tooltip={"tro.trade_menu_goto"}
	}
	
	-- create sprite buttons and labels for each ingredient 
	if #ingredients == 0 then goto products end-- recipes can have no ingredient (free items)
	for i, ingredient in ipairs(ingredients) do
		self:create_trade_row_item(trade_row_flow, ingredient, "ingredient")
	end

	-- create divider between ingredients and products
	trade_row_flow.add{type="label", caption = " --->"}

	::products::
	-- create sprite buttons and labels for each product
	for i, product in ipairs(products) do
		self:create_trade_row_item(trade_row_flow, product, "product")
	end
end

-- create a custom set of elements for the trade row
function Trades_menu_view:create_trade_row_item(element, item, type)
	element.add{
		type = "sprite-button",
		sprite = item.type .. "/" .. item.name, 
		tags = {
			action = "tro_filter_list",
			item_name = item.name,
			filter = type, 
			type = item.type
		},
		tooltip = {"", {"tro.item_name"}, ": ", item.name, " | ", {"tro.trade_menu_item_sprite_button_instructions"}}
	}
	-- item amount
	element.add{type = "label", caption = item.amount}
end

function Trades_menu_view:create_pagination(root_element)
	local root = root_element.add{type="frame", direction="horizontal", name="tro_page_index_root", style="tro_page_index_root"}
	root.add{type="button", caption="<<", style="tro_page_index_button", name="pagination_first_set"}
	root.add{type="button", caption="<", style="tro_page_index_button", name="pagination_previous_set"}
	self.pagination_buttons = root.add{type="flow", name="tro_page_index_button_flow", style="tro_page_index_button_flow"}
	root.add{type="button", caption=">", style="tro_page_index_button", name="pagination_next_set"}
	root.add{type="button", caption=">>", style="tro_page_index_button", name="pagination_last_set"}
end

function Trades_menu_view:create_pagination_buttons(start_num, button_amount)
	local end_num = start_num + button_amount - 1 -- start 1 + 4 buttons = 5 buttons so - 1 to be actual button amount
	for i = start_num, end_num do
		self.pagination_buttons.add{
			type = "button",
			caption = i,
			style = "tro_page_index_button",
			tags = {
				action = "switch_pagination_page", 
				page_number = i
			}
		}
	end
end

-- creates a ui explaining the search for an item failed as well as next steps
function Trades_menu_view:create_failed_search_message(list, player, search_term)
	local search_history = self.search_history
	local message_element = list.add{type="flow"}
	local horizontal_flow = message_element.add{type="flow", direction="horizontal"}

	-- main text
	if self.filter.products == true and self.filter.ingredients == true then
		horizontal_flow.add{type="label", caption="No recipes found."}
	elseif self.filter.products == true then
		horizontal_flow.add{type="label", caption="No recipes create"}
		horizontal_flow.add{type="sprite", sprite=search_history[1].item_type .. "/" .. search_history[1].searched_item}
		horizontal_flow.add{type="label", caption=search_term}
	elseif self.filter.ingredients == true then
		horizontal_flow.add{type="label", caption="No recipes require"}
		horizontal_flow.add{type="sprite", sprite=search_history[1].item_type .. "/" .. search_history[1].searched_item}
		horizontal_flow.add{type="label", caption=search_term}
	else
		horizontal_flow.add{type="label", caption="Unknown filter!"}
	end

	-- ending text
	if #search_history > 0 then
		message_element.add{type="label", caption='Try searching for something else. Or press "backspace" to see your last search!'}
	else
		message_element.add{type="label", caption="Try searching for something else!"}
	end
end

return Trades_menu_view