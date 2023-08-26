local awful = require("awful")
local M = {}

local new_music_widget = function (width)
    local widget_player = awful.widget.watch("playerctl metadata title", 1, function(widget, stdout)
        widget:set_text( " | " .. stdout:sub(1,width))
    end)
    return widget_player
end

M.new_music_widget = new_music_widget

return M
