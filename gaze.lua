addon.name = 'gaze';
addon.author = 'Mr.Bear';
addon.version = '0.1.0';
addon.desc = 'A lightweight targeted-player profile helper for Phoenix XI.';
require 'common';

local bit      = require 'bit';
local chat     = require 'chat';
local imgui    = require 'imgui';
local prims    = require 'primitives';
local settings = require 'settings';

local PROFILE_BASE = 'https://phoenix-xi.com/characters/';
local DEBOUNCE_MS  = 200;
local TEXTURE_SIZE = 128;
local SIZE_PRESETS = T{ 40, 56, 72 };

local STATE_IDLE    = 'idle';
local STATE_PLAYER  = 'player';
local STATE_CLICKED = 'clicked';

local default_settings = T{
    visible      = true,
    x            = 40,
    y            = 40,
    size_index   = 2,
    recent_limit = 5,
    recent_gazed = T{},
};

local gaze = T{
    settings       = settings.load(default_settings),
    eye            = nil,

    state          = STATE_IDLE,
    texture_state  = nil,

    candidate_key  = nil,
    candidate_name = nil,
    candidate_since = 0,

    stable_key     = 'idle',
    stable_name    = nil,

    pending_copy   = nil,

    mouse_down     = false,
    dragging       = false,
    drag_x         = 0,
    drag_y         = 0,
    move_mode      = false,
};

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
};

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

local function get_player_target()
    local entity, index = get_current_target();

    if (entity == nil or entity.Name == nil or entity.Name == '') then
        return nil;
    end

    -- Standard FFXI player-character spawn flag.
    if (bit.band(entity.SpawnFlags or 0, 0x01) ~= 0x01) then
        return nil;
    end

    if (not valid_character_name(entity.Name)) then
        return nil;
    end

    local sid = tonumber(entity.ServerId) or 0;
    local key;

    if (sid ~= 0) then
        key = ('player:%u'):fmt(sid);
    else
        key = ('player:%u:%s'):fmt(index, entity.Name);
    end

    return {
        key  = key,
        name = entity.Name,
    };
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
end

local function update_target_state()
    local now = ashita.time.get_tick64();
    local target = get_player_target();

    local next_key  = target ~= nil and target.key or 'idle';
    local next_name = target ~= nil and target.name or nil;

    if (next_key ~= gaze.candidate_key) then
        gaze.candidate_key   = next_key;
        gaze.candidate_name  = next_name;
        gaze.candidate_since = now;
    end

    if (gaze.stable_key ~= gaze.candidate_key) then
        if ((now - gaze.candidate_since) >= DEBOUNCE_MS) then
            gaze.stable_key  = gaze.candidate_key;
            gaze.stable_name = gaze.candidate_name;

            if (gaze.stable_key == 'idle') then
                set_state(STATE_IDLE);
            elseif (was_recently_gazed(gaze.stable_name)) then
                set_state(STATE_CLICKED);
            else
                set_state(STATE_PLAYER);
            end
        end
    end
end

local function copy_current_profile()
    if (gaze.stable_key == 'idle') then
        return;
    end

    -- Re-read the live target so a delayed visual state can never copy
    -- the wrong player's profile during rapid target changes.
    local live = get_player_target();
    if (live == nil or live.key ~= gaze.stable_key) then
        return;
    end

    gaze.pending_copy = PROFILE_BASE .. live.name;
    add_recent_gazed(live.name);
    set_state(STATE_CLICKED);
end

-- Create one local image primitive. No browser launch, network access,
-- packet manipulation, or gameplay commands are used by this addon.
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

ensure_recent_settings();
trim_recent_list();
set_state(STATE_IDLE);
apply_settings();

settings.register('settings', 'settings_update', function (s)
    if (s ~= nil) then
        gaze.settings = s;
    end

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

    -- Clipboard write happens during the normal render callback rather than
    -- launching or calling any native external process.
    if (gaze.pending_copy ~= nil) then
        imgui.SetClipboardText(gaze.pending_copy);
        gaze.pending_copy = nil;
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
                copy_current_profile();
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
        print(chat.header('Gaze'):append(chat.message('/gaze move - toggle drag mode.')));
        print(chat.header('Gaze'):append(chat.message('/gaze size 1-3 - set eye size.')));
        print(chat.header('Gaze'):append(chat.message('/gaze recent 1-18 - set recent-gazed memory.')));
        print(chat.header('Gaze'):append(chat.message('/gaze reset - reset position and size.')));
        return;
    end
end);

ashita.events.register('unload', 'unload_cb', function ()
    settings.save();

    if (gaze.eye ~= nil) then
        gaze.eye:destroy();
        gaze.eye = nil;
    end
end);
