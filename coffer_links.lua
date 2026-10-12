-- Exact case-insensitive name matching scoped to the current numeric zone.
local M = {};
local function phoenix(url)
    local prefix = 'https://wiki.phoenix-xi.com/';
    return type(url) == 'string' and url:sub(1, #prefix) == prefix;
end
function M.build(rows)
    local index = {};
    for _, row in ipairs(rows) do
        assert(type(row.zone_id) == 'number' and row.zone_id > 0);
        assert(phoenix(row.key_url));
        assert(row.coffer_url == nil or phoenix(row.coffer_url));
        assert(index[row.zone_id] == nil, 'Duplicate key zone');
        local zone = { coffer_url = row.coffer_url, monsters = {} };
        index[row.zone_id] = zone;
        for _, mob in ipairs(row.monsters) do
            local match = {key_url = row.key_url, source_name = mob.source_name};
            zone.monsters[mob.name:lower()] = match;
            zone.monsters[mob.source_name:lower()] = match;
        end
    end
    return index;
end
function M.key(index, zone_id, name)
    local zone = index[zone_id];
    return zone and type(name) == 'string' and zone.monsters[name:lower()] or nil;
end
function M.coffer(index, zone_id, name)
    local zone = index[zone_id];
    if (zone and zone.coffer_url and type(name) == 'string' and name:lower() == 'treasure coffer') then
        return zone;
    end
    return nil;
end
return M;
