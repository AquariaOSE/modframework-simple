local plugins = {}

local function import(p)
    local r = dofile("src/logic/" .. p .. ".lua")
    if r then
        table.insert(plugins, r)
    end
end

import "functions"
import "todo"
import "editoraddons"
import "cn"
-- add any other plugins here

return plugins
