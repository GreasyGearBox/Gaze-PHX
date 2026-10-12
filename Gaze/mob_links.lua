-- Pure local resolution. No name corrections, web requests, or inferred IDs.
local M = {};
function M.resolve(name, server_id, nms, placeholders)
    if (type(name) ~= 'string' or name == '') then return nil; end
    local normalized = name:lower();
    local entry = placeholders[server_id];
    if (entry ~= nil) then
        if (type(entry.placeholder_name) == 'string'
            and normalized == entry.placeholder_name:lower()) then
            return entry.nm_slug, 'ph';
        end
        -- Known PH ID with a different name remains unsupported.
        return nil;
    end
    if (normalized == 'mimic' or normalized == 'chigoe'
        or normalized:match(' elemental$')
        or normalized:match('^hobgoblin ')
        or normalized:match('^halforc ')
        or normalized:match('^theoyagudo ')
        or normalized:match('^metaquadav ')) then return nil; end
    local slug = nms[normalized];
    if (slug ~= nil) then return slug, 'nm'; end
    return nil;
end
return M;
