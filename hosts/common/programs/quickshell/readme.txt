================================================================================
QUICKSHELL SYSTEM CONFIGURATION & ARCHITECTURE DOCUMENTATION
================================================================================

1. OVERVIEW
-----------
This Quickshell configuration provides a complete desktop shell environment for
Wayland compositors (Sway / Hyprland). It features:
  • An animated top status bar with slanted cyberpunk capsules and tooltips.
  • An all-in-one modal launcher (Applications, Clipboard, Passwords, Todo, Notes,
    Dictionary, Unicode search, Math/Currency converter, Gemini AI, Settings, Power).
  • A hardware-accelerated email client (Himalaya CLI integration).
  • A Wayland lock screen backed by PAM authentication.
  • Quickshot: a screenshot & OCR studio with invisible cryptographic watermarking.
  • Desktop notification server with speech cues, priority stacking, and history.

2. PROJECT STRUCTURE & MODULES
------------------------------
./
├── shell.qml                     # ShellRoot: Bar window, overlays, PAM lock, global IPC
├── Theme.qml                     # Central color palette (Stylix base00-base0F tokens)
├── Ipc.qml                       # Singleton IPC bridge dispatcher
├── readme.txt                    # System documentation
│
├── modules/
│   ├── bar/                      # Top bar capsules and slanted tooltips
│   │   ├── alarm/                # Alarm & timer manager (pw-play backend)
│   │   ├── battery/              # Battery status capsule
│   │   ├── calendar/             # Interactive monthly calendar
│   │   ├── clock/                # Clock and multi-timezone matrix
│   │   ├── cpu/                  # CPU usage and top client process monitor
│   │   ├── gpu/                  # Multi-GPU metrics (AMD/Nvidia/Intel) & VRAM danger
│   │   ├── music/                # MPD music player controls and seek bar
│   │   ├── network/              # Bandwidth monitor, dynamic ping, and active clients
│   │   ├── notify/               # Notification counter & DND toggle
│   │   ├── ram/                  # Physical & ZRAM usage breakdown
│   │   ├── sound/                # PipeWire master audio sink & mic control
│   │   ├── tray/                 # Animated expandable System Tray (SNI)
│   │   ├── unified/              # System health, Borg offsite backup, Twitch miners
│   │   └── weather/              # Live wttr.in weather forecast & outage risk alerts
│   │
│   ├── common/                   # Shared UI and utility components
│   │   ├── PackageInstallerModal.qml # Sudo package installer for official repos
│   │   ├── ProcessMonitorList.qml    # Reusable process manager with search and kill
│   │   └── Utils.js              # Formatting, unit conversions, math evaluator
│   │
│   ├── lockscreen/               # PAM-authenticated Wayland lock surface
│   │   └── LockScreen.qml        # Lockscreen UI with clock, date, and CapsLock check
│   │
│   ├── overlays/                 # Floating windows and modal overlays
│   │   ├── launcher/             # Multi-mode launcher & sub-panels
│   │   │   ├── AppLauncher.qml   # High-speed desktop application scanner
│   │   │   ├── BatteryEngine.qml # Headless battery sysfs reader
│   │   │   ├── Clipboard.qml     # Cliphist clipboard manager & preview
│   │   │   ├── Dictionary.qml    # Wiktionary live definition lookups
│   │   │   ├── Email/            # Email suite (Sidebar, ListView, Preview, Compose)
│   │   │   ├── GeminiPanel.qml   # Google Gemini AI chat panel
│   │   │   ├── LauncherOverlay.qml # Master launcher controller & modal UI
│   │   │   ├── Notes.qml         # SQLite quick note taker
│   │   │   ├── Pass.qml          # Standard 'pass' password manager browser
│   │   │   ├── PowerView.qml     # Session control (Lock, Sleep, Logout, Reboot, Halt)
│   │   │   ├── SettingsPanel.qml # Live GUI configuration panel
│   │   │   ├── Todo.qml          # SQLite Kanban/todo manager
│   │   │   └── UnicodeSearch.qml # Unicode emoji & symbol finder
│   │   │
│   │   ├── magnify/              # Screen magnifier lens overlay
│   │   ├── notifications/        # D-Bus notification daemon and history drawer
│   │   ├── quickshot/            # Region screenshot, annotation, & watermark engine
│   │   └── rng/                  # Polyhedral dice roller & coin flipper
│   │
│   ├── settings/                 # Settings management subsystem
│   │   ├── ColorPickerPopup.qml  # HSV color picker modal
│   │   ├── CyberSlider.qml       # Styled numeric slider
│   │   ├── CyberToggle.qml       # Styled on/off toggle switch
│   │   └── SettingsManager.qml   # Persistent configuration controller
│   │
│   └── style/                    # Styling primitives
│       ├── SlantedBox.qml        # Parallelogram / chamfered shape renderer
│       └── SlantedTooltip.qml    # Sliding animated slanted tooltip window

3. IPC COMMAND INTERFACE
------------------------
Quickshell exposes built-in IPC endpoints. Trigger these via your window manager
keybindings (e.g. Sway / Hyprland config):

  Command                                  Action
  ---------------------------------------  -----------------------------------------
  qs ipc call launcher toggle              Toggle Application Launcher
  qs ipc call clipboard toggle             Toggle Clipboard History
  qs ipc call pass toggle                  Toggle Password Manager
  qs ipc call todo toggle                  Toggle Todo List
  qs ipc call notes toggle                 Toggle Quick Notes
  qs ipc call email toggle                 Toggle Email Client
  qs ipc call settings toggle              Toggle Settings Panel
  qs ipc call power toggle                 Toggle Power / Session Menu
  qs ipc call rng toggle                   Toggle Dice Roller & Coin Flipper
  qs ipc call gemini toggle                Toggle Gemini AI Chat
  qs ipc call magnifier toggle             Toggle Screen Magnifier
  qs ipc call lockscreen lock              Lock the screen immediately
  qs ipc call lockscreen unlock            Unlock the screen
  qs ipc call global_notif dismissLatest   Dismiss the active notification toast
  qs ipc call global_notif jumpToLatest    Focus app that sent latest notification
  qs ipc call global_notif toggleHistory   Toggle Notification History Drawer



5. CONFIGURATION & STATE STORAGE
--------------------------------
  • Settings JSON: ~/.config/quickshell/settings.json
  • Gemini API Token: ~/.config/quickshell/gemini_key or /run/secrets/gemini_token
  • Email SQLite Queue: Offline mail actions cached in QMailQueue
  • Todo Database: ~/.local/share/QTodoQueue
  • Notes Database: ~/.local/share/QNotesDB
  • Screenshots: ~/Screenshots (configurable via Settings Panel)
================================================================================
