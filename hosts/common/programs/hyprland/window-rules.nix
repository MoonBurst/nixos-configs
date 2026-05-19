{ }: ''
  windowrulev2 = workspace 1, class:(vesktop)
  windowrulev2 = workspace 2, class:(edopro)
  windowrulev2 = workspace 5, class:(Audacious)
  windowrulev2 = fullscreen, class:(edopro)
  windowrulev2 = immediate, class:(steam_app.*)
  windowrulev2 = bordersize 1, class:(.*)
  windowrulev2 = idleinhibit focus, class:(gamescope), title:(Overwatch)

  windowrulev2 = maximize, class:(.*)

  # Fixed formatting layout structure matching your exact version constraints
  windowrulev2 = nofocus, class:^(quickshell)$
  windowrulev2 = noinitialfocus, class:^(quickshell)$
  windowrulev2 = noshadow, class:^(quickshell)$
  windowrulev2 = nofocus, title:(?i).*notification.*

  windowrulev2 = float, class:(satty)
  windowrulev2 = size 800 800, class:(satty)
  
  windowrulev2 = float, class:(dev.benz.walker)
  windowrulev2 = noborder, class:(dev.benz.walker)
  windowrulev2 = pin, class:(dev.benz.walker)
  windowrulev2 = opacity 1.0 override 1.0 override, class:(dev.benz.walker)
  windowrulev2 = size 700 500, class:(dev.benz.walker)
  windowrulev2 = center, class:(dev.benz.walker)

  windowrulev2 = float, class:(walker)
  windowrulev2 = noborder, class:(walker)
  windowrulev2 = pin, class:(walker)
  windowrulev2 = opacity 1.0 override 1.0 override, class:(walker)
  windowrulev2 = size 700 500, class:(walker)
  windowrulev2 = center, class:(walker)
''
