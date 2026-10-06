#!/usr/bin/env lua

-- Backend driver for Quickshell Clipboard Manager (cliphist integration)
local cmd = arg[1] or "list"
local runtime = os.getenv("XDG_RUNTIME_DIR") or "/tmp"

-- Escapes strings for safe JSON serialization
local function json_escape(str)
if not str then return "" end
    str = str:gsub("\\", "\\\\")
    str = str:gsub('"', '\\"')
    str = str:gsub("\n", "\\n")
    str = str:gsub("\r", "\\r")
    str = str:gsub("\t", "\\t")
    return str
    end

    if cmd == "list" then
        -- Fetches raw cliphist tab-delimited list and converts to clean JSON
        local handle = io.popen("cliphist list 2>/dev/null")
        if not handle then
            print("[]")
            return
            end

            local entries = {}
            for line in handle:lines() do
                local id, content = line:match("^(%d+)\t(.*)$")
                if id and content then
                    local is_img = content:find("%[%[ binary data") ~= nil or content:find("%[%[ image") ~= nil
                    local thumb_path = ""

                    -- If image, decode a thumbnail to XDG_RUNTIME_DIR for quick asynchronous loading
                    if is_img then
                        thumb_path = runtime .. "/qs_clip_thumb_" .. id .. ".png"
                        local check = io.open(thumb_path, "r")
                        if not check then
                            os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode > '%s' 2>/dev/null", id, thumb_path))
                            else
                                check:close()
                                end
                                thumb_path = "file://" .. thumb_path
                                end

                                local entry = string.format(
                                    '{"id":"%s","isImage":%s,"text":"%s","displayText":"%s","title":"%s","searchText":"%s","thumbPath":"%s"}',
                                    id,
                                    is_img and "true" or "false",
                                    json_escape(content),
                                                            json_escape(content),
                                                            is_img and "Image Entry" or "Text Entry",
                                                            json_escape(content:lower()),
                                                            json_escape(thumb_path)
                                )
                                table.insert(entries, entry)
                                end
                                end
                                handle:close()

                                print("[" .. table.concat(entries, ",") .. "]")

                                elseif cmd == "preview" then
                                    local id = arg[2]
                                    if not id then return end
                                        -- Outputs decoded text directly to stdout for preview
                                        os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode 2>/dev/null", id))

                                        elseif cmd == "ocr" then
                                            local id = arg[2]
                                            if not id then return end
                                                local tmp_file = runtime .. "/qs_ocr_" .. id .. ".png"

                                                -- Decode image, run tesseract OCR, and clean up temporary asset
                                                os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode > '%s' 2>/dev/null", id, tmp_file))
                                                local handle = io.popen(string.format("tesseract '%s' stdout 2>/dev/null", tmp_file))
                                                if handle then
                                                    local text = handle:read("*a")
                                                    handle:close()
                                                    io.write(text or "")
                                                    end
                                                    os.remove(tmp_file)

                                                    elseif cmd == "copy" then
                                                        local id = arg[2]
                                                        if not id then return end
                                                            -- Copies selection back into Wayland active clipboard
                                                            os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist decode 2>/dev/null | wl-copy", id))

                                                            elseif cmd == "delete" then
                                                                local id = arg[2]
                                                                if not id then return end
                                                                    -- Purges entry from cliphist database and removes local thumbnail
                                                                    os.execute(string.format("printf '%%s\\t\\n' '%s' | cliphist delete 2>/dev/null", id))
                                                                    os.remove(runtime .. "/qs_clip_thumb_" .. id .. ".png")

                                                                    elseif cmd == "wipe" then
                                                                        -- Completely clears cliphist database and removes all cached thumbnails
                                                                        os.execute("cliphist wipe 2>/dev/null")
                                                                        os.execute(string.format("rm -f '%s'/qs_clip_thumb_*.png 2>/dev/null || true", runtime))
                                                                        end
