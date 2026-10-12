-- Manual PH editing stays within this addon's placeholders.lua.
-- Validate before writing, keep a backup, and install the new file with rollback.
local M = {};
local BEGIN = '    -- BEGIN MANUAL PH ENTRIES';
local END = '    -- END MANUAL PH ENTRIES';
local MAX_ID = 4294967295;
local function valid_id(id)
    return type(id) == 'number' and id >= 4096 and id <= MAX_ID and id == math.floor(id);
end
local function valid_text(s)
    return type(s) == 'string' and #s > 0 and #s <= 128 and not s:find('[%c]');
end
local function read(path)
    local f, err = io.open(path, 'rb');
    if (not f) then return nil, err; end
    local text = f:read('*a'); f:close(); return text;
end
local function block_bounds(text)
    local first, last = text:find(BEGIN, 1, true);
    local stop = last and text:find(END, last + 1, true);
    if (not first or not stop or text:find(BEGIN, last + 1, true)
        or text:find(END, stop + #END, true)) then return nil; end
    return last + 1, stop - 1;
end
function M.load(path)
    local text, err = read(path);
    if (not text) then return nil, err; end
    local a,b = block_bounds(text);
    if (not a) then return nil, 'Manual PH markers are missing or duplicated.'; end
    local chunk, parse_err = loadstring('return {' .. text:sub(a,b) .. '}');
    if (not chunk) then return nil, parse_err; end
    setfenv(chunk, {});
    local ok, entries = pcall(chunk);
    if (not ok or type(entries) ~= 'table') then return nil, 'Invalid manual PH section.'; end
    for id,row in pairs(entries) do
        if (not valid_id(id) or type(row) ~= 'table' or not valid_text(row.placeholder_name)
            or not valid_text(row.nm_slug) or row.manual ~= true) then
            return nil, 'Invalid manual PH entry.';
        end
    end
    return entries;
end
function M.nm_slug(text)
    if (not valid_text(text)) then return nil, 'Enter an NM name or Phoenix wiki page slug.'; end
    local slug = text:match('^https://wiki%.phoenix%-xi%.com/(.+)$') or text;
    if (slug:find('://',1,true) or slug:find('[?#]') or slug:find('[/\\]')
        or slug:find('^%s') or slug:find('%s$')) then return nil, 'Use an NM name, slug, or Phoenix wiki page URL.'; end
    -- Encode the title rather than allowing user text to change URL structure.
    slug = slug:gsub(' ', '_');
    slug = slug:gsub('([^%w_%-%.~%%])', function(c) return ('%%%02X'):format(c:byte()); end);
    local rest = slug:gsub('%%%x%x', '');
    if (rest:find('%',1,true)) then return nil, 'Invalid URL escape.'; end
    return slug;
end
function M.resolve_id(token, entity, target_name)
    if (type(token) ~= 'string') then return nil, 'Enter a full server ID or a three-digit hex PH ID.'; end
    local short = token:match('^%x%x%x$') or token:match('^0[xX](%x%x%x)$');
    if (short) then
        if (not entity or type(entity.Name) ~= 'string' or
            not valid_text(target_name) or entity.Name:lower() ~= target_name:lower()) then
            return nil, 'Target the named PH before using a three-digit hex ID.';
        end
        local sid = tonumber(entity.ServerId);
        if (not valid_id(sid) or sid % 4096 ~= tonumber(short,16)) then
            return nil, 'The short hex ID does not match the targeted mob full server ID.';
        end
        return sid;
    end
    local id;
    if (token:match('^%d+$')) then id = tonumber(token);
    elseif (token:match('^0[xX]%x+$')) then id = tonumber(token:sub(3),16); end
    if (not valid_id(id)) then return nil, 'Use a full decimal server ID, full 0x hex ID, or three-digit hex ID.'; end
    return id;
end
function M.row(nm, name, id)
    local slug,err = M.nm_slug(nm);
    if (not slug) then return nil,err; end
    if (not valid_text(name) or name:find('^%s') or name:find('%s$')) then return nil,'Enter the exact PH target name.'; end
    if (not valid_id(id)) then return nil,'Invalid full server ID.'; end
    return {placeholder_name=name,nm_slug=slug,manual=true,added_on=os.date('!%Y-%m-%dT%H:%M:%SZ')};
end
function M.save(path, entries)
    local old,err = read(path);
    if (not old) then return false,err; end
    local a,b = block_bounds(old);
    if (not a) then return false,'Manual PH markers are missing or duplicated.'; end
    local ids = {};
    for id,row in pairs(entries) do
        if (not valid_id(id) or type(row) ~= 'table' or not valid_text(row.placeholder_name)
            or not valid_text(row.nm_slug) or row.manual ~= true or not valid_text(row.added_on)) then
            return false,'Invalid manual PH entry; no changes saved.';
        end
        ids[#ids+1]=id;
    end
    table.sort(ids);
    local lines = {'\n'};
    for _,id in ipairs(ids) do
        local row=entries[id];
        lines[#lines+1]=('    [%u] = { placeholder_name = %q, nm_slug = %q, manual = true, added_on = %q },\n')
            :format(id,row.placeholder_name,row.nm_slug,row.added_on);
    end
    local updated = old:sub(1,a-1) .. table.concat(lines) .. old:sub(b+1);
    local syntax,syntax_err = loadstring(updated);
    if (not syntax) then return false,syntax_err; end
    setfenv(syntax, {pairs=pairs});
    local compiled, lookup = pcall(syntax);
    if (not compiled or type(lookup) ~= 'table') then return false,'Invalid placeholder file.'; end
    local temporary = path .. '.manual.tmp';
    local f,open_err=io.open(temporary,'wb');
    if (not f) then return false,open_err; end
    local written,write_err=f:write(updated);local closed,close_err=f:close();
    if (not written or not closed) then os.remove(temporary);return false,write_err or close_err; end
    -- A unique backup avoids deleting earlier backups when editing repeatedly.
    local backup=path .. '.before-manual-' .. os.date('!%Y%m%d-%H%M%S');
    local suffix=0;
    local function exists(name) local probe=io.open(name,'rb');if probe then probe:close();return true;end return false;end
    while exists(backup) do
        suffix=suffix+1;backup=path..'.before-manual-'..os.date('!%Y%m%d-%H%M%S')..'-'..suffix;
    end
    local moved,move_err=os.rename(path,backup);
    if (not moved) then os.remove(temporary);return false,move_err; end
    local installed,install_err=os.rename(temporary,path);
    if (not installed) then
        local restored,restore_err=os.rename(backup,path);
        os.remove(temporary);
        return false,restored and install_err or ('Install and rollback failed; original is at '..backup..': '..tostring(restore_err));
    end
    return true,backup,lookup;
end
function M.args(text)
    local result, pos = {}, 1;
    while pos <= #text do
        while text:sub(pos,pos):match('%s') do pos=pos+1; end
        if pos > #text then break; end
        local quote=text:sub(pos,pos);
        if quote == '"' then
            local stop=text:find('"',pos+1,true);
            if not stop then return nil,'Unclosed quote.'; end
            result[#result+1]=text:sub(pos+1,stop-1);pos=stop+1;
            if pos <= #text and not text:sub(pos,pos):match('%s') then return nil,'Separate arguments with spaces.'; end
        else
            local stop=text:find('%s',pos) or (#text+1);
            result[#result+1]=text:sub(pos,stop-1);pos=stop;
        end
    end
    return result;
end
return M;
