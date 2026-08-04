{ ... }:
{
  wayland.windowManager.hyprland.extraConfig = ''
    hl.config({
      group = {
        insert_after_current = false,
        group_on_movetoworkspace = true
      }
    })

    -- Window Rules
    hl.window_rule({ name = "sway-auto-group", match = { class = ".*" }, group = "set" })
    hl.window_rule({ name = "edopro-fullscreen", match = { class = "edopro" }, fullscreen = true })
    hl.window_rule({ name = "satty-float", match = { class = "satty" }, float = true, size = "800 800" })
    hl.window_rule({ name = "quickshell-float", match = { class = "org.quickshell" }, float = true, size = "700 500", center = true, pin = true })


    local pinned_workspace = {
      vesktop = "1",
      edopro = "2",
      Audacious = "5",
    }
    hl.on("window.open", function(w)
      local target = pinned_workspace[w.class]
      if target then
        hl.dispatch(hl.dsp.window.move({ workspace = target, window = w.address }))
      end
    end)
  '';
}
