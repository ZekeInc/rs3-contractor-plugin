-- luacheck settings for official RS3 plugins
std = "lua54"
max_line_length = 120
read_globals = {
  -- Game API globals used by the plugins in this repo.
  -- Add new ones here when you start using them.
  "Plugin",
  "Event",
  "Player",
  "config",
  "var",
  "id",
  "ui",
  "Vector3",
  "Vector4",
  "Mouse",
  "PersistentDB",
  "ShapeList",
  "ShapeData",
  "LocList",
  "HintList",
  "CoordGrid",
  "CoordFine",
  "World",
}
