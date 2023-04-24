-- If LuaRocks is installed, make sure that packages installed through it are
-- found (e.g. lgi). If LuaRocks is not installed, do nothing.
pcall(require, "luarocks.loader")

-- Standard awesome library
local gears = require("gears")
local awful = require("awful")
require("awful.autofocus")
-- Widget and layout library
local wibox = require("wibox")
-- Theme handling library
local beautiful = require("beautiful")
-- Notification library
local naughty = require("naughty")
local menubar = require("menubar")
local hotkeys_popup = require("awful.hotkeys_popup")
-- Enable hotkeys help widget for VIM and other apps
-- when client with a matching name is opened:
require("awful.hotkeys_popup.keys")
require("io")

-- Error handling
-- Check if awesome encountered an error during startup and fell back to
-- another config (This code will only ever execute for the fallback config)
if awesome.startup_errors then
    naughty.notify({ preset = naughty.config.presets.critical,
    title = "Oops, there were errors during startup!",
    text = awesome.startup_errors })
end

-- Handle runtime errors after startup
do
    local in_error = false
    awesome.connect_signal("debug::error", function (err)
        -- Make sure we don't go into an endless error loop
        if in_error then return end
        in_error = true

        naughty.notify({ preset = naughty.config.presets.critical,
        title = "Oops, an error happened!",
        text = tostring(err) })
        in_error = false
    end)
end
-- End Error handling

-- Utils Functions
local function create_keys_for_tags(key, tag_name)
    local tag = awful.tag.find_by_name(awful.screen.focused(), tag_name)
    return gears.table.join(
        -- View tag only.
        awful.key( { Modkey }, key,
        function ()
            if tag then
                tag:view_only()
            end
        end,
        {description = "View tag " .. key, group = "tag"}),
        -- Toggle tag display.
        awful.key({ Modkey, "Control" }, key,
        function ()
            if tag then
                awful.tag.viewtoggle(tag)
            end
        end,
        {description = "toggle tag " .. key, group = "tag"}),
        -- Move client to tag.
        awful.key({ Modkey, "Shift" }, key,
        function ()
            if client.focus then
                if tag then
                    client.focus:move_to_tag(tag)
                end
            end
        end,
        {description = "move focused client to tag "..key, group = "tag"}),
        -- Toggle tag on focused client.
        awful.key({ Modkey, "Control", "Shift" }, key,
        function ()
            if client.focus then
                if tag then
                    client.focus:toggle_tag(tag)
                end
            end
        end,
        {description = "toggle focused client on tag " .. key, group = "tag"})
    )
end

local create_tags = function (tag_name, s)
    local t = awful.tag.add(tag_name, {
        screen = s,
        layout = awful.layout.layouts[1]
    })
    return t
end

-- theme or wallpaper

beautiful.init("/home/lucas/.config/awesome/zenburn/theme.lua")

local function set_wallpaper(s)
    -- Wallpaper
    if beautiful.wallpaper then
        local wallpaper = beautiful.wallpaper
        -- If wallpaper is a function, call it with the screen
        if type(wallpaper) == "function" then
            wallpaper = wallpaper(s)
        end
        gears.wallpaper.maximized(wallpaper, s, true)
    end
end

-- Defaults Values

Terminal = "alacritty"
Editor = os.getenv("EDITOR") or "vim"
Editor_cmd = Terminal .. " -e " .. Editor
Modkey = "Mod1"
Music_lenght = 20

awful.layout.layouts = {
    awful.layout.suit.tile,
    awful.layout.suit.tile.top,
    awful.layout.suit.fair
}

local taglist_buttons = gears.table.join(
    awful.button({ }, 1, function(t) t:view_only() end),
    awful.button({ Modkey }, 1, function(t)
        if client.focus then
            client.focus:move_to_tag(t)
        end
    end),
    awful.button({ }, 3, awful.tag.viewtoggle),
    awful.button({ Modkey }, 3, function(t)
        if client.focus then
            client.focus:toggle_tag(t)
        end
    end)
)

