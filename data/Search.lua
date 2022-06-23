local Search = {

}

-- create a new search table
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

-- checks if a search object has the same contents as itself.
function Search:compare(search)
	for key, value in pairs(search) do
		if self[key] ~= value then
			return false
		end
	end
	return true
end

return Search