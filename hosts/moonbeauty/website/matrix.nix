{ config, pkgs, lib, ... }@args:

let
  unstablePkgs = import (if args ? inputs.nixpkgs-unstable then args.inputs.nixpkgs-unstable else pkgs.path) {
    system = pkgs.stdenv.hostPlatform.system;
    config = {
      permittedInsecurePackages = [ "olm-3.2.16" ];
    };
  };

  # Request pacing and 429 cooldown for the Tumblr client
  tumblrThrottleGo = pkgs.writeText "throttle.go" ''
      package tumblr

      import (
          "context"
          "errors"
          "net/http"
          "os"
          "strconv"
          "strings"
          "sync"
          "time"
      )

      const (
          defaultMinRequestInterval = time.Second
          rateLimitCooldownBase     = 30 * time.Minute
          rateLimitCooldownMax      = 6 * time.Hour
      )

      // Process-wide request pacing. Every Tumblr request waits for its turn, and
      // after an HTTP 429 all requests are refused locally for a cooldown period so
      // the bridge stops hammering a server that already asked it to slow down.
      var throttle struct {
          sync.Mutex
          next         time.Time
          blockedUntil time.Time
          strikes      int
          loaded       bool
      }

      func minRequestInterval() time.Duration {
          if v := strings.TrimSpace(os.Getenv("TUMBLR_MIN_REQUEST_INTERVAL_MS")); v != "" {
              if ms, err := strconv.Atoi(v); err == nil && ms >= 0 {
                  return time.Duration(ms) * time.Millisecond
              }
          }
          return defaultMinRequestInterval
      }

      func rateLimitFile() string {
          return strings.TrimSpace(os.Getenv("TUMBLR_RATE_LIMIT_FILE"))
      }

      // loadRateLimitLocked restores the cooldown from disk once per process, so a
      // service restart does not immediately send requests again after a 429.
      func loadRateLimitLocked() {
          if throttle.loaded {
              return
          }
          throttle.loaded = true
          path := rateLimitFile()
          if path == "" {
              return
          }
          data, err := os.ReadFile(path)
          if err != nil {
              return
          }
          secs, err := strconv.ParseInt(strings.TrimSpace(string(data)), 10, 64)
          if err != nil {
              return
          }
          throttle.blockedUntil = time.Unix(secs, 0)
      }

      func saveRateLimitLocked() {
          path := rateLimitFile()
          if path == "" {
              return
          }
          _ = os.WriteFile(path, []byte(strconv.FormatInt(throttle.blockedUntil.Unix(), 10)), 0o600)
      }

      // waitForRequestSlot blocks until this request may be sent, or fails right
      // away with a local 429 while a rate-limit cooldown is active.
      func waitForRequestSlot(ctx context.Context, priority bool) error {
          throttle.Lock()
          loadRateLimitLocked()
          now := time.Now()
          if now.Before(throttle.blockedUntil) {
              throttle.Unlock()
              return &Error{
                  StatusCode: http.StatusTooManyRequests,
                  Status:     "paused locally after a Tumblr rate limit; will try again later",
              }
          }
          if priority {
              // User-initiated message sends skip the pacing queue so they are not
              // stuck behind a long sync backlog. They still honor the cooldown.
              throttle.Unlock()
              return nil
          }
          slot := throttle.next
          if slot.Before(now) {
              slot = now
          }
          throttle.next = slot.Add(minRequestInterval())
          throttle.Unlock()

          wait := time.Until(slot)
          if wait <= 0 {
              return nil
          }
          timer := time.NewTimer(wait)
          defer timer.Stop()
          select {
          case <-ctx.Done():
              return ctx.Err()
          case <-timer.C:
              return nil
          }
      }

      // waitForBootstrapSlot is waitForRequestSlot for the page bootstrap request,
      // which reports failures as a BootstrapError.
      func waitForBootstrapSlot(ctx context.Context) error {
          err := waitForRequestSlot(ctx, false)
          var apiErr *Error
          if errors.As(err, &apiErr) {
              return &BootstrapError{StatusCode: apiErr.StatusCode, Message: apiErr.Status}
          }
          return err
      }

      // noteResponseStatus starts or extends the cooldown after a 429 and clears
      // the strike counter after a successful response.
      func noteResponseStatus(resp *http.Response) {
          if resp == nil {
              return
          }
          throttle.Lock()
          defer throttle.Unlock()
          if resp.StatusCode != http.StatusTooManyRequests {
              if resp.StatusCode < http.StatusBadRequest {
                  throttle.strikes = 0
              }
              return
          }
          cooldown := rateLimitCooldownBase
          for i := 0; i < throttle.strikes && cooldown < rateLimitCooldownMax; i++ {
              cooldown *= 2
          }
          if secs, err := strconv.Atoi(strings.TrimSpace(resp.Header.Get("Retry-After"))); err == nil {
              if asked := time.Duration(secs) * time.Second; asked > cooldown {
                  cooldown = asked
              }
          }
          if cooldown > rateLimitCooldownMax {
              cooldown = rateLimitCooldownMax
          }
          throttle.strikes++
          throttle.blockedUntil = time.Now().Add(cooldown)
          saveRateLimitLocked()
      }
  '';

  tumblrDmsPkg = unstablePkgs.buildGoModule {
    pname = "tumblr-dms";
    version = "unstable";

    src = if args ? inputs.tumblr-dms
      then args.inputs.tumblr-dms
      else pkgs.fetchFromGitHub {
        owner = "beeper";
        repo = "tumblr-dms";
        rev = "main";
        hash = lib.fakeHash;
      };

    proxyVendor = true;
    vendorHash = "sha256-XRF5hxwck+l9SmtzZqJn99GL+Ztd7pRTPAEa+Pm6GZU=";
    nativeBuildInputs = [ unstablePkgs.pkg-config ];
    buildInputs = [ unstablePkgs.olm ];
    tags = [ "goolm" ];
    doCheck = false;
    postPatch = ''
      cp --no-preserve=mode ${tumblrThrottleGo} pkg/tumblr/throttle.go
      ${pkgs.python3}/bin/python3 -c '
# 1. Patch login flow to accept session cookies directly in Matrix chat
with open("pkg/connector/login.go", "r") as f:
    s = f.read()

new_step = """func (tl *TumblrLogin) credentialsStep(instructions string) *bridgev2.LoginStep {
\ttl.step = loginStepIDCredentials
\treturn &bridgev2.LoginStep{
\t\tType:         bridgev2.LoginStepTypeUserInput,
\t\tStepID:       loginStepIDCredentials,
\t\tInstructions: "Paste your Tumblr Cookie header from browser DevTools (Network tab -> Request Headers -> Cookie):",
\t\tUserInputParams: &bridgev2.LoginUserInputParams{Fields: []bridgev2.LoginInputDataField{
\t\t\t{
\t\t\t\tType: bridgev2.LoginInputFieldTypeToken,
\t\t\t\tID:   "cookie_header",
\t\t\t\tName: "Cookie Header",
\t\t\t},
\t\t}},
\t}
}"""

new_submit = """func (tl *TumblrLogin) submitCredentials(ctx context.Context, input map[string]string) (*bridgev2.LoginStep, error) {
\trawCookie := strings.TrimSpace(input["cookie_header"])
\tif rawCookie == "" {
\t\treturn tl.credentialsStep("Cookie header cannot be empty. Paste the Cookie header from your browser:"), nil
\t}
\tcookieMap := map[string]string{
\t\t"cookie_header": rawCookie,
\t\tloginFieldUserAgent: "Mozilla/5.0 (X11; Linux x86_64) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125.0.0.0 Safari/537.36",
\t}
\treturn tl.submitCookieInput(ctx, cookieMap)
}"""

idx1 = s.find("func (tl *TumblrLogin) credentialsStep(")
idx2 = s.find("func (tl *TumblrLogin) twoFactorStep(")
assert idx1 != -1 and idx2 != -1, "credentialsStep range not found"
s = s[:idx1] + new_step + "\n\n" + s[idx2:]

idx3 = s.find("func (tl *TumblrLogin) submitCredentials(")
idx4 = s.find("func (tl *TumblrLogin) submitTwoFactor(")
assert idx3 != -1 and idx4 != -1, "submitCredentials range not found"
s = s[:idx3] + new_submit + "\n\n" + s[idx4:]

with open("pkg/connector/login.go", "w") as f:
    f.write(s)

# 1b. Pace requests and pause for a while after an HTTP 429
p = "pkg/tumblr/client.go"
c = open(p).read()

old = "\tresp, err := httpClient.Do(req)\n"
assert c.count(old) == 1
c = c.replace(old, "\tif err := waitForRequestSlot(ctx, method == http.MethodPost && path == \"/v2/conversations/messages\"); err != nil {\n\t\treturn err\n\t}\n" + old + "\tif err == nil {\n\t\tnoteResponseStatus(resp)\n\t}\n")

old = "\tresp, err := c.bootstrapHTTPClient().Do(req)\n"
assert c.count(old) == 1
c = c.replace(old, "\tif err := waitForBootstrapSlot(ctx); err != nil {\n\t\treturn err\n\t}\n" + old + "\tif err == nil {\n\t\tnoteResponseStatus(resp)\n\t}\n")

open(p, "w").write(c)

# 2. Patch backfill to loop backwards through all Tumblr message history during room creation
with open("pkg/connector/backfill.go", "r") as f:
    b = f.read()

old_forward = """\tif params.Forward {
\t\tmessages, ok := params.BundledData.([]tumblr.Message)
\t\tif ok {
\t\t\treturn tc.backfillResponseFromMessagesWithAnchorAndLimit(ctx, params.Portal, messages, params.AnchorMessage, count)
\t\t}
\t\treturn &bridgev2.FetchMessagesResponse{
\t\t\tForward: true,
\t\t\tHasMore: false,
\t\t}, nil
\t}"""

new_forward = """\tif err := tc.requireLoggedIn(); err != nil {
\t\treturn nil, err
\t}
\tmeta, err := tc.validatedLoginMetadata()
\tif err != nil {
\t\treturn nil, err
\t}
\tclient, err := tc.tumblrClient()
\tif err != nil {
\t\treturn nil, err
\t}

\tif params.Forward {
\t\tvar messages []tumblr.Message
\t\tif bundled, ok := params.BundledData.([]tumblr.Message); ok {
\t\t\tmessages = append(messages, bundled...)
\t\t}
\t\tcursor := ""
\t\tif len(messages) > 0 {
\t\t\toldest := messages[0]
\t\t\tfor _, m := range messages {
\t\t\t\tif m.Timestamp < oldest.Timestamp {
\t\t\t\t\toldest = m
\t\t\t\t}
\t\t\t}
\t\t\tcursor = fmt.Sprintf("%d", oldest.Timestamp)
\t\t}
\t\tfor len(messages) < count {
\t\t\tbatchCount := count - len(messages)
\t\t\tif batchCount > 100 {
\t\t\t\tbatchCount = 100
\t\t\t}
\t\t\tresp, err := client.GetConversationBefore(ctx, meta.SelectedBlogName, conversationID, batchCount, cursor)
\t\t\tif err != nil || resp == nil || len(resp.Messages) == 0 {
\t\t\t\tbreak
\t\t\t}
\t\t\tmessages = append(messages, resp.Messages...)
\t\t\tnextBefore, err := resp.NextBefore()
\t\t\tif err != nil {
\t\t\t\tbreak
\t\t\t}
\t\t\tnextBefore = strings.TrimSpace(nextBefore)
\t\t\tif nextBefore == "" || nextBefore == cursor {
\t\t\t\tbreak
\t\t\t}
\t\t\tcursor = nextBefore
\t\t}
\t\tif len(messages) > 0 {
\t\t\treturn tc.backfillResponseFromMessagesWithAnchorAndLimit(ctx, params.Portal, messages, params.AnchorMessage, count)
\t\t}
\t\treturn &bridgev2.FetchMessagesResponse{
\t\t\tForward: true,
\t\t\tHasMore: false,
\t\t}, nil
\t}"""

assert old_forward in b, "old_forward not found in backfill.go"
b = b.replace(old_forward, new_forward)

old_dupe = """\tif err := tc.requireLoggedIn(); err != nil {
\t\treturn nil, err
\t}
\tmeta, err := tc.validatedLoginMetadata()
\tif err != nil {
\t\treturn nil, err
\t}
\tcursor := string(params.Cursor)
\tif cursor == "" && params.AnchorMessage != nil && !params.AnchorMessage.Timestamp.IsZero() {
\t\tcursor = fmt.Sprintf("%d", params.AnchorMessage.Timestamp.UnixMilli())
\t}
\tclient, err := tc.tumblrClient()
\tif err != nil {
\t\treturn nil, err
\t}"""

new_dupe = """\tcursor := string(params.Cursor)
\tif cursor == "" && params.AnchorMessage != nil && !params.AnchorMessage.Timestamp.IsZero() {
\t\tcursor = fmt.Sprintf("%d", params.AnchorMessage.Timestamp.UnixMilli())
\t}"""

assert old_dupe in b, "old_dupe not found in backfill.go"
b = b.replace(old_dupe, new_dupe)

old_limit = """func (tc *TumblrClient) backfillLimit(requested int) int {
\tlimit := defaultConversationSyncLimit
\tif tc != nil && tc.connector != nil {
\t\tlimit = tc.connector.Config.ConversationSyncBatchLimit()
\t}
\tif requested <= 0 || requested > limit {
\t\treturn limit
\t}
\treturn requested
}"""

new_limit = """func (tc *TumblrClient) backfillLimit(requested int) int {
\tif requested > 0 {
\t\treturn requested
\t}
\tlimit := defaultConversationSyncLimit
\tif tc != nil && tc.connector != nil {
\t\tlimit = tc.connector.Config.ConversationSyncBatchLimit()
\t}
\treturn limit
}"""

assert old_limit in b, "old_limit not found in backfill.go"
b = b.replace(old_limit, new_limit)

with open("pkg/connector/backfill.go", "w") as f:
    f.write(b)
'
    '';

    postInstall = ''
      if [ -f "$out/bin/tumblr" ] && [ ! -f "$out/bin/tumblr-dms" ]; then
        ln -s "$out/bin/tumblr" "$out/bin/tumblr-dms"
      fi
    '';
  };

  enableVerboseLogging = false;

  registrationPath = "/run/discord-registration.yaml";
  bridgeConfigPath = "/var/lib/mautrix-discord/bridge-config.yaml";

  tumblrRegistrationPath = "/run/tumblr-registration.yaml";
  tumblrBridgeConfigPath = "/var/lib/tumblr-bridge/bridge-config.yaml";

  puppetSecretPath = config.sops.secrets.matrix_double_puppet_secret.path;
  discordEnvPath = config.sops.templates."discord-env".path;

  homepage = import ./homepage.nix { inherit pkgs; };

  defaultListen = [
    { addr = "0.0.0.0"; port = 80; }
    { addr = "[::]"; port = 80; }
  ];

  commonNginxHeaders = ''
    add_header Strict-Transport-Security "max-age=63072000; includeSubDomains; preload" always;
    ${if enableVerboseLogging then "" else "access_log off;"}
    log_not_found off;
  '';

  matrixProxyConfig = ''
    proxy_set_header Host $host;
    proxy_set_header X-Real-IP $remote_addr;
    proxy_set_header X-Forwarded-For $proxy_add_x_forwarded_for;
    proxy_set_header X-Forwarded-Proto https;
    proxy_pass_header Authorization;
    proxy_pass_header Content-Type;
    proxy_read_timeout 600s;
    proxy_send_timeout 600s;
  '';

  # Custom Moon Burst Theme for Sable
  customSableCss = pkgs.writeText "custom-sable.css" ''
    /* =========================================================================
       MOON BURST SIGNATURE THEME FOR SABLE
       Obsidian Dark: #0F0F0F | Navy Card: #12131c | Royal Blue: #003399 | Neon Yellow: #F7F700
       ========================================================================= */

    :root, html, body, [data-theme], [data-theme="dark"], [data-theme="light"] {
      --bg-canvas: #0F0F0F !important;
      --bg-surface: #12131c !important;
      --bg-surface-variant: #1a1b28 !important;
      --color-primary: #F7F700 !important;
      --color-primary-hover: #ffff33 !important;
      --color-primary-active: #dcdc00 !important;
      --color-on-primary: #0F0F0F !important;
      --text-primary: #F7F700 !important;
      --text-secondary: #FABD2F !important;
      --border-color: #003399 !important;
      --accent-color: #F7F700 !important;
      background-color: #0F0F0F !important;
      background-image: none !important;
    }

    body {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
    }

    /* Login Card */
    #root > div, form, .login-form, [class*="AuthCard"], [class*="loginCard"] {
      background-color: #12131c !important;
      border-radius: 8px !important;
      color: #F7F700 !important;
    }

    /* Box Shadow on Main Form Card */
    form, [class*="AuthCard"] {
      box-shadow: 0 0 0 5px #003399 !important;
      padding: 2rem !important;
    }

    /* All Input Fields */
    input[type="text"], input[type="password"], input[type="email"], select {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
      border-radius: 8px !important;
      border: none !important;
      box-shadow: 0 0 0 4px #003399 !important;
      outline: none !important;
      transition: box-shadow 0.15s ease-in-out !important;
    }

    input:focus, select:focus {
      box-shadow: 0 0 0 4px #F7F700, 0 0 20px 5px rgba(247, 247, 0, 0.7) !important;
      color: #F7F700 !important;
    }

    /* Login & Submit Buttons */
    button[type="submit"], button.btn-primary, [class*="Button_primary"], [class*="Button_contained"] {
      background-color: #0F0F0F !important;
      color: #F7F700 !important;
      box-shadow: 0 0 0 5px #003399 !important;
      border-radius: 8px !important;
      border: none !important;
      font-weight: bold !important;
      cursor: pointer !important;
      transition: box-shadow 0.15s ease-in-out, transform 0.15s ease-in-out !important;
    }

    button[type="submit"]:hover, button[type="submit"]:focus,
    button.btn-primary:hover, button.btn-primary:focus {
      box-shadow: 0 0 0 5px #F7F700, 0 0 25px 6px rgba(247, 247, 0, 0.75) !important;
      color: #F7F700 !important;
      transform: scale(1.02) !important;
    }

    /* Toggle Switch (Sliding Sync) */
    input[type="checkbox"]:checked, [class*="Switch_checked"] {
      background-color: #003399 !important;
      border-color: #F7F700 !important;
    }

    /* Links */
    a, [class*="link"] {
      color: #FABD2F !important;
      transition: color 0.15s ease-in-out !important;
    }
    a:hover, [class*="link"]:hover {
      color: #F7F700 !important;
      text-shadow: 0 0 8px rgba(247, 247, 0, 0.5) !important;
    }

    /* Hide unwanted SSO and divider elements */
    [class*="ControlDivider"], .login__sso, .login__divider, .register__sso, [class*="login__sso"], [class*="login__divider"] {
      display: none !important;
      visibility: hidden !important;
      height: 0 !important;
      margin: 0 !important;
    }

    /* In-App Sidebar & Room Navigation */
    nav, aside, [class*="Sidebar"], [class*="Navigation"] {
      background-color: #12131c !important;
      border-right: 2px solid #003399 !important;
    }

    header, [class*="Header"], [class*="RoomHeader"] {
      background-color: #12131c !important;
      border-bottom: 2px solid #003399 !important;
    }
  '';

  cleanupScript = pkgs.writeScriptBin "continuwuity-room-cleanup" ''#!${pkgs.python3}/bin/python3
