addon.name = 'gaze';
addon.author = 'Mr.Bear';
addon.version = '0.6.2';
addon.desc = 'Player profiles, NM/PH links, and testimony and AF coffer wiki shortcuts for Phoenix XI.';
require 'common';

local bit      = require 'bit';
local chat     = require 'chat';
local imgui    = require 'imgui';
local prims    = require 'primitives';
local settings = require 'settings';
local nm_names = require 'nms';
local ph_lookup = require 'placeholders';
local manual_ph = require 'manual_ph';
local mob_links = require 'mob_links';
local testimony_data = require 'testimonies';
local testimony_links = require 'testimony_links';
local testimony_index = testimony_links.build(testimony_data);
local coffer_links = require 'coffer_links';
local coffer_index = coffer_links.build(require 'coffers');

local PROFILE_BASE = 'https://phoenix-xi.com/characters/';
local WIKI_BASE    = 'https://wiki.phoenix-xi.com/';
local DEBOUNCE_MS  = 500;
local TEXTURE_SIZE = 128;
local SIZE_PRESETS = T{ 40, 56, 72 };

-- NM lookup is intentionally disabled in Salvage and Nyzul Isle.
local EXCLUDED_NM_ZONES = {
    [73] = true, -- Zhayolm Remnants
    [74] = true, -- Arrapago Remnants
    [75] = true, -- Bhaflau Remnants
    [76] = true, -- Silver Sea Remnants
    [77] = true, -- Nyzul Isle
};

local STATE_IDLE    = 'idle';
local STATE_PLAYER  = 'player';
local STATE_CLICKED = 'clicked';
local STATE_NM      = 'nm';

local default_settings = T{
    mode         = 2,
    visible      = true,
    x            = 40,
    y            = 40,
    size_index   = 2,
    testimonies  = true,
    coffers      = true,
    recent_limit = 5,
    recent_gazed = T{},
};

local gaze = T{
    settings       = settings.load(default_settings),
    eye            = nil,
    badge          = nil,
    stable_secondary_url = nil,
    candidate_secondary_url = nil,
    mouse_badge    = false,

    state          = STATE_IDLE,
    texture_state  = nil,

    candidate_key  = nil,
    candidate_name = nil,
    candidate_kind = nil,
    candidate_job  = nil,
    candidate_since = 0,

    stable_key     = 'idle',
    stable_name    = nil,
    stable_kind    = 'idle',
    stable_job     = nil,

    pending_link   = nil,

    mouse_down     = false,
    dragging       = false,
    drag_x         = 0,
    drag_y         = 0,
    move_mode      = false,
};

-- Hand browser requests to Ashita after the current callback has returned.
-- Do not call ShellExecute through Lua FFI from the render callback.
local function open_browser(url)
    local function report_failure()
        print(chat.header('Gaze'):append(chat.error('Could not open browser.')));
    end
    local ok = pcall(function ()
        ashita.tasks.once(0.1, function ()
            local launched = pcall(ashita.misc.open_url, url);
            if (not launched) then report_failure(); end
        end);
    end);
    if (not ok) then
        report_failure();
        return false;
    end
    -- Ashita's open_url has no return status; true means the request was queued.
    return true;
end

local function ensure_mode_settings()
    if (gaze.settings.mode ~= 1 and gaze.settings.mode ~= 2) then
        gaze.settings.mode = 2;
    end
end

local function ensure_feature_settings()
    if (type(gaze.settings.testimonies) ~= 'boolean') then gaze.settings.testimonies = true; end
    if (type(gaze.settings.coffers) ~= 'boolean') then gaze.settings.coffers = true; end
end

-- Party slot 0 is the local player; compare identity before any player profile action.
local function is_self_target(entity, index)
    if (entity == nil or bit.band(entity.SpawnFlags or 0, 0x01) == 0) then return false; end
    if (type(entity.Name) ~= 'string') then return true; end
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then return true; end -- No local identity: do not open a player link.
    local self_sid = tonumber(party:GetMemberServerId(0)) or 0;
    local self_index = tonumber(party:GetMemberTargetIndex(0)) or 0;
    local self_name = party:GetMemberName(0);
    return (self_sid ~= 0 and self_sid == tonumber(entity.ServerId))
        or (self_index ~= 0 and self_index == index)
        or (self_name ~= nil and self_name ~= ''
            and self_name:lower() == entity.Name:lower());
