-- See https://wiki.hypr.land/Configuring/Start/

-- Split config into multiple files with require, e.g.
-- require("myColors")

------------------
---- MONITORS ----
------------------

-- See https://wiki.hypr.land/Configuring/Basics/Monitors/
-- Default layout is HDMI-A-1 stacked above eDP-1. Hyprland applies these rules
-- on hot-plug, so no watcher is needed; when HDMI-A-1 is unplugged eDP-1 just
-- stays on alone. The eDP-1 y offset is the external monitor's height (1440).
-- The `monitor` script switches layouts at runtime; its changes persist until
-- the next config reload or `monitor stack`.
-- `disabled = false` is explicit because hl.monitor() merges into the existing
-- rule, which matters when edp_rule is re-applied at runtime below.
local edp_rule = { output = "eDP-1", disabled = false, mode = "preferred", position = "0x1440", scale = 1 }
hl.monitor({ output = "HDMI-A-1", mode = "preferred", position = "0x0", scale = 1 })
hl.monitor(edp_rule)

-- After `monitor ext` eDP-1 is disabled, so unplugging HDMI-A-1 would leave no
-- output on. Re-enable eDP-1 in that case. The `monitor` script never removes
-- HDMI-A-1 while eDP-1 is off, so this only fires on a real unplug.
hl.on("monitor.removed", function(monitor)
    if monitor.name == "HDMI-A-1" and hl.get_monitor("eDP-1") == nil then
        hl.monitor(edp_rule)
    end
end)

---------------------
---- MY PROGRAMS ----
---------------------

local terminal = "footclient"

-------------------
---- AUTOSTART ----
-------------------

hl.on("hyprland.start", function()
    hl.exec_cmd("foot --server")
    hl.exec_cmd("~/.config/hypr/random_wallpaper.sh")
    hl.exec_cmd("mako")
    hl.exec_cmd("/usr/lib/polkit-kde-authentication-agent-1")

    hl.exec_cmd("waybar")
end)

-------------------------------
---- ENVIRONMENT VARIABLES ----
-------------------------------

-- hl.env("XDG_SESSION_TYPE", "wayland")
-- hl.env("GBM_BACKEND", "nvidia-drm")