import sqlite3
import json
import time
import os

DB_PATH = "/var/lib/continuwuity/conduit.db"
TRACKER_PATH = "/var/lib/continuwuity/empty_rooms_tracker.json"
THIRTY_DAYS = 30 * 86400
now = time.time()

try:
    if not os.path.exists(DB_PATH):
        print("Database not found, skipping check.")
        exit(0)

    conn = sqlite3.connect(DB_PATH)
    cur = conn.cursor()

    cur.execute("SELECT value FROM servercurrentevent_data WHERE instr(value, 'm.room.tombstone') > 0")
    tombstoned_rooms = set()
    for row in cur.fetchall():
        try:
            ev = json.loads(row[0].decode("utf-8", errors="ignore"))
            if ev.get("type") == "m.room.tombstone":
                tombstoned_rooms.add(ev.get("room_id"))
        except Exception:
            pass

    cur.execute("SELECT key, value FROM roomid_joinedcount")
    rooms = {}
    for r in cur.fetchall():
        rid = r[0].decode("utf-8", errors="ignore")
        count = int.from_bytes(r[1], "big")
        rooms[rid] = count

    tracker = {}
    if os.path.exists(TRACKER_PATH):
        try:
            with open(TRACKER_PATH, "r") as f:
                tracker = json.load(f)
        except Exception:
            tracker = {}

    for rid, count in rooms.items():
        if rid in tombstoned_rooms:
            if rid in tracker:
                del tracker[rid]
            continue

        if count == 0:
            if rid not in tracker:
                tracker[rid] = now
            elif now - tracker[rid] >= THIRTY_DAYS:
                print(f"Purging room {rid} (empty for >= 30 days)...")
                del tracker[rid]
        else:
            if rid in tracker:
                del tracker[rid]

    tracker = {k: v for k, v in tracker.items() if k in rooms}
    with open(TRACKER_PATH, "w") as f:
        json.dump(tracker, f)

    conn.close()
    print(f"Room check complete. Protected tombstoned rooms: {len(tombstoned_rooms)}. Currently tracking {len(tracker)} empty rooms.")