menubar.utils.terminal = Terminal -- Set the Terminal for applications that require it

-- Widget

local battery_widget = awful.widget.watch("cat /sys/class/power_supply/BAT0/uevent", 10 , function (widget, stdout)
    local data = {}
    for line in stdout:gmatch("[^\r\n]+") do
        local aux = {}
        for word in line:gmatch("[^=]+") do
            table.insert(aux, word)
        end
        data[aux[1]] =  aux[2]
    end
    local is_charging = ""
    local remaining_time = ""
    if ( data["POWER_SUPPLY_STATUS"] == "Charging" ) then
        is_charging = "+"
        remaining_time = ""
        -- remaining_time = (tonumber(data["POWER_SUPPLY_ENERGY_FULL"]) - tonumber(data["POWER_SUPPLY_POWER_NOW"])) / tonumber(data["POWER_SUPPLY_POWER_NOW"])
    elseif ( data["POWER_SUPPLY_STATUS"] == "Full" ) then
        is_charging = "="
        remaining_time = ""
    else
        is_charging = "-"
        local time = tonumber(data["POWER_SUPPLY_ENERGY_NOW"])
        / tonumber(data["POWER_SUPPLY_POWER_NOW"])
        remaining_time = string.format( "%.0fh:%.0fm", math.floor(time) , (time - math.floor(time)) * 60)
    end
    local capacity =  tonumber(data["POWER_SUPPLY_ENERGY_NOW"])
    / tonumber(data["POWER_SUPPLY_ENERGY_FULL_DESIGN"]) * 100
    widget:set_text(string.format("%s%.1f%% %d %s", is_charging, capacity, data["POWER_SUPPLY_CYCLE_COUNT"], remaining_time ))
end)

local volume_porcent = wibox.widget.textbox("", true)

local music_playing = awful.widget.watch("playerctl metadata title", 1, function(widget, stdout)
    widget:set_text( " | " .. stdout:sub(1,Music_lenght))
end)

-- function ( stdout, stderr, exitreason, exitcode )
local update_volume = function ( stdout, _, _, exitcode )
    if ( exitcode == 0 ) then
        volume_porcent:set_text(stdout)
    end
end

local mykeyboardlayout = awful.widget.keyboardlayout()

local mytextclock = wibox.widget.textclock("%d/%m/%Y - %H:%M")

gears.timer {
    timeout = 1,
    autostart = true,
    call_now = true,
    callback = function ()
        awful.spawn.easy_async("wpctl get-volume @DEFAULT_SINK@", update_volume)
    end
}

-- Screen configs

screen.connect_signal("property::geometry", set_wallpaper)

