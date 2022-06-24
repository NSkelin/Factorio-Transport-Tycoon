---@class Search
---@field item_name string
---@field product_name string
---@field ingredient_name string
local Search = {

}

---Create a new search table
---@param object table
---@return table
function Search:new(object)
	item_type = item_type or self.item_type
	search = {}
	search.item_name = object.item_name
	search.product_name = object.product_name
	search.ingredient_name = object.ingredient_name

	if object.item_name == nil and object.product_name == nil and object.ingredient_name == nil then
		search.item_name = ""
	end
	setmetatable(search, self)
	self.__index = self

	return search
end

---Checks if a search object has the same contents as itself.
---@param search Search
---@return boolean
function Search:compare(search)
	for key, value in pairs(search) do
		if self[key] ~= value then
			return false
		end
	end
	return true
end

return Search