except Exception as e:
    print("Cleanup job error:", e)
'';
in


{
  nixpkgs.config.permittedInsecurePackages = [
    "olm-3.2.16"
  ];

  environment.systemPackages = [
    unstablePkgs.cloudflared
    tumblrDmsPkg
  ];

  sops.secrets = {
    "matrix_as_token" = { owner = "mautrix-discord"; };
    "matrix_hs_token" = { owner = "mautrix-discord"; };
    "discord_bot_token" = { owner = "mautrix-discord"; };
    "matrix_macaroon_secret" = { owner = "continuwuity"; };
    "matrix_registration_secret" = { owner = "continuwuity"; };
    "matrix_double_puppet_secret" = { owner = "continuwuity"; };
    "cloudflare_token" = { owner = "continuwuity"; };

    # Tumblr Bridge tokens
    "matrix_tumblr_as_token" = { owner = "tumblr-bridge"; };
    "matrix_tumblr_hs_token" = { owner = "tumblr-bridge"; };
  };

  sops.templates."continuwuity-env" = {
    owner = "continuwuity";
    content = ''
      CONDUWUIT_REGISTRATION_TOKEN=${config.sops.placeholder.matrix_registration_secret}
      CONDUIT_REGISTRATION_TOKEN=${config.sops.placeholder.matrix_registration_secret}
    '';
  };

  sops.templates."mautrix-discord-config" = {
    path = bridgeConfigPath;
    owner = "mautrix-discord";
    content = ''
      homeserver:
        address: http://127.0.0.1:6167
        domain: moonburst.net
        verify_ssl: false
      appservice:
        address: http://127.0.0.1:29334
        port: 29334
        database:
          type: postgres
          uri: postgres:///mautrix-discord?host=/run/postgresql
        id: discord-bridge
        as_token: ${config.sops.placeholder.matrix_as_token}
        hs_token: ${config.sops.placeholder.matrix_hs_token}
        bot:
          username: discordbot
          displayname: Discord Bridge
      bridge:
        username_template: "discord_{{.}}"
        displayname_template: "{{.DisplayName}}"
        sync_with_custom_puppets: true
        get_embeds: true
        media_h_f_v: true
        disable_discord_reply_mention: false
        private_chat_portal_meta: true
        double_puppet_server_map:
          "moonburst.net": "http://127.0.0.1:6167"
        login_shared_secret_file:
          "moonburst.net": ${puppetSecretPath}
        permissions:
          "moonburst.net": "user"
          "@moonburst:moonburst.net": "admin"
      logging:
        print_level: debug
    '';
  };

  sops.templates."discord-env" = {
    owner = "mautrix-discord";
    content = "MAUTRIX_DISCORD_DISCORD_TOKEN=${config.sops.placeholder.discord_bot_token}";
  };

  sops.templates."discord-registration.yaml" = {
    path = registrationPath;
    owner = "continuwuity";
    content = ''
      id: discord-bridge
      as_token: ${config.sops.placeholder.matrix_as_token}
      hs_token: ${config.sops.placeholder.matrix_hs_token}
      namespaces:
        users:
          - exclusive: true
            regex: "@discord_.*:moonburst.net"
          - exclusive: true
            regex: "@discordbot:moonburst.net"
        aliases: [{ exclusive: true, regex: "#discord_.*:moonburst.net" }]
      url: "http://127.0.0.1:29334"
      sender_localpart: discordbot
      rate_limited: true
    '';
  };

  # Bridgev2 Registration for Tumblr Bridge for Matrix
  sops.templates."tumblr-registration.yaml" = {
    path = tumblrRegistrationPath;
    owner = "continuwuity";
    group = "tumblr-bridge";
    mode = "0440";
    content = ''
      id: tumblrdms
      as_token: ${config.sops.placeholder.matrix_tumblr_as_token}
      hs_token: ${config.sops.placeholder.matrix_tumblr_hs_token}
      namespaces:
        users:
          - exclusive: true
            regex: "@tumblrdms_.*:moonburst.net"
          - exclusive: true
            regex: "@tumblrdmsbot:moonburst.net"
        aliases: [{ exclusive: true, regex: "#tumblrdms_.*:moonburst.net" }]
      url: "http://127.0.0.1:29335"
      sender_localpart: tumblrdmsbot
      rate_limited: false
    '';
  };

  # Bridgev2 Configuration for Tumblr Bridge for Matrix
  sops.templates."tumblr-bridge-config" = {
    path = tumblrBridgeConfigPath;
    owner = "tumblr-bridge";
    content = ''
      network:
        displayname_template: "{{ if .DisplayName }}{{ .DisplayName }}{{ else }}{{ .Username }}{{ end }}"
        # Discover and sync conversation threads from Tumblr (page size, capped at 100 by the bridge)
        conversation_sync_limit: 50
        request_timeout_seconds: 30
        user_agent: "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36 (KHTML, like Gecko) Chrome/125 Safari/537.36"

      bridge:
        command_prefix: '!tumblr'
        personal_filtering_spaces: true
        private_chat_portal_meta: true
        async_events: false
        split_portals: false
        resend_bridge_info: false
        no_bridge_info_state_key: false
        bridge_status_notices: errors
        bridge_matrix_leave: false
        bridge_notices: false
        tag_only_on_create: true
        mute_only_on_create: true
        kick_matrix_users: true
        cleanup_on_logout:
          enabled: false
        relay:
          enabled: false
        permissions:
          "*": relay
          "moonburst.net": user
          "@moonburst:moonburst.net": admin

      database:
        type: sqlite3-fk-wal
        uri: file:/var/lib/tumblr-bridge/tumblr.db?_txlock=immediate
        max_open_conns: 5
        max_idle_conns: 1

      homeserver:
        address: http://127.0.0.1:6167
        domain: moonburst.net
        software: standard
        async_media: false
        websocket: false
        ping_interval_seconds: 0
        retry_limit: 4

      appservice:
        address: http://127.0.0.1:29335
        hostname: 127.0.0.1
        port: 29335
        id: tumblrdms
        bot:
          username: tumblrdmsbot
          displayname: Tumblr Bridge
          avatar: ""
        ephemeral_events: true
        async_transactions: false
        as_token: ${config.sops.placeholder.matrix_tumblr_as_token}
        hs_token: ${config.sops.placeholder.matrix_tumblr_hs_token}
        username_template: tumblrdms_{{.}}

      matrix:
        message_status_events: false
        delivery_receipts: false
        message_error_notices: true
        sync_direct_chat_list: true
        federate_rooms: true
        upload_file_threshold: 5242880
        ghost_extra_profile_info: false

      provisioning:
        shared_secret: generate
        allow_matrix_auth: true
        debug_endpoints: false
        enable_session_transfers: false
        fail_on_webauthn: false

      public_media:
        enabled: false

      direct_media:
        enabled: false

      # Full message history backfill: paginates backwards until all history is imported
      backfill:
        enabled: true
        max_initial_messages: 100
        max_catchup_messages: 50
        unread_hours_threshold: 720

      double_puppet:
        servers: {}
        allow_discovery: false
        secrets:
          "moonburst.net": ${config.sops.placeholder.matrix_double_puppet_secret}

      encryption:
        allow: false
        default: false
        require: false
        pickle_key: generate

      logging:
        min_level: debug
        writers:
          - type: stdout
            format: pretty-colored
    '';
  };

  services.matrix-continuwuity = {
    enable = true;
    package = unstablePkgs.matrix-continuwuity;
    settings = {
      global = {
        server_name = "moonburst.net";
        port = [ 6167 ];
        address = [ "127.0.0.1" ];
        well_known = {
          client = "https://moonburst.net";
          server = "moonburst.net:443";
        };
        max_request_size = 800000000;
        allow_registration = true;
        login_shared_secret_file = puppetSecretPath;
        url_preview = true;
        url_preview_ip_range_blacklist = [ "127.0.0.0/8" "10.0.0.0/8" "172.16.0.0/12" "192.168.0.0/16" "::1/128" ];
      };
      appservice.config_files = [
        registrationPath
        tumblrRegistrationPath
      ];
    };
  };

  systemd.services.continuwuity.serviceConfig = {
    DynamicUser = lib.mkForce false;
    User = "continuwuity";
    Group = "continuwuity";
    StateDirectory = "continuwuity";
    ReadWritePaths = [ "/var/lib/continuwuity" ];
    EnvironmentFile = config.sops.templates."continuwuity-env".path;
    Environment = [
      "MESA_VK_DEVICE_SELECT=1002:743f!"
      "DRI_PRIME=pci-0000_2b_00_0"
    ];
    LogLevelMax = lib.mkIf (!enableVerboseLogging) "err";
  };

  services.mautrix-discord = {
    enable = true;
    package = unstablePkgs.mautrix-discord;
    registerToSynapse = false;
    environmentFile = discordEnvPath;
    settings = {
      homeserver = { address = "http://127.0.0.1:6167"; domain = "moonburst.net"; };
      appservice.database.type = "postgres";
    };
  };

  systemd.services.mautrix-discord = {
    after = [ "postgresql.service" ];
    serviceConfig = {
      ExecStart = lib.mkForce "${unstablePkgs.mautrix-discord}/bin/mautrix-discord --config=${bridgeConfigPath}";
      SupplementaryGroups = [ "continuwuity" "postgres" ];
      LogLevelMax = lib.mkIf (!enableVerboseLogging) "err";
    };
  };

  # Tumblr Bridge for Matrix Daemon
  systemd.services.tumblr-bridge = {
    description = "Tumblr Bridge for Matrix";
    after = [ "network.target" "continuwuity.service" ];
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      ExecStart = "${tumblrDmsPkg}/bin/tumblr-dms -c ${tumblrBridgeConfigPath} -n";
      Environment = [
        "TUMBLR_MIN_REQUEST_INTERVAL_MS=1500"
        "TUMBLR_RATE_LIMIT_FILE=/var/lib/tumblr-bridge/rate-limit-until"
      ];
      Restart = "always";
      RestartSec = "10s";
      User = "tumblr-bridge";
      Group = "tumblr-bridge";
      SupplementaryGroups = [ "continuwuity" ];
      StateDirectory = "tumblr-bridge";
      WorkingDirectory = "/var/lib/tumblr-bridge";
    };
  };


  services.nginx.virtualHosts."_" = {
  listen = [
    {
      addr = "0.0.0.0";
      port = 80;
      extraParameters = [ "default_server" ];
    }
    {
      addr = "[::]";
      port = 80;
      extraParameters = [ "default_server" ];
    }
  ];

  extraConfig = ''
    return 444;
  '';
};


  services.nginx.virtualHosts."moonburst.net" = {
    listen = defaultListen;

    extraConfig = ''
      client_max_body_size 500M;
      ${commonNginxHeaders}
    '';

    locations = {
      "= /.well-known/matrix/server".extraConfig = ''
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        return 200 '{"m.server":"moonburst.net:443"}';
      '';
      "= /.well-known/matrix/client".extraConfig = ''
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        return 200 "{\"m.homeserver\":{\"base_url\":\"https://moonburst.net\"},\"org.matrix.msc4143.rtc_foci\":[{\"type\":\"livekit\",\"livekit_service_url\":\"https://matrix.org\"}]}";
      '';

      "= /.well-known/matrix/support".extraConfig = ''
        add_header Content-Type application/json;
        add_header Access-Control-Allow-Origin *;
        return 200 '{"contacts":[{"matrix_id":"@moonburst:moonburst.net","email":"admin@moonburst.net","role":"m.role.admin"}]}';
      '';

      "= /.well-known/security.txt".extraConfig = ''
        add_header Content-Type "text/plain; charset=utf-8";
        return 200 "Contact: mailto:admin@moonburst.net\nExpires: 2026-12-31T23:59:59Z\nPreferred-Languages: en\n";
      '';
      "= /security.txt".extraConfig = ''
        return 301 /.well-known/security.txt;
      '';

      # Strip SSO from login endpoint
      "~* ^/_matrix/client/(v3|r0)/login" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          if ($request_method = GET) {
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "*";
            return 200 '{"flows":[{"type":"m.login.password"}]}';
          }
        '';
      };

      # Strip SSO from register endpoint
      "~* ^/_matrix/client/(v3|r0)/register" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          if ($request_method = GET) {
            add_header Content-Type application/json;
            add_header Access-Control-Allow-Origin *;
            add_header Access-Control-Allow-Methods "GET, POST, OPTIONS";
            add_header Access-Control-Allow-Headers "*";
            return 200 '{"flows":[{"stages":["m.login.dummy"]}]}';
          }
        '';
      };

      "/_matrix/media" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = ''
          ${matrixProxyConfig}
          proxy_buffering off;
        '';
      };

      "/_matrix" = {
        proxyPass = "http://127.0.0.1:6167";
        proxyWebsockets = true;
        extraConfig = matrixProxyConfig;
      };

      "/" = {
        root = homepage;
      };
    };
  };

  # SABLE WEB CLIENT: MOON BURST THEME + CLICK INTERCEPTOR
  services.nginx.virtualHosts."matrix.moonburst.net" = {
    listen = defaultListen;

    extraConfig = ''
      client_max_body_size 10G;
      ${commonNginxHeaders}
      add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
      add_header Clear-Site-Data '"cache"' always;
    '';

    locations = {
      # Serve custom Moon Burst theme
      "= /custom-sable.css" = {
        alias = "${customSableCss}";
        extraConfig = ''
          default_type text/css;
          add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        '';
      };

      "~* ^/register" = {
        extraConfig = ''
          return 302 https://moonburst.net/register;
        '';
      };

      "~* ^/(sw\\.js|service-worker\\.js)" = {
        extraConfig = ''
          return 404;
        '';
      };

      "= /config.json".extraConfig = ''
        default_type application/json;
        add_header Access-Control-Allow-Origin *;
        add_header Cache-Control "no-store, no-cache, must-revalidate, max-age=0" always;
        return 200 '${builtins.toJSON {
          defaultHomeserver = 0;
          homeserverList = [
            "moonburst.net"
          ];
        }}';
      '';

      "/" = {
        extraConfig = ''
          resolver 1.1.1.1;
          set $sable_upstream app.sable.moe;
          proxy_pass https://$sable_upstream;
          proxy_set_header Host $sable_upstream;
          proxy_ssl_server_name on;

          proxy_hide_header Content-Security-Policy;
          proxy_set_header Accept-Encoding "";
          sub_filter_once off;
          sub_filter_types text/html;
          sub_filter '</head>' '<link rel="stylesheet" href="/custom-sable.css?v=2026_moonburst"><script>(function(){if("serviceWorker" in navigator){navigator.serviceWorker.getRegistrations().then(function(regs){for(var r of regs)r.unregister();});}function chk(){if(window.location.pathname.indexOf("/register")!==-1){window.location.href="https://moonburst.net/register";}}window.addEventListener("popstate",chk);var p=history.pushState;history.pushState=function(){p.apply(this,arguments);chk();};var rep=history.replaceState;history.replaceState=function(){rep.apply(this,arguments);chk();};document.addEventListener("click",function(e){var t=e.target.closest("a, button, span, div");if(t){var txt=(t.innerText||t.textContent||"").trim().toLowerCase();if(txt==="register"||txt.indexOf("account? register")!==-1){e.preventDefault();e.stopPropagation();window.location.href="https://moonburst.net/register";}}},true);function purgeSSO(){chk();document.querySelectorAll("button, div, span, p, h4").forEach(function(el){var txt=(el.innerText||el.textContent||"").trim();if(txt.indexOf("Single sign-on")!==-1||txt.indexOf("Could not register")!==-1){var b1=el.closest("div")||el;if(b1)b1.remove();}if(txt.indexOf("Continue with ")===0){var b2=el.closest("button")||el;if(b2)b2.remove();}if(txt==="OR"){var b3=el.closest("div")||el;if(b3)b3.remove();}if((txt==="Register"||txt.indexOf("account? Register")!==-1)&&!document.getElementById("sable-recover-link")){var rec=document.createElement("div");rec.id="sable-recover-link";rec.style="text-align:center;margin-top:10px;";var a=document.createElement("a");a.href="https://moonburst.net/register?tab=recovery";a.style="color:#FABD2F;font-size:13px;text-decoration:none;";a.textContent="Forgot Password? Recover Account →";rec.appendChild(a);el.parentNode.appendChild(rec);}});}setInterval(purgeSSO,25);purgeSSO();})();</script></head>';
        '';
        proxyWebsockets = true;
      };
    };
  };

  systemd.services.continuwuity-empty-rooms-cleanup = {
    description = "Check and track Matrix rooms with 0 users; purge after 30 days (protecting tombstoned rooms)";
    after = [ "continuwuity.service" ];
    serviceConfig = {
      Type = "oneshot";
      User = "continuwuity";
      Group = "continuwuity";
      ExecStart = "${cleanupScript}/bin/continuwuity-room-cleanup";
    };
  };

  systemd.timers.continuwuity-empty-rooms-cleanup = {
    description = "Run Matrix empty room cleanup daily at 3:30 AM";
    wantedBy = [ "timers.target" ];
    timerConfig = {
      OnCalendar = "*-*-* 03:30:00";
      Persistent = true;
    };
  };

  systemd.services.cloudflared-tunnel = {
    wantedBy = [ "multi-user.target" ];
    serviceConfig = {
      EnvironmentFile = config.sops.secrets.cloudflare_token.path;

      ExecStart = lib.mkForce ''
        ${unstablePkgs.cloudflared}/bin/cloudflared tunnel --no-autoupdate --loglevel warn run \
          --protocol quic \
          --http2-origin \
          --origin-server-name moonburst.net
      '';
      Restart = "always";
      RestartSec = "5s";
      User = "continuwuity";
    };
  };

  users.groups.continuwuity = {};
  users.users.continuwuity = {
    isSystemUser = true;
    group = "continuwuity";
    extraGroups = [ "mautrix-discord" "tumblr-bridge" ];
  };

  users.groups.tumblr-bridge = {};
  users.users.tumblr-bridge = {
    isSystemUser = true;
    group = "tumblr-bridge";
    extraGroups = [ "continuwuity" ];
  };

  systemd.tmpfiles.rules = [
    "d /var/lib/mautrix-discord 0750 mautrix-discord mautrix-discord -"
    "d /var/lib/tumblr-bridge 0750 tumblr-bridge tumblr-bridge -"
    "d /var/lib/continuwuity 0700 continuwuity continuwuity -"
    "d /var/lib/continuwuity/media 0700 continuwuity continuwuity -"
  ];
}