awful.screen.connect_for_each_screen(function(s)

    s.mypromptbox = awful.widget.prompt()
    if ( s.outputs.eDP1 ~= nil ) then
        local output_screen = s.outputs.eDP1
        if ( output_screen.nm_width == 390 and output_screen.nm_heigth == 190  ) then
            Music_lenght = 60
        end
        set_wallpaper(s)

        create_tags("1", s):view_only()
        create_tags("2", s)
        create_tags("3", s)
        create_tags("4", s)
        create_tags("5", s)
        create_tags("6", s)
        create_tags("7", s)
        create_tags("8", s)
        create_tags("9", s)
        create_tags("q", s)
        create_tags("w", s)
        create_tags("e", s)
        create_tags("r", s)
        s.mylayoutbox = awful.widget.layoutbox(s)

        s.mytaglist = awful.widget.taglist {
            screen  = s,
            filter  = awful.widget.taglist.filter.all,
            buttons = taglist_buttons
        }

        s.mywibox = awful.wibar({ position = "bottom", screen = s })
        s.mywibox:setup {
                layout = wibox.layout.align.horizontal,
                expand = "none",
                { -- Left widgets
                    layout = wibox.layout.fixed.horizontal,
                    s.mytaglist,
                    s.mypromptbox,
                },
            {
                layout = wibox.layout.fixed.horizontal,
                spacing = 15,
                battery_widget,
                {
                    layout = wibox.layout.fixed.horizontal,
                    volume_porcent,
                    music_playing
                }
            },
            -- s.mytasklist, -- Middle widget
            { -- Right widgets
                layout = wibox.layout.fixed.horizontal,
                spacing = 5,
                mykeyboardlayout,
                wibox.widget.systray(),
                mytextclock,
                s.mylayoutbox,
            },
        }
    elseif (s.outputs.HDMI1 ~= nil) then
        set_wallpaper(s)

        create_tags("1", s):view_only()
        create_tags("2", s)
        create_tags("3", s)
        create_tags("4", s)
        create_tags("q", s)
        create_tags("w", s)
        create_tags("e", s)
        create_tags("r", s)
        s.mylayoutbox = awful.widget.layoutbox(s)
        s.padding = { bottom=60 }

        s.mytaglist = awful.widget.taglist {
            screen  = s,
            filter  = awful.widget.taglist.filter.all,
            buttons = taglist_buttons
        }
        s.mywibox = awful.wibar({ position = "top", screen = s })
        s.mywibox:setup {
                layout = wibox.layout.align.horizontal,
                expand = "none",
                { -- Left widgets
                    layout = wibox.layout.fixed.horizontal,
                    s.mytaglist,
                    s.mypromptbox,
                },
            {
                layout = wibox.layout.fixed.horizontal,
                spacing = 15,
                battery_widget,
                {
                    layout = wibox.layout.fixed.horizontal,
                    volume_porcent,
                    music_playing
                }
            },
            -- s.mytasklist, -- Middle widget
            { -- Right widgets
                layout = wibox.layout.fixed.horizontal,
                spacing = 5,
                mykeyboardlayout,
                wibox.widget.systray(),
                mytextclock,
                s.mylayoutbox,
            },
        }
    end

end)

