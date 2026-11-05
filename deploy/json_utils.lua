-- Fonction pour encoder une table en JSON
local function to_json(obj)
    local function escape(str)
        return (str:gsub("\\", "\\\\"):gsub('"', '\\"'))
    end
    
    if type(obj) == "string" then
        return '"' .. escape(obj) .. '"'
    elseif type(obj) == "number" then
        return tostring(obj)
    elseif type(obj) == "boolean" then
        return obj and "true" or "false"
    elseif type(obj) == "nil" then
        return "null"
    elseif type(obj) == "table" then
        local parts = {}
        local is_array = true
        for k, v in pairs(obj) do
            if type(k) ~= "number" or k < 1 or math.floor(k) ~= k then
                is_array = false
                break
            end
        end
        
        if is_array then
            parts[1] = "["
            for i, v in ipairs(obj) do
                parts[#parts + 1] = (i > 1 and ", " or "") .. to_json(v)
            end
            parts[#parts + 1] = "]"
        else
            parts[1] = "{"
            local first = true
            for k, v in pairs(obj) do
                parts[#parts + 1] = (first and "" or ", ") .. '"' .. escape(k) .. '": ' .. to_json(v)
                first = false
            end
            parts[#parts + 1] = "}"
        end
        return table.concat(parts)
    else
        return "null"
    end
end

return to_json
