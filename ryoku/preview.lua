package.path = os.getenv("HOME") .. "/.config/hypr/?.lua;" .. package.path
require("modules.binds")
require("modules.decoration")
require("modules.resize")
require("modules.record")
require("modules.ryoshot")

hl.monitor({ output = "", mode = "preferred", position = "auto", scale = 1 })
hl.config({ general = { border_size = 1 } })
hl.layer_rule({
    name = "tsukuyomi-frost",
    match = { namespace = "^ryoku-(frame-edge|dock)$" },
    blur = true,
    ignore_alpha = 0.05,
})

hl.on("hyprland.start", function()
    hl.exec_cmd("bash /preview/session.sh")
end)

hl.bind("CTRL + SHIFT + F12", hl.dsp.exit())
hl.bind("CTRL + SHIFT + F11", hl.dsp.exec_cmd("ryoku-shell hub open"))
hl.bind("CTRL + SHIFT + F10", hl.dsp.exec_cmd("ryoku-shell quicksettings"))
