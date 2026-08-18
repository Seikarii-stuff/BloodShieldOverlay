std = "lua51"

-- WoW's API is injected by the client, so undefined-global warnings are not useful here.
-- Keep the rest of Luacheck enabled for ordinary Lua mistakes and dead locals.
ignore = { "113" }
max_line_length = 140
