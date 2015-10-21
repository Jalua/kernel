-- MoonScript
moon = require "moon"
moonscript = require "moonscript"
-- Penlight lib requires
path = require "pl.path"
dir = require "pl.dir"
utils = require "pl.utils"
tablex = require "pl.tablex"

----
-- @TODO
-- @classmod Game
class Game

  try = require "try"

  ----
  -- Load a single file within the given environment.
  -- @param file the filepath to load
  -- @env environment to execute in
  load_cfg_file: (file, env) =>
    assert(env, "No env")
    assert(file, "No file")
    file_path = path.dirname(file)
    file_basename = path.basename(file)
    file_fun = moonscript.loadfile(file)
    if not file_fun
      log.warn("No result parsing " .. file)
      return
    new_env = {}
    for key, value in pairs env
      new_env[key] = (cfg) -> value(cfg, file_basename, file_path)
    new_env.state = @state
    utils.setfenv(file_fun, new_env)
    try
      do: ->
        file_fun!
      catch: (e) ->
        log.error("Error Loading config file: " .. file .. ": " .. e)
        anal_mode = true --- @TODO
        if (anal_mode)
          log.fatal("Anal mode exit")
          utils.quit("Anal exit")
      finally: ->
        log.trace("Loaded File: " .. file)

--public:

  ---
  -- Load only the files at this level of the directory structure.
  -- @param content_dir_path
  -- @param env environment to execute the files in
  load_files: (content_dir_path, env) =>
    assert(content_dir_path)
    assert(env)
    --- @TODO this patterns don't work
    --files = dir.getfiles(content_dir_path, "@(*.moon|*.lua)")
    files = dir.getfiles(content_dir_path, "*.moon")
    for file in *files
      filePath = path.join(content_dir_path, file)
      @load_cfg_file(filePath, env)

  ---
  -- Load each and every file in the given path.
  -- @param content_dir_path root path to load from
  -- @param env environment to run the file loader with
  load_all_files: (content_dir_path, env) =>
    assert(content_dir_path)
    assert(env)
    log.trace("Loading all files in: " .. content_dir_path)
    iter = dir.walk(content_dir_path, false, false)
    helper = (root, dirs, files) ->
      log.trace(root)
      --- @TODO this patterns don't work
      --for file in *dir.filter(files, "@(*.moon|*.lua)")
      for file in *dir.filter(files, "*.moon")
        filepath = path.join(root, file)
        @load_cfg_file(filepath, env)
    seq = require("pl.seq").foreach(iter, helper)

  ---
  -- loads a WesMod by path
  -- @param wesmod_path string
  load_wesmod_by_path: (wesmod_path) =>
    log.info("Loading WesMod at: " .. wesmod_path)
    -- Note: order matters
    -- knowns = { "Eras", "Help", "Tips", "WesMods" }
    knowns = { "WML", "Mechanics", "Terrains", "Units", "Scenarios" }
    found = ""
    for folder in *knowns
      folder_path = path.join(wesmod_path, folder)
      if not path.exists(folder_path)
        continue
      found ..= folder .. " "
      env = @state.ENV.folders[folder]
      @load_all_files(folder_path, env)
    log.trace("Found: " .. found)
    -- loading root of the wesmod
    env = @state.ENV.folders.WesMods
    @load_files(wesmod_path, env)
    return true

  scan_root: (root_path) =>
    env = @state.ENV.on_scan
    log.info("Scanning root: " .. root_path)
    @load_all_files(root_path, env)

  ---
  -- Constructor @TODO
  -- @param data_dir
  -- @param userdata_dir
  -- @param config_dir
  new: (data_dir, userdata_dir, config_dir) =>
    -- @core_loaded = false
    -- @core_loaded = true --- @TODO
    @state =
      ENV: -- holds tables being used as env
        on_scan:
          wml_config: (cfg) -> @state.WesMods.wml_tags[cfg.name] = true
        folders: -- envs for wesmod content folders
          Mechanics: {}
          Terrains: {}
          WesMods: {}
          Units: {}
          Help: {}
          Scenarios: {}
          --- @TODO think about same name but different scopes
          --  Which currently just overwrites the on_scan function
          WML:
            wml_config: (cfg) ->
              assert(cfg.name, "no name")
              assert(cfg.on_load, "no on_load")
              @state.ENV.folders[cfg.scope][cfg.name] = cfg.on_load
              if cfg.on_scan
                @state.ENV.on_scan[cfg.name] = cfg.on_scan
              else
                @state.ENV.on_scan[cfg.name] = (cfg) -> return
        action: {} -- the env for event handlers
        command: {} -- is it an env? at least a collenction of functions
      Mechanics: -- used by Kernel execution
        actions: {} -- direct kernel access
        commands: {}
      -- Help should have no dependencies at load level
      -- At build level it needs nearly everything
      Help:
        toplevel: {}
        topics: {}
        sections: {}
      Terrains:
        terrain_types: {}
        -- terrain_graphics: {}
      Units:
        -- movetypes ---> terrain_types
        movetypes: {}
        races: {}
        traits: {}
        -- unit_types ---> movetypes, races, traits
        unit_types: {}
      WesMods:
        roots: {}
        campaigns: {}
        eras: {}
        game_cores: {}
        scenarios: {}
        wml_tags: {}
      Eras:
        factions: {}
        eras: {}
      Scenarios: {}

    -- root must be loaded first or only wml_config function is known.
    if data_dir
      @load_wesmod_by_path(data_dir)
      -- moon.p(@)
      @scan_root(data_dir)
      moon.p(@)
    else
      log.fatal("no data dir")
      utils.quit("no data dir")
    -- if userdata_dir
    --   @scan_root(userdata_dir)
    --@kernel = require("Kernel/MoonScript/Kernel")!
    --@kernel\init(@state)

  debug: =>
    moon.p(@state.Scenarios)
    --@kernel\fire_event("test")
    --@kernel\debug!

  register_action: (cfg) =>
    env =
      kernel: @kernel
    utils.setfenv(cfg.command, @content_state.actions)
    assert(cfg.name)
    if not @game_state.events[cfg.name]
      @game_state.events[cfg.name] = {}
    table.insert(@game_state.events[cfg.name], cfg)

  ---
  -- @TODO
  -- @param id
  -- @param cfg
  start_scenario: (id, cfg) =>
    assert(id, "Missing first arguement")
    scenario = @state.scenarios[id]
    @kernel\start(scenario)

  ---
  -- Load a WesMod by its id
  -- @param id of the WesMod to load
  load_wesmod: (id) =>
    assert(id)
    mod = @state.WesMods[id]
    if not mod
      log.error("Can't load, WesMod not registered: " .. id)
      return false
    assert(mod)
    if mod.loaded
      log.warn("WesMod " .. id .. " already loaded")
      return false
    -- @TODO
    -- if (not @core_loaded) and mod.type != "core"
    --   log.error("WesMod " .. id .. " can't load, core needed")
    --   return false
    mod_path = mod.path
    mod.loaded = @load_wesmod_by_path(mod_path)
    switch mod.type
      when nil
        log.warn("WesMod of type nil")
      when "scenario"
        @kernel\load_scenario(mod_path)
      when "campaign"
        log.debug("Loading campaign: " .. id)
      else
        log.debug("Loading some type: " .. mod.type .. " with " .. id)

return Game