local globalkeys = gears.table.join(
    -- Group awesome
    awful.key({ Modkey,           }, "s",      hotkeys_popup.show_help, {description="show help", group="awesome"}),
    awful.key({ Modkey, "Control" }, "s", awesome.restart, {description = "reload awesome", group = "awesome"}),
    awful.key({ Modkey, "Shift"   }, "s", awesome.quit, {description = "quit awesome", group = "awesome"}),

    -- Group tag
    awful.key({ Modkey,           }, "Tab", awful.tag.history.restore, {description = "go back", group = "tag"}),

    -- Group client
    awful.key({ Modkey,           }, "j",
        function ()
            awful.client.focus.byidx( 1)
        end,
        {description = "focus next by index", group = "client"}
    ),
    awful.key({ Modkey,           }, "k",
        function ()
            awful.client.focus.byidx(-1)
        end,
        {description = "focus previous by index", group = "client"}
    ),

    awful.key({ Modkey, "Control" }, "n",
        function ()
            local c = awful.client.restore()
            -- Focus restored client
            if c then
                c:emit_signal(
                "request::activate", "key.unminimize", {raise = true}
                )
            end
        end,
        {description = "restore minimized", group = "client"}
    ),

    awful.key({ Modkey }, "x",
        function ()
            awful.prompt.run {
                prompt       = "Run Lua code: ",
                textbox      = awful.screen.focused().mypromptbox.widget,
                exe_callback = awful.util.eval,
                history_path = awful.util.get_cache_dir() .. "/history_eval"
            }
        end,
        {description = "lua execute prompt", group = "awesome"}
    ),

    -- Layout manipulation
    awful.key({ Modkey, "Shift"   }, "j",
        function ()
            awful.client.swap.byidx(1)
        end,
        {description = "swap with next client by index", group = "client"}
    ),
    awful.key({ Modkey, "Shift"   }, "k",
        function ()
            awful.client.swap.byidx(-1)
        end,
        {description = "swap with previous client by index", group = "client"}
    ),
    awful.key({ Modkey, "Control" }, "j",
        function ()
            awful.screen.focus_relative(1)
        end,
        {description = "focus the next screen", group = "screen"}
    ),
    awful.key({ Modkey, "Control" }, "k",
        function ()
            awful.screen.focus_relative(-1)
        end,
        {description = "focus the previous screen", group = "screen"}
    ),
    awful.key({ Modkey,           }, "u", awful.client.urgent.jumpto, {description = "jump to urgent client", group = "client"}),

    -- Standard program
    -- Group launcher
    awful.key({ Modkey,           }, "Return",
        function ()
            awful.spawn(Terminal)
        end,
        {description = "open a Terminal", group = "launcher"}
    ),
    -- Prompt
    awful.key({ Modkey }, "d",
        function ()
            awful.spawn("rofi -show drun")
        end,
        {description = "run prompt", group = "launcher"}
    ),

    -- Group layout
    awful.key({ Modkey,           }, "l",
        function ()
            awful.tag.incmwfact( 0.05)
        end,
        {description = "increase master width factor", group = "layout"}
    ),
    awful.key({ Modkey,           }, "h",
        function ()
            awful.tag.incmwfact(-0.05)
        end,
        {description = "decrease master width factor", group = "layout"}
    ),
    awful.key({ Modkey, "Shift"   }, "h",
        function ()
            awful.tag.incnmaster( 1, nil, true)
        end,
        {description = "increase the number of master clients", group = "layout"}
    ),
    awful.key({ Modkey, "Shift"   }, "l",
        function ()
            awful.tag.incnmaster(-1, nil, true)
        end,
        {description = "decrease the number of master clients", group = "layout"}
    ),
    awful.key({ Modkey, "Control" }, "h",
        function ()
            awful.tag.incncol( 1, nil, true)
        end,
        {description = "increase the number of columns", group = "layout"}
    ),
    awful.key({ Modkey, "Control" }, "l",
        function ()
            awful.tag.incncol(-1, nil, true)
        end,
        {description = "decrease the number of columns", group = "layout"}
    ),
    awful.key({ Modkey,           }, "space",
        function ()
            awful.layout.inc( 1)
        end,
        {description = "select next", group = "layout"}
    ),
    awful.key({ Modkey, "Shift"   }, "space",
        function ()
            awful.layout.inc(-1)
        end,
        {description = "select previous", group = "layout"}
    ),

    -- Group System
    -- Volume Control
    awful.key({}, "XF86AudioRaiseVolume",
        function ()
            awful.spawn.easy_async( "wpctl set-volume @DEFAULT_SINK@ 5%+",
                function ( _, _, _, exitcode )
                    if (exitcode == 0 ) then
                        awful.spawn.easy_async( "wpctl get-volume @DEFAULT_SINK@" , update_volume )
                    end
                end
            )
        end,
        { description = "raise volume", group = "system"}
    ),
    awful.key({}, "XF86AudioLowerVolume",
        function ()
            awful.spawn.easy_async( "wpctl set-volume @DEFAULT_SINK@ 5%-",
                function ( _, _, _, exitcode )
                    if (exitcode == 0 ) then
                        awful.spawn.easy_async( "wpctl get-volume @DEFAULT_SINK@" , update_volume )
                    end
                end
            )
        end,
        { description = "lower volume", group = "system"}
    ),
    awful.key({Modkey}, "F3",
        function ()
            awful.spawn.easy_async( "wpctl set-volume @DEFAULT_SINK@ 5%+",
                function ( _, _, _, exitcode )
                    if (exitcode == 0 ) then
                        awful.spawn.easy_async( "wpctl get-volume @DEFAULT_SINK@" , update_volume )
                    end
                end
            )
        end,
        { description = "raise volume", group = "system"}
    ),
    awful.key({Modkey}, "F2",
        function ()
            awful.spawn.easy_async( "wpctl set-volume @DEFAULT_SINK@ 5%-",
                function ( _, _, _, exitcode )
                    if (exitcode == 0 ) then
                        awful.spawn.easy_async( "wpctl get-volume @DEFAULT_SINK@" , update_volume )
                    end
                end
            )
        end,
        { description = "lower volume", group = "system"}
    ),

    -- Brightness Control
    awful.key({Modkey}, "m",
        function ()
            awful.spawn( "light -A 5")
        end, { description = "raise brightness", group = "system"}),
    awful.key({Modkey}, "n",
        function ()
            awful.spawn( "light -U 5")
        end,
        { description = "lower brightness", group = "system"}
    ),
    awful.key({ }, "XF86AudioPlay" ,
        function ()
            awful.spawn( "playerctl play-pause" )
        end,
        { description = "Play/Pause music", group = "system"}
    ),
    awful.key({ }, "XF86AudioPrev" ,
        function ()
            awful.spawn( "playerctl previous" )
        end,
        { description = "previous music", group = "system"}
    ),
    awful.key({ }, "XF86AudioNext" ,
        function ()
            awful.spawn( "playerctl next" )
        end,
        { description = "next music", group = "system"}
    )
)

