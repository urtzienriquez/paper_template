-- fix-titleblock.lua
-- Reorder title, abstract, and keywords before Introduction; remove originals.

local utils = require("pandoc.utils")

local PAPER_TITLE = "Niche evolution in lineages of the alpine newt" -- adjust as needed
local FALLBACK_PHRASE = "Corresponding author"
local TITLE_MACRO_PATTERN = "\\%w+titleblock" -- matches \mytitleblock etc.

-- --- helpers -----------------------------------------------------------

local function text_of(x)
	return utils.stringify(x or "")
end

local function contains_title_macro(block)
	if not block then
		return false
	end
	if block.t == "RawBlock" and (block.format == "latex" or block.format == "tex") then
		if block.text:match(TITLE_MACRO_PATTERN) then
			return true
		end
	end
	if (block.t == "Para" or block.t == "Plain") and block.content then
		for _, inl in ipairs(block.content) do
			if inl.t == "RawInline" and (inl.format == "latex" or inl.format == "tex") then
				if inl.text:match(TITLE_MACRO_PATTERN) then
					return true
				end
			end
			if inl.t == "Str" and inl.text:match(TITLE_MACRO_PATTERN) then
				return true
			end
		end
	end
	return false
end

local function contains_title_text(block)
	local txt = text_of(block):lower()
	if PAPER_TITLE ~= "" and txt:find(PAPER_TITLE:lower(), 1, true) then
		return true
	end
	if txt:find(FALLBACK_PHRASE:lower(), 1, true) then
		return true
	end
	return false
end

local function is_introduction_header(block)
	if block.t == "Header" then
		local htxt = text_of(block)
		if htxt and htxt:match("^%s*[Ii]ntroduction%s*$") then
			return true
		end
	end
	return false
end

local function expand_title_run(blocks, i)
	local n = #blocks
	local s, e = i, i
	while s > 1 do
		local prev = blocks[s - 1]
		local len = (#text_of(prev))
		if prev.t == "RawBlock" or len < 200 then
			s = s - 1
		else
			break
		end
	end
	while e < n do
		local nxt = blocks[e + 1]
		local len = (#text_of(nxt))
		if nxt.t == "RawBlock" or (len < 400 and not is_introduction_header(nxt)) then
			e = e + 1
		else
			break
		end
	end
	return s, e
end

local function is_keywords_para(block)
	if block.t == "Para" or block.t == "Plain" then
		local txt = text_of(block):lower()
		if txt:match("^%s*keywords%s*:") or txt:match("^%*%*keywords") then
			return true
		end
	end
	return false
end

-- --- main logic --------------------------------------------------------

function Pandoc(doc)
	local blocks = doc.blocks
	local n = #blocks

	-- find Introduction
	local intro_idx
	for i = 1, n do
		if is_introduction_header(blocks[i]) then
			intro_idx = i
			break
		end
	end
	if not intro_idx then
		return doc
	end

	-- find title run
	local title_run_start, title_run_end
	for i = 1, n do
		if contains_title_macro(blocks[i]) or contains_title_text(blocks[i]) then
			title_run_start, title_run_end = expand_title_run(blocks, i)
			break
		end
	end

	-- find keywords
	local keywords_idx
	for i = 1, n do
		if is_keywords_para(blocks[i]) then
			keywords_idx = i
			break
		end
	end

	-- build abstract
	local abs_blocks = {}
	if doc.meta and doc.meta.abstract then
		local abs_txt = text_of(doc.meta.abstract)
		if abs_txt and abs_txt:match("%S") then
			table.insert(abs_blocks, pandoc.Para({ pandoc.Strong({ pandoc.Str("Abstract:") }) }))
			table.insert(abs_blocks, pandoc.Para({ pandoc.Str(abs_txt) }))
		end
		doc.meta.abstract = nil
	end

	-- extract title run
	local title_run_blocks = {}
	if title_run_start then
		for k = title_run_start, title_run_end - 1 do -- -1 to remove keywords line
			table.insert(title_run_blocks, blocks[k])
		end
	end

	-- extract keywords block
	local keywords_block
	if keywords_idx then
		keywords_block = blocks[keywords_idx]
	end

	-- rebuild
	local newblocks = {}
	for i = 1, n do
		if i == intro_idx then
			for _, b in ipairs(title_run_blocks) do
				table.insert(newblocks, b)
			end
			for _, b in ipairs(abs_blocks) do
				table.insert(newblocks, b)
			end
			if keywords_block then
				table.insert(newblocks, keywords_block)
			end
			table.insert(newblocks, blocks[i])
		elseif
			not (
				(title_run_start and i >= title_run_start and i <= title_run_end)
				or (keywords_idx and i == keywords_idx)
			)
		then
			table.insert(newblocks, blocks[i])
		end
	end

	doc.blocks = newblocks
	return doc
end