-- No global NVIDIA vars: the AMD iGPU drives the display, and forcing apps onto
-- the dGPU (e.g. Chrome's GPU acceleration) causes cross-GPU copies and stutter.
-- Use `prime-run <cmd>` for games/CUDA.
-- hl.env("LIBVA_DRIVER_NAME", "nvidia")
-- hl.env("__GLX_VENDOR_LIBRARY_NAME", "nvidia")
-- hl.env("NVD_BACKEND", "direct")
hl.env("WLR_NO_HARDWARE_CURSORS", "1") -- show cursor on both screens when mirroring
hl.env("XCURSOR_SIZE", "24")
hl.env("QT_QPA_PLATFORMTHEME", "qt5ct") -- change to qt6ct if you have that

-----------------
---- OPTIONS ----
-----------------

-- For all categories, see https://wiki.hypr.land/Configuring/Basics/Variables/
hl.config({
    input = {
        kb_layout  = "losipai",
        kb_variant = "",
        kb_model   = "",
        kb_options = "caps:escape_shifted_capslock",
        kb_rules   = "",

        follow_mouse = 1,

        touchpad = {
            natural_scroll = false,
        },

        sensitivity = 0, -- -1.0 to 1.0, 0 means no modification.
    },

    general = {
        gaps_in     = 4,
        gaps_out    = 8,
        border_size = 2,

        col = {
            active_border   = { colors = { "rgba(33ccffee)", "rgba(00ff99ee)" }, angle = 45 },
            inactive_border = "rgba(595959aa)",
        },

        layout = "master",

        -- Please see https://wiki.hypr.land/Configuring/Advanced-and-Cool/Tearing/ before you turn this on
        allow_tearing = false,
    },

    decoration = {
        rounding = 10,

        blur = {
            enabled = true,
            size    = 3,
            passes  = 1,
        },
    },

    animations = {
        enabled = false,
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Dwindle-Layout/ for more
    dwindle = {
        preserve_split = true, -- you probably want this
    },

    -- See https://wiki.hypr.land/Configuring/Layouts/Master-Layout/ for more
    -- master = {
    --     new_status = "master",
    -- },

    misc = {
        force_default_wallpaper  = 0, -- Set to 0 or 1 to disable the anime mascot wallpapers
        disable_hyprland_logo    = true,
        disable_splash_rendering = true,
    },

    debug = {
        disable_logs = false,
    },
})

hl.device({
    name        = "epic-mouse-v1",
    sensitivity = -0.5,
})

--------------------
---- ANIMATIONS ----
--------------------

-- Animations are disabled above; these only take effect if re-enabled.
-- See https://wiki.hypr.land/Configuring/Advanced-and-Cool/Animations/
hl.curve("myBezier", { type = "bezier", points = { { 0.05, 0.9 }, { 0.1, 1.05 } } })

hl.animation({ leaf = "windows",     enabled = true, speed = 7,  bezier = "myBezier" })
hl.animation({ leaf = "windowsOut",  enabled = true, speed = 7,  bezier = "default", style = "popin 80%" })
hl.animation({ leaf = "border",      enabled = true, speed = 10, bezier = "default" })
hl.animation({ leaf = "borderangle", enabled = true, speed = 8,  bezier = "default" })
hl.animation({ leaf = "fade",        enabled = true, speed = 7,  bezier = "default" })
hl.animation({ leaf = "workspaces",  enabled = true, speed = 6,  bezier = "default" })

----------------------
---- WINDOW RULES ----
----------------------

-- See https://wiki.hypr.land/Configuring/Basics/Window-Rules/
hl.window_rule({
    name  = "launcher-popup",
    match = { title = "^(launcher)$" },
    float = true,
    size  = "monitor_w*0.2 monitor_h*0.2",
    move  = "monitor_w*0.4 monitor_h*0.4",
})

hl.window_rule({ name = "tile-teams",     match = { title = "^(Microsoft Teams)(.*)$" }, tile = true })
hl.window_rule({ name = "tile-outlook",   match = { title = "^(Outlook)(.*)$" },         tile = true })
hl.window_rule({ name = "no-anim-chrome", match = { title = ".*Google Chrome.*" },        no_anim = true })
hl.window_rule({ name = "katrain",        match = { title = ".*KaTrain.*" },             tile = true, no_anim = true })

---------------------
---- KEYBINDINGS ----
---------------------

local mainMod = "SUPER"

-- See https://wiki.hypr.land/Configuring/Basics/Binds/ for more
hl.bind(mainMod .. " + Return",    hl.dsp.exec_cmd(terminal))
hl.bind(mainMod .. " + F",         hl.dsp.window.fullscreen())
hl.bind(mainMod .. " + SHIFT + C", hl.dsp.window.close())
hl.bind(mainMod .. " + SHIFT + Q", hl.dsp.exit())
hl.bind(mainMod .. " + V",         hl.dsp.window.float({ action = "toggle" }))
hl.bind(mainMod .. " + P",         hl.dsp.window.pseudo()) -- dwindle
hl.bind(mainMod .. " + J",         hl.dsp.layout("togglesplit")) -- dwindle
hl.bind(mainMod .. " + R", hl.dsp.exec_cmd(
    [[footclient --title=launcher bash -c 'compgen -c | sort -u | fzf --no-extended --reverse --border=sharp --color=16 --print-query | tail -1 | xargs -r -d "\n" -I{} hyprctl dispatch "hl.dsp.exec_cmd([==[{}]==])"']]
))

-- Move focus with mainMod + arrow keys
-- Move tiles with mainMod + SHIFT + arrow keys
for _, direction in ipairs({ "left", "right", "up", "down" }) do
    hl.bind(mainMod .. " + " .. direction,         hl.dsp.focus({ direction = direction }))
    hl.bind(mainMod .. " + SHIFT + " .. direction, hl.dsp.window.move({ direction = direction }))
end

-- Switch workspaces with mainMod + [0-9]
-- Move active window to a workspace (without following it) with mainMod + SHIFT + [0-9]
for i = 1, 10 do
    local key = i % 10 -- 10 maps to key 0
    hl.bind(mainMod .. " + " .. key,         hl.dsp.focus({ workspace = i }))
    hl.bind(mainMod .. " + SHIFT + " .. key, hl.dsp.window.move({ workspace = i, follow = false }))
end

-- Special workspace (scratchpad)
hl.bind(mainMod .. " + S",         hl.dsp.workspace.toggle_special("magic"))
hl.bind(mainMod .. " + SHIFT + S", hl.dsp.window.move({ workspace = "special:magic", follow = true }))

-- Scroll through existing workspaces with mainMod + scroll
hl.bind(mainMod .. " + mouse_down", hl.dsp.focus({ workspace = "e+1" }))
hl.bind(mainMod .. " + mouse_up",   hl.dsp.focus({ workspace = "e-1" }))

-- Move/resize windows with mainMod + LMB/RMB and dragging
hl.bind(mainMod .. " + mouse:272", hl.dsp.window.drag(),   { mouse = true })
hl.bind(mainMod .. " + mouse:273", hl.dsp.window.resize(), { mouse = true })

-- Multimedia keys, also active while locked
hl.bind("XF86AudioRaiseVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%+"),    { locked = true, repeating = true })
hl.bind("XF86AudioLowerVolume",  hl.dsp.exec_cmd("wpctl set-volume @DEFAULT_AUDIO_SINK@ 5%-"),    { locked = true, repeating = true })
hl.bind("XF86AudioMute",         hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SINK@ toggle"),   { locked = true })
hl.bind("XF86AudioMicMute",      hl.dsp.exec_cmd("wpctl set-mute @DEFAULT_AUDIO_SOURCE@ toggle"), { locked = true })
hl.bind("XF86MonBrightnessDown", hl.dsp.exec_cmd("brightnessctl -q set 5%-"),                     { locked = true, repeating = true })
hl.bind("XF86MonBrightnessUp",   hl.dsp.exec_cmd("brightnessctl -q set +5%"),                     { locked = true, repeating = true })
