-- BEGIN screenshot-to-action
-- Screenshot-to-Action: {{HOTKEY_DESC}} triggers region screenshot capture
hs.hotkey.bind({{HOTKEY_MODS}}, "{{HOTKEY_KEY}}", function()
    hs.task.new("/bin/bash", nil, {"{{INSTALL_DIR}}/screenshot-capture.sh"}):start()
end)
-- END screenshot-to-action
