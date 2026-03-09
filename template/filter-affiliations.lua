-- filter-affiliations.lua
-- filters, orders, AND renumbers affiliations (1, 2, 3, ...)
-- based on the sequence they appear in the author list

-- Helper function for deep copying tables/objects
local function deep_copy(obj)
	if type(obj) ~= "table" then
		return obj
	end
	local new_table = {}
	for key, value in pairs(obj) do
		new_table[key] = deep_copy(value)
	end
	return new_table
end

function Meta(meta)
	-- 1. Scan Authors to Collect Affiliation IDs in Order and map old IDs to new ones

	local id_renumbering_map = {}
	local new_affiliations_data = {}
	local original_aff_map = {}
	local next_new_id = 1

	-- Pre-map original affiliations for quick lookup
	if meta.affiliations then
		for _, aff in ipairs(meta.affiliations) do
			-- We must use pandoc.utils.stringify to ensure 'id' is treated as a string key
			local original_id = pandoc.utils.stringify(aff.id)
			original_aff_map[original_id] = aff
		end
	end

	-- Process authors to build the renumbering map and the new affiliations list
	if meta.author then
		for _, author in ipairs(meta.author) do
			local current_author_aff_ids = {} -- Collects new IDs for the current author

			if author.affiliation then
				-- Split the affiliation string (e.g., "2,3") by comma and trim whitespace
				for aff_id in string.gmatch(pandoc.utils.stringify(author.affiliation), "([^,]+)") do
					local original_id = aff_id:match("^%s*(.-)%s*$") -- Trim whitespace

					if original_id ~= "" then
						-- Check if this original ID has been encountered before
						if not id_renumbering_map[original_id] then
							-- First encounter: Assign a new sequential ID
							local new_id_str = tostring(next_new_id)
							id_renumbering_map[original_id] = new_id_str

							-- Create the new affiliation object with the new ID
							local original_aff = original_aff_map[original_id]
							if original_aff then
								-- FIX: Use the robust custom deep_copy function
								local new_aff = deep_copy(original_aff)

								-- Ensure we are setting the ID correctly as a Pandoc string type (Str)
								new_aff.id = pandoc.Str(new_id_str)
								new_affiliations_data[new_id_str] = new_aff

								next_new_id = next_new_id + 1
							end
						end

						-- Get the new ID for the current author
						table.insert(current_author_aff_ids, id_renumbering_map[original_id])
					end
				end

				-- Update the author's affiliation field with the new, renumbered string (e.g., "1,2")
				author.affiliation = pandoc.Str(table.concat(current_author_aff_ids, ","))
			end
		end
	end

	-- 2. Update the Affiliations List in the Metadata

	-- Convert the table keyed by new ID (1, 2, 3...) into a sequential list
	local final_affiliations_list = {}
	for i = 1, next_new_id - 1 do
		table.insert(final_affiliations_list, new_affiliations_data[tostring(i)])
	end

	meta.affiliations = final_affiliations_list

	return meta
end