end

local function get_display_size()
    local index = tonumber(gaze.settings.size_index) or 2;

    if (index < 1) then
        index = 1;
    elseif (index > #SIZE_PRESETS) then
        index = #SIZE_PRESETS;
    end

    gaze.settings.size_index = index;
    return SIZE_PRESETS[index];
end

local function normalize_name(name)
    if (name == nil) then
        return nil;
    end

    return name:lower();
end

local function get_current_zone()
    local party = AshitaCore:GetMemoryManager():GetParty();
    if (party == nil) then
        return 0;
    end

    return tonumber(party:GetMemberZone(0)) or 0;
end

local function ensure_recent_settings()
    local limit = tonumber(gaze.settings.recent_limit) or 5;

    if (limit < 1) then
        limit = 1;
    elseif (limit > 18) then
        limit = 18;
    end

    gaze.settings.recent_limit = math.floor(limit);

    if (gaze.settings.recent_gazed == nil) then
        gaze.settings.recent_gazed = T{};
    end
end

local function trim_recent_list()
    ensure_recent_settings();

    while (#gaze.settings.recent_gazed > gaze.settings.recent_limit) do
        table.remove(gaze.settings.recent_gazed);
    end
end

local function was_recently_gazed(name)
    if (name == nil) then
        return false;
    end

    ensure_recent_settings();

    local wanted = normalize_name(name);

    for _, recent_name in ipairs(gaze.settings.recent_gazed) do
        if (normalize_name(recent_name) == wanted) then
            return true;
        end
    end

    return false;
end

local function add_recent_gazed(name)
    if (name == nil) then
        return;
    end

    ensure_recent_settings();

    local wanted = normalize_name(name);

    for i = #gaze.settings.recent_gazed, 1, -1 do
        if (normalize_name(gaze.settings.recent_gazed[i]) == wanted) then
            table.remove(gaze.settings.recent_gazed, i);
        end
    end

    table.insert(gaze.settings.recent_gazed, 1, name);
    trim_recent_list();
    settings.save();
end

local function asset_path(name)
    return ('%s\\assets\\%s'):fmt(addon.path, name);
end

local textures = {
    [STATE_IDLE]    = asset_path('eye_idle.png'),
    [STATE_PLAYER]  = asset_path('eye_player.png'),
    [STATE_CLICKED] = asset_path('eye_clicked.png'),
    [STATE_NM]      = asset_path('eye_nm.png'),
    key = asset_path('coffer_key.png'),
    coffer = asset_path('coffer.png'),
};

-- Each testimony job keeps a distinct icon before and after clicking.
for _, testimony in ipairs(testimony_data.testimonies) do
    textures['testimony_' .. testimony.job] = asset_path(
        ('testimony_%s.png'):fmt(testimony.job:lower()));
end

local function valid_character_name(name)
    return name ~= nil and name:match('^[A-Za-z]+$') ~= nil;
end

local function get_current_target()
    local target_mgr = AshitaCore:GetMemoryManager():GetTarget();
    if (target_mgr == nil) then
        return nil, 0;
    end

    local index = 0;

    if (target_mgr:GetIsSubTargetActive() == 0) then
        index = target_mgr:GetTargetIndex(0);
    else
        index = target_mgr:GetTargetIndex(1);
    end

    if (index == nil or index == 0) then
        return nil, 0;
    end

    return GetEntity(index), index;
end

local function get_supported_target()
    local entity, index = get_current_target();

    if (entity == nil or entity.Name == nil or entity.Name == '') then
        return nil;
    end

    local flags = entity.SpawnFlags or 0;
    local sid = tonumber(entity.ServerId) or 0;

    -- Player character.
    if (bit.band(flags, 0x01) == 0x01) then
        if (not valid_character_name(entity.Name)) then
            return nil;
        end

        local key;
        if (sid ~= 0) then
            key = ('player:%u'):fmt(sid);
        else
            key = ('player:%u:%s'):fmt(index, entity.Name);
        end

        return {
            kind = is_self_target(entity, index) and 'self' or 'player',
            key  = key,
            name = entity.Name,
        };
    end

    -- NM/PH identification takes priority over testimony drops.
    -- PH matching still requires full ServerId and exact published name.
    if (bit.band(flags, 0x10) == 0x10) then
        local zone = get_current_zone();
        if (zone == 0) then return nil; end
        do
            local slug, kind = mob_links.resolve(entity.Name, sid, nm_names, ph_lookup);
            if (slug ~= nil and (kind == 'ph' or not EXCLUDED_NM_ZONES[zone])) then
                return {
                    kind = kind,
                    key = ('%s:%u:%u:%s:%s'):fmt(kind, zone, sid ~= 0 and sid or index,
                        entity.Name, slug),
                    name = entity.Name,
                    slug = slug,
                };
            end
        end

        local key_drop = coffer_links.key(coffer_index, zone, entity.Name);
        local testimony = gaze.settings.testimonies and (
            testimony_links.resolve(testimony_index, entity.Name) or
            (key_drop and testimony_links.resolve(testimony_index, key_drop.source_name))); 
        if (testimony) then
            return {
                kind = 'testimony',
                key = ('testimony:%u:%u:%s:%s'):fmt(zone, sid ~= 0 and sid or index,
                    entity.Name, testimony.job) .. (gaze.settings.coffers and key_drop and ':key' or ''),
                name = entity.Name,
                job = testimony.job,
                url = testimony.wiki_url,
                secondary_url = gaze.settings.coffers and key_drop and key_drop.key_url or nil,
            };
        end
        if (gaze.settings.coffers and key_drop ~= nil) then
            return { kind = 'key', key = ('key:%u:%u:%s'):fmt(zone,
                sid ~= 0 and sid or index, entity.Name), name = entity.Name, url = key_drop.key_url };
        end
    elseif (gaze.settings.coffers and bit.band(flags, 0x02) == 0x02) then
        local zone = get_current_zone();
        local coffer = coffer_links.coffer(coffer_index, zone, entity.Name);
        if (coffer ~= nil) then
            return { kind = 'coffer', key = ('coffer:%u:%u'):fmt(zone,
                sid ~= 0 and sid or index), name = entity.Name, url = coffer.coffer_url };
        end
    end

    return nil;
end

local function set_state(state)
    if (gaze.state == state and gaze.texture_state == state) then
        return;
    end

    gaze.state = state;

    if (gaze.eye ~= nil and textures[state] ~= nil) then
        gaze.eye.texture = textures[state];
        gaze.texture_state = state;
    end
end

local function apply_settings()
    if (gaze.eye == nil) then
        return;
    end

    local display_size = get_display_size();
    local scale = display_size / TEXTURE_SIZE;

    gaze.eye.position_x = gaze.settings.x;
    gaze.eye.position_y = gaze.settings.y;
    gaze.eye.width      = TEXTURE_SIZE;
    gaze.eye.height     = TEXTURE_SIZE;
    gaze.eye.scale_x    = scale;
    gaze.eye.scale_y    = scale;
    gaze.eye.visible    = gaze.settings.visible;
    if (gaze.badge ~= nil) then
        gaze.badge.position_x = gaze.settings.x + display_size * 0.02;
        gaze.badge.position_y = gaze.settings.y + display_size * 0.60;
        gaze.badge.scale_x = scale * 0.38;
        gaze.badge.scale_y = scale * 0.38;
        gaze.badge.visible = gaze.settings.visible and gaze.stable_secondary_url ~= nil;
    end
end

local function clear_target_state()
    gaze.candidate_key = nil;
    gaze.stable_key = 'idle'; gaze.stable_kind = 'idle';
    gaze.stable_name = nil; gaze.stable_job = nil;
    gaze.stable_secondary_url = nil; gaze.candidate_secondary_url = nil;
    gaze.pending_link = nil; gaze.mouse_down = false;
    set_state(STATE_IDLE); apply_settings();
end

local function update_target_state()
    local entity, index = get_current_target();
    -- Self targets follow the debounce and remain clickable with a closed eye.
    local now = ashita.time.get_tick64();
    local target = get_supported_target();

    local next_key  = target ~= nil and target.key or 'idle';
    local next_name = target ~= nil and target.name or nil;
    local next_kind = target ~= nil and target.kind or 'idle';
    local next_job  = target ~= nil and target.job or nil;

    if (next_key ~= gaze.candidate_key) then
        gaze.candidate_key   = next_key;
        gaze.candidate_name  = next_name;
        gaze.candidate_kind  = next_kind;
        gaze.candidate_job   = next_job;
        gaze.candidate_secondary_url = target and target.secondary_url or nil;
        gaze.candidate_since = now;
    end

    if (gaze.stable_key ~= gaze.candidate_key) then
        if ((now - gaze.candidate_since) >= DEBOUNCE_MS) then
            gaze.stable_key  = gaze.candidate_key;
            gaze.stable_name = gaze.candidate_name;
            gaze.stable_kind = gaze.candidate_kind;
            gaze.stable_job  = gaze.candidate_job;
            gaze.stable_secondary_url = gaze.candidate_secondary_url;
            apply_settings();

            if (gaze.stable_key == 'idle') then
                set_state(STATE_IDLE);
            elseif (gaze.stable_kind == 'nm' or gaze.stable_kind == 'ph') then
                set_state(STATE_NM);
            elseif (gaze.stable_kind == 'testimony') then
                set_state('testimony_' .. gaze.stable_job);
            elseif (gaze.stable_kind == 'key' or gaze.stable_kind == 'coffer') then
                set_state(gaze.stable_kind);
            elseif (gaze.stable_kind == 'self') then
                set_state(STATE_IDLE);
            elseif (was_recently_gazed(gaze.stable_name)) then
                set_state(STATE_CLICKED);
            else
                set_state(STATE_PLAYER);
            end
        end
    end
end

local function activate_current_link(use_badge)
    if (gaze.stable_key == 'idle') then
        return;
    end

    -- Re-read the live target so a delayed visual state can never copy
    -- a link for a target that has already changed.
    local live = get_supported_target();
    if (live == nil or live.key ~= gaze.stable_key or live.kind ~= gaze.stable_kind) then
        return;
    end

    if (use_badge) then
        if (live.secondary_url ~= nil) then
            gaze.pending_link = { url = live.secondary_url, kind = 'key',
                key = live.key, target_kind = live.kind, mode = gaze.settings.mode };
        end
        return;
    end

    if (live.kind == 'player' or live.kind == 'self') then
        gaze.pending_link = { url = PROFILE_BASE .. live.name, name = live.name,
            kind = live.kind, key = live.key, mode = gaze.settings.mode };
        return;
    end

    if (live.kind == 'testimony' or live.kind == 'key' or live.kind == 'coffer') then
        gaze.pending_link = { url = live.url, kind = live.kind,
            key = live.key, mode = gaze.settings.mode };
        return;
    end

    if (live.kind == 'nm' or live.kind == 'ph') then
        gaze.pending_link = { url = WIKI_BASE .. live.slug, kind = live.kind,
            key = live.key, mode = gaze.settings.mode };

        -- NMs and their PHs share the fourth eye before and after clicking.
        set_state(STATE_NM);
    end
end

-- Create one local image primitive. Browser launching requires a deliberate click in mode 2.
gaze.eye = prims.new({
    visible       = gaze.settings.visible,
    position_x    = gaze.settings.x,
    position_y    = gaze.settings.y,
    can_focus     = false,
    locked        = true,
    lockedz       = false,
    scale_x       = get_display_size() / TEXTURE_SIZE,
    scale_y       = get_display_size() / TEXTURE_SIZE,
    width         = TEXTURE_SIZE,
    height        = TEXTURE_SIZE,
    color         = 0xFFFFFFFF,
});

gaze.badge = prims.new({visible = false, position_x = 0, position_y = 0,
    can_focus = false, locked = true, lockedz = false, width = TEXTURE_SIZE,
    height = TEXTURE_SIZE, color = 0xFFFFFFFF, texture = asset_path('key_badge.png')});
ensure_feature_settings();
ensure_mode_settings();
ensure_recent_settings();
trim_recent_list();
set_state(STATE_IDLE);
apply_settings();

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        gaze.settings = s;
    end

    ensure_feature_settings();
    clear_target_state();
    ensure_mode_settings();
    ensure_recent_settings();
    trim_recent_list();
    apply_settings();
    settings.save();
end);

ashita.events.register('d3d_present', 'present_cb', function ()
    if (not gaze.settings.visible) then
        return;
    end

    update_target_state();

    -- Consume each deliberate click once, using the mode selected at click time.
    if (gaze.pending_link ~= nil) then
        local pending = gaze.pending_link;
        gaze.pending_link = nil;
        local live = get_supported_target();
        if (live == nil or live.key ~= pending.key or
            live.kind ~= (pending.target_kind or pending.kind)) then return; end
        local success = true;
        if (pending.mode == 2) then
            success = open_browser(pending.url);
        else
            imgui.SetClipboardText(pending.url);
        end
        if (success and pending.kind == 'player') then
            add_recent_gazed(pending.name);
            if (gaze.stable_key == pending.key) then
                set_state(STATE_CLICKED);
            end
        end
    end
end);

local function hit_test(x, y)
    local display_size = get_display_size();
    local left   = gaze.settings.x;
    local top    = gaze.settings.y;
    local right  = left + display_size;
    local bottom = top + display_size;

    return x >= left and x <= right
       and y >= top  and y <= bottom;
end

ashita.events.register('mouse', 'mouse_cb', function (e)
    if (not gaze.settings.visible or gaze.eye == nil) then
        return;
    end

    local hit = hit_test(e.x, e.y);

    -- Mouse move.
    if (e.message == 0x200) then
        if (gaze.dragging) then
            gaze.settings.x = e.x - gaze.drag_x;
            gaze.settings.y = e.y - gaze.drag_y;
            apply_settings();
            e.blocked = true;
        end
        return;
    end

    -- Left button down.
    if (e.message == 0x201) then
        if (not hit) then
            return;
        end

        e.blocked = true;

        if (gaze.move_mode) then
            gaze.dragging = true;
            gaze.drag_x = e.x - gaze.settings.x;
            gaze.drag_y = e.y - gaze.settings.y;
        else
            local size = get_display_size();
            gaze.mouse_badge = gaze.stable_secondary_url ~= nil
                and e.x >= gaze.settings.x + size * 0.02
                and e.x <= gaze.settings.x + size * 0.40
                and e.y >= gaze.settings.y + size * 0.60
                and e.y <= gaze.settings.y + size * 0.98;
            gaze.mouse_down = true;
        end

        return;
    end

    -- Left button up.
    if (e.message == 0x202) then
        if (gaze.dragging) then
            gaze.dragging = false;
            e.blocked = true;
            settings.save();
            return;
        end

        if (gaze.mouse_down) then
            gaze.mouse_down = false;
            e.blocked = true;

            if (hit) then
                local size = get_display_size();
                local badge_hit = gaze.stable_secondary_url ~= nil
                    and e.x >= gaze.settings.x + size * 0.02
                    and e.x <= gaze.settings.x + size * 0.40
                    and e.y >= gaze.settings.y + size * 0.60
                    and e.y <= gaze.settings.y + size * 0.98;
                if (badge_hit == gaze.mouse_badge) then activate_current_link(badge_hit); end
            end
        end
    end
end);

ashita.events.register('command', 'command_cb', function (e)
    local args = e.command:args();

    if (#args == 0 or args[1]:lower() ~= '/gaze') then
        return;
    end

    e.blocked = true;

    -- /gaze
    if (#args == 1) then
        gaze.settings.visible = not gaze.settings.visible;
        apply_settings();
        settings.save();

        print(chat.header('Gaze')
            :append(chat.message('Button: '))
            :append(chat.success(gaze.settings.visible and 'Shown' or 'Hidden')));
        return;
    end

    local sub = args[2]:lower();

    -- Explicit @ commands always open a browser, regardless of eye click mode.
    if (args[2]:sub(1,1) == '@') then
        local name=args[2]:sub(2);
        local function report(text) print(chat.header('Gaze'):append(chat.message(text))); end
        if #args ~= 2 then report('Use /gaze @PlayerName, /gaze @<t>, or /gaze @.');return;end
        if name == '' or name:lower() == '<t>' then
            local entity,index=get_current_target();
            if not entity or bit.band(tonumber(entity.SpawnFlags) or 0,0x01) ~= 0x01 then
                report('Target a player to open their profile.');return;
            end
            if is_self_target(entity,index) then report('Gaze ignores your own player.');return;end
            name=entity.Name;
        end
        if not valid_character_name(name) then report('Enter a valid player name.');return;end
        local party=AshitaCore:GetMemoryManager():GetParty();
        local own=party and party:GetMemberName(0);
        if own and own:lower() == name:lower() then report('Gaze ignores your own player.');return;end
        if open_browser(PROFILE_BASE..name) then add_recent_gazed(name);update_target_state();end
        return;
    end

    if (sub == 'ph') then
        local tokens,parse_err=manual_ph.args(e.command);
        local function report(text) print(chat.header('Gaze'):append(chat.message(text))); end
        if not tokens then report(parse_err);return;end
        local action=tokens[3] and tokens[3]:lower();
        local path=addon.path..'/placeholders.lua';
        local entries,load_err=manual_ph.load(path);
        if not entries then report('Manual PH read failed: '..tostring(load_err));return;end
        if action == 'list' and #tokens == 3 then
            local ids={};for id in pairs(entries) do ids[#ids+1]=id;end;table.sort(ids);
            if #ids == 0 then report('No manual placeholders saved.');end
            for _,id in ipairs(ids) do local row=entries[id];report(('%u: %s -> %s'):format(id,row.placeholder_name,row.nm_slug));end
            return;
        end
        local entity=get_current_target();
        if entity and bit.band(tonumber(entity.SpawnFlags) or 0,0x10) ~= 0x10 then entity=nil;end
        local id,err;
        if action == 'add' and #tokens == 6 then
            id,err=manual_ph.resolve_id(tokens[6],entity,tokens[5]);
            if not id then report(err);return;end
            local row;row,err=manual_ph.row(tokens[4],tokens[5],id);
            if not row then report(err);return;end
            entries[id]=row;
        elseif action == 'remove' and #tokens == 4 then
            id,err=manual_ph.resolve_id(tokens[4],entity,entity and entity.Name);
            if not id then report(err);return;end
            if not entries[id] then report('That ID is not a manual entry.');return;end
            entries[id]=nil;
        else
            report('Use /gaze ph add "NM Name" "PH Name" ID, /gaze ph remove ID, or /gaze ph list.');return;
        end
        local saved,backup,lookup=manual_ph.save(path,entries);
        if not saved then report('Manual PH save failed: '..tostring(backup));return;end
        for key in pairs(ph_lookup) do ph_lookup[key]=nil;end
        for key,row in pairs(lookup) do ph_lookup[key]=row;end
        clear_target_state();update_target_state();
        report(('Manual PH %u %s. Backup: %s'):format(id,action == 'add' and 'saved' or 'removed',backup));
        return;
    end

    -- Persist independent feature switches; old settings default to enabled.
    if (sub == 'testimonies' or sub == 'coffers') then
        if (#args > 3 or (#args == 3 and args[3]:lower() ~= 'on' and args[3]:lower() ~= 'off')) then
            print(chat.header('Gaze'):append(chat.error('Use /gaze ' .. sub .. ' on or off.')));
            return;
        end
        if (#args == 3) then
            gaze.settings[sub] = args[3]:lower() == 'on';
            clear_target_state(); settings.save(); update_target_state();
        end
        print(chat.header('Gaze'):append(chat.message(sub .. ': ' ..
            (gaze.settings[sub] and 'Enabled' or 'Disabled'))));
        return;
    end

    -- /gaze mode [1|2]
    if (sub == 'mode') then
        if (#args > 3 or (#args == 3 and args[3] ~= '1' and args[3] ~= '2')) then
            print(chat.header('Gaze'):append(chat.error('Use /gaze mode 1 or /gaze mode 2.')));
            return;
        end
        if (#args == 3) then
            gaze.settings.mode = tonumber(args[3]);
            settings.save();
        end
        ensure_mode_settings();
        print(chat.header('Gaze'):append(chat.message(('Mode %d: %s'):fmt(
            gaze.settings.mode, gaze.settings.mode == 2 and 'Open browser' or 'Copy to clipboard'))));
        return;
    end

    -- /gaze move
    if (sub == 'move') then
        gaze.move_mode = not gaze.move_mode;

        print(chat.header('Gaze')
            :append(chat.message('Move mode: '))
            :append(chat.success(gaze.move_mode and 'Enabled' or 'Disabled')));

        if (gaze.move_mode) then
            print(chat.header('Gaze')
                :append(chat.message('Drag the eye with the left mouse button, then use /gaze move again.')));
        end
        return;
    end

    -- /gaze size 1-3
    if (sub == 'size') then
        if (#args < 3) then
            print(chat.header('Gaze')
                :append(chat.message(('Current size: preset %d (%d px)'):fmt(
                    gaze.settings.size_index,
                    get_display_size()
                ))));
            print(chat.header('Gaze')
                :append(chat.message('Use /gaze size 1 through /gaze size 3.')));
            return;
        end

        local index = tonumber(args[3]);

        if (index == nil or index < 1 or index > 3 or index ~= math.floor(index)) then
            print(chat.header('Gaze')
                :append(chat.error('Size must be a whole number from 1 to 3.')));
            return;
        end

        gaze.settings.size_index = index;
        apply_settings();
        settings.save();

        print(chat.header('Gaze')
            :append(chat.message(('Size preset %d: %d px'):fmt(
                index,
                get_display_size()
            ))));
        return;
    end

    -- /gaze clear
    if (sub == 'clear') then
        gaze.settings.recent_gazed = T{};
        settings.save();
        if (gaze.stable_kind == 'player' and gaze.stable_key ~= 'idle') then
            set_state(STATE_PLAYER);
        end
        print(chat.header('Gaze'):append(chat.message('Recent-player history cleared.')));
        return;
    end

    -- /gaze recent 1-18
    if (sub == 'recent') then
        if (#args < 3) then
            ensure_recent_settings();

            print(chat.header('Gaze')
                :append(chat.message(('Recent-gazed limit: %d'):fmt(
                    gaze.settings.recent_limit
                ))));
            return;
        end

        local limit = tonumber(args[3]);

        if (limit == nil or limit < 1 or limit > 18 or limit ~= math.floor(limit)) then
            print(chat.header('Gaze')
                :append(chat.error('Recent limit must be a whole number from 1 to 18.')));
            return;
        end

        gaze.settings.recent_limit = limit;
        trim_recent_list();
        settings.save();

        print(chat.header('Gaze')
            :append(chat.message(('Recent-gazed limit set to %d.'):fmt(limit))));
        return;
    end

    -- /gaze reset
    if (sub == 'reset') then
        gaze.settings.x = default_settings.x;
        gaze.settings.y = default_settings.y;
        gaze.settings.visible = true;
        gaze.settings.size_index = default_settings.size_index;
        gaze.move_mode = false;
        apply_settings();
        settings.save();

        print(chat.header('Gaze'):append(chat.message('Position reset.')));
        return;
    end

    -- /gaze help
    if (sub == 'help') then
        print(chat.header('Gaze'):append(chat.message('/gaze - show or hide the eye.')));
        print(chat.header('Gaze'):append(chat.message('/gaze mode 1|2 - clipboard or browser (default).')));
        print(chat.header('Gaze'):append(chat.message('/gaze @PlayerName | @<t> | @ - open a player profile.')));
        print(chat.header('Gaze'):append(chat.message('/gaze testimonies on|off - toggle testimony links.')));
        print(chat.header('Gaze'):append(chat.message('/gaze coffers on|off - toggle AF keys and coffers.')));
        print(chat.header('Gaze'):append(chat.message('/gaze ph add "NM Name" "PH Name" ID | ph remove ID | ph list.')));
        print(chat.header('Gaze'):append(chat.message('/gaze move - toggle drag mode.')));
        print(chat.header('Gaze'):append(chat.message('/gaze size 1-3 - set eye size.')));
        print(chat.header('Gaze'):append(chat.message('/gaze recent 1-18 - set recent-gazed memory.')));
        print(chat.header('Gaze'):append(chat.message('/gaze clear - clear recent-player history.')));
        print(chat.header('Gaze'):append(chat.message('/gaze reset - reset position and size.')));
        return;
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    settings.save();
    if (gaze.badge ~= nil) then gaze.badge:destroy(); gaze.badge = nil; end

    if (gaze.eye ~= nil) then
        gaze.eye:destroy();
        gaze.eye = nil;
    end
end);