-- TagKeybinds
globalkeys = gears.table.join(
    globalkeys,
    create_keys_for_tags('1',"1"),
    create_keys_for_tags('2',"2"),
    create_keys_for_tags('3',"3"),
    create_keys_for_tags('4',"4"),
    create_keys_for_tags('5',"5"),
    create_keys_for_tags('6',"6"),
    create_keys_for_tags('7',"7"),
    create_keys_for_tags('8',"8"),
    create_keys_for_tags('9',"9"),
    create_keys_for_tags('q',"q"),
    create_keys_for_tags('w',"w"),
    create_keys_for_tags('e',"e"),
    create_keys_for_tags('r',"r")
)

-- Set keys
root.keys(globalkeys)
-- }}}

-- Rules

local clientbuttons = gears.table.join(
    awful.button({ }, 1,
        function (c)
            c:emit_signal("request::activate", "mouse_click", {raise = true})
        end
    ),
    awful.button({ Modkey }, 1,
        function (c)
            c:emit_signal("request::activate", "mouse_click", {raise = true})
            awful.mouse.client.move(c)
        end
    ),
    awful.button({ Modkey }, 3,
        function (c)
            c:emit_signal("request::activate", "mouse_click", {raise = true})
            awful.mouse.client.resize(c)
        end
    )
)

local  clientkeys = gears.table.join(
    awful.key({ Modkey, "Shift"   }, "c",
        function (c)
            c:kill()
        end,
        {description = "close", group = "client"}
    ),
    awful.key({ Modkey, "Control" }, "Return",
        function (c)
            c:swap(awful.client.getmaster())
        end,
        {description = "move to master", group = "client"}
    ),
    awful.key({ Modkey,           }, "o",
        function (c)
            c:move_to_screen()
        end,
        {description = "move to screen", group = "client"}
    ),
    awful.key({ Modkey,           }, "t",
        function (c)
            c.ontop = not c.ontop
        end,
        {description = "toggle keep on top", group = "client"}
    ),
    awful.key({ Modkey,           }, "n",
        function (c)
            -- The client currently has the input focus, so it cannot be
            -- minimized, since minimized clients can't have the focus.
            c.minimized = true
        end ,
        {description = "minimize", group = "client"}
    )
)


