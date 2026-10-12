-- Exact case-insensitive mob names from confirmed Phoenix Wiki drop tables.
-- Steal-only sources are retained in testimonies.lua but are not drop matches.
local M = {};

function M.build(data)
    local index = {};
    for _, testimony in ipairs(data.testimonies) do
        assert(type(testimony.job) == 'string', 'Missing testimony job');
        assert(type(testimony.wiki_url) == 'string'
            and testimony.wiki_url:match('^https://wiki%.phoenix%-xi%.com/'),
            'Testimony links must use the Phoenix Wiki');
        for _, drop in ipairs(testimony.drops or {}) do
            local name = drop.monster:lower();
            local previous = index[name];
            assert(previous == nil or previous.job == testimony.job,
                'Multiple testimony jobs for mob: ' .. name);
            index[name] = { job = testimony.job, wiki_url = testimony.wiki_url,
                item_id = testimony.item_id };
        end
    end
    return index;
end

function M.resolve(index, name)
    if (type(name) ~= 'string' or name == '') then return nil; end
    return index[name:lower()];
end

return M;
