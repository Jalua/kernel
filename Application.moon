export log = require "log"
moon = require "moon"
app = require "pl.app"
dir = require "pl.dir"
path = require "pl.path"
utils = require "pl.utils"
moonscript = require "moonscript"

version = "0.0"
manifest_file_name = "WesMod.moon"

flags, params = app.parse_args!
log.level = flags["log-level"] or "info"

if flags["log-help"]
  log.trace("TRACE")
  log.debug("DEBUG")
  log.info("INFO")
  log.warn("WARN")
  log.error("ERROR")
  log.fatal("FATAL")
  utils.quit("Normal Exit")

if flags["help"]
  print([[
--log-level=trace|debug|info|warn|error|fatal
--data-dir
--userdata-dir
--userconfig-dir
]])
  utils.quit("Normal Exit")

platform = app.platform!
log.debug("Running on " .. platform)

--- @TODO detect them
data_dir = flags["data-dir"] or "../root"
userdata_dir = flags["userdata-dir"] or path.join("~/.local/share/kernel", version, "data")
userconfig_dir = flags["userconfig-dir"] or "~/.config/kernel"

userdata_dir = path.expanduser(userdata_dir)
userconfig_dir = path.expanduser(userconfig_dir)

check_root = (root, name, create) ->
  if path.isdir(root)
    log.info(name .. " found at: " .. root)
    manifest = path.join(root, manifest_file_name)
    if path.isfile(manifest)
      log.debug("Reading manifest file: " .. manifest)
      wesmod_type = nil
      env =
        root: (cfg) ->
          wesmod_type = cfg.type
      file_fun = moonscript.loadfile(manifest)
      utils.setfenv(file_fun, env)
      file_fun!
      if (wesmod_type != "root")
        log.warn(name .. " is not valid at: " .. root)
        return false
      else return true
    else log.warn("No Manifest file found at " .. manifest)
  else
    log.warn(name .. "not found at: " .. root)
    if create
      success, err = dir.makepath(root)
      if not success
        log.err("Couldn't create " .. name .. "at " .. root .. ": " .. err)
      else
        log.warn(name .. " created at " .. root)
    return false

data_found = check_root(data_dir, "data-dir", false)
userdata_found = check_root(userdata_dir, "userdata-dir", true)
userconfig_found = check_root(userconfig_dir, "userconfig-dir", true)

if not (data_found or userdata_found)
  log.fatal("No game content found")
  utils.quit("Aborting...")

--- Yeah, let's make a plan here:
-- 1) Load basics from toplevel root
-- 2) Next we need a core or there won't be any content
-- 3) Ready to load a scenario now -- load only the content
game = require("Game")(data_dir, userdata_dir)
--game\debug! -- The game should print the root content
if game\load_wesmod("test") -- a core
  game\debug!

game\debug!

log.info("Exiting...")
utils.quit("Normal Exit")