-- Rules to apply to new clients (through the "manage" signal).
awful.rules.rules = {
    -- All clients will match this rule.
    {
        rule = { },
        properties = {
            border_width = beautiful.border_width,
            border_color = beautiful.border_normal,
            focus = awful.client.focus.filter,
            raise = true,
            keys = clientkeys,
            buttons = clientbuttons,
            screen = awful.screen.preferred,
            placement = awful.placement.no_overlap+awful.placement.no_offscreen
        }
    },

    -- Floating clients.
    {
        rule_any = {
            instance = {
                "DTA",  -- Firefox addon DownThemAll.
                "copyq",  -- Includes session name in class.
                "pinentry",
            },
            class = {
                "Arandr",
                "Blueman-manager",
                "Gpick",
                "Kruler",
                "MessageWin",  -- kalarm.
                "Sxiv",
                "Tor Browser", -- Needs a fixed window size to avoid fingerprinting by screen size.
                "Wpa_gui",
                "veromix",
                "xtightvncviewer"
            },

                -- Note that the name property shown in xprop might be set slightly after creation of the client
                -- and the name shown there might not match defined rules here.
            name = {
                "Event Tester",  -- xev.
            },
            role = {
                "AlarmWindow",  -- Thunderbird's calendar.
                "ConfigManager",  -- Thunderbird's about:config.
                "pop-up",       -- e.g. Google Chrome's (detached) Developer Tools.
            }
        },
        properties = {
            floating = true
        }
    },

            -- Add titlebars to normal clients and dialogs
    {
        rule_any = {
            type = {
                "normal",
                "dialog"
            }
        },
        properties = {
            titlebars_enabled = true
        }
    },

    -- Set Firefox to always map on the tag named "2" on screen 1.
    {
        rule = {
            class = "Firefox"
        },
        properties = {
            screen = 1,
            tag = "q"
        }
    },
}
-- }}}

-- {{{ Signals
-- Signal function to execute when a new client appears.
client.connect_signal("manage", function (c)
    -- Set the windows at the slave,
    -- i.e. put it at the end of others instead of setting it master.
    -- if not awesome.startup then awful.client.setslave(c) end

    if awesome.startup
        and not c.size_hints.user_position
        and not c.size_hints.program_position then
        -- Prevent clients from being unreachable after screen count changes.
        awful.placement.no_offscreen(c)
    end
end)

-- Add a titlebar if titlebars_enabled is set to true in the rules.
-- client.connect_signal("request::titlebars", function(c)
    --     -- buttons for the titlebar
    --     local buttons = gears.table.join(
    --         awful.button({ }, 1, function()
        --             c:emit_signal("request::activate", "titlebar", {raise = true})
        --             awful.mouse.client.move(c)
        --         end),
        --         awful.button({ }, 3, function()
            --             c:emit_signal("request::activate", "titlebar", {raise = true})
            --             awful.mouse.client.resize(c)
            --         end)
            --     )
            -- 
            --     awful.titlebar(c) : setup {
                --         { -- Left
                --             awful.titlebar.widget.iconwidget(c),
                --             buttons = buttons,
                --             layout  = wibox.layout.fixed.horizontal
                --         },
                --         { -- Middle
                --             { -- Title
                --                 align  = "center",
                --                 widget = awful.titlebar.widget.titlewidget(c)
                --             },
                --             buttons = buttons,
                --             layout  = wibox.layout.flex.horizontal
                --         },
                --         { -- Right
                --             awful.titlebar.widget.floatingbutton (c),
                --             awful.titlebar.widget.maximizedbutton(c),
                --             awful.titlebar.widget.stickybutton   (c),
                --             awful.titlebar.widget.ontopbutton    (c),
                --             awful.titlebar.widget.closebutton    (c),
                --             layout = wibox.layout.fixed.horizontal()
                --         },
                --         layout = wibox.layout.align.horizontal
                --     }
                -- end)

                -- Enable sloppy focus, so that focus follows mouse.
client.connect_signal("mouse::enter", function(c)
    c:emit_signal("request::activate", "mouse_enter", {raise = false})
end)

client.connect_signal("focus", function(c) c.border_color = beautiful.border_focus end)
client.connect_signal("unfocus", function(c) c.border_color = beautiful.border_normal end)
                -- }}}
