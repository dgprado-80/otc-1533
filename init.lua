-- this is the first file executed when the application starts
-- we have to load the first modules form here

-- Updates are installed by BestServerOt.exe. The game does not call the file updater.
-- login-new.php also answers eventschedule and boostedcreature for the login screen.
-- devserver.flag keeps this machine on the local game login.
Services = {
    status = "https://bestserverot.com.br/login-new.php"
}

--- Enables or disables the entire server configuration block.
-- Set to `false` to disable all configuration below.
local ENABLE_SERVERS = true

---
-- @module Servers_init
-- Configuration table for all servers used by the system.
--
-- This entire block is conditionally enabled based on ENABLE_SERVERS.
-- When ENABLE_SERVERS == false, everything is ignored/disabled.
--

---
-- Server configuration system for multi-server or multi-world clients.
--
-- This structure allows a single client build to connect to multiple servers
-- without requiring duplicate client folders.
--
-- A server that hosts several worlds, or that provides a separate test environment,
-- can simply define additional entries inside this configuration table.
--
-- Instead of maintaining multiple client installations (one per world/server),
-- the client can switch between servers by selecting the desired configuration entry.
-- This simplifies testing, avoids redundant directories, and centralizes connection settings.
--
-- The ENABLE_SERVERS flag allows the entire configuration block to be enabled or disabled
-- without deleting or commenting out individual entries.
--

Servers_init = {}

-- Inside LDPlayer, 127.0.0.1 is the Android guest. The Windows host is the NAT address.
local function localServerHost()
    if g_platform.isMobile() then
        return "10.0.2.2"
    end
    return "127.0.0.1"
end

if ENABLE_SERVERS then

    ---
    -- List of servers and their configuration parameters.
    -- Each entry defines port, protocol, and authentication options.
    -- @table Servers_init
    --
    -- DEV (devserver.flag next to the exe): localhost ONLY - no background requests to the
    -- release endpoint. Release (no flag) = the production login below.
    if g_resources.fileExists("/devserver.flag") then
        Servers_init = {
            ["http://" .. localServerHost() .. "/login.php"] = {
                port = 80,
                protocol = 1530,
                httpLogin = true,
                useAuthenticator = false
            }
        }
    else
        Servers_init = {
            ["https://bestserverot.com.br/login-new.php"] = {
                port = 443,
                protocol = 1530,
                httpLogin = true,
                useAuthenticator = false
            }
        }
    end
end

g_app.setName("BestserverOt");
g_app.setCompactName("crystalotc");
g_app.setOrganizationName("Bestserver");

-- Server aligned to crystalserver main 15.30 (PR #1103 Winter removed). Assets: data/things/1530.
g_gameConfig.setLastSupportedVersion(1530)

g_app.hasUpdater = function()
    return (Services.updater and Services.updater ~= "" and g_modules.getModule("updater"))
end

-- setup logger
g_logger.setLogFile(g_resources.getWorkDir() .. g_app.getCompactName() .. '.log')
g_logger.info(os.date('== application started at %b %d %Y %X'))
g_logger.info("== operating system: " .. g_platform.getOSName())

-- print first terminal message
g_logger.info(g_app.getName() .. ' ' .. g_app.getVersion() .. ' rev ' .. g_app.getBuildRevision() .. ' (' ..
    g_app.getBuildCommit() .. ') built on ' .. g_app.getBuildDate() .. ' for arch ' ..
    g_app.getBuildArch())

-- setup lua debugger
if os.getenv("LOCAL_LUA_DEBUGGER_VSCODE") == "1" then
    require("lldebugger").start()
    g_logger.debug("Started LUA debugger.")
else
    g_logger.debug("LUA debugger not started (not launched with VSCode local-lua).")
end

-- Try to add on-disk data/, modules/, mods/ to the search path.
-- These calls return false (without crashing) when the directory does not
-- physically exist on disk. With the embedded assets.pak mounted at "/" via
-- PHYSFS_mountMemory the corresponding subtrees come from inside the exe, so
-- a missing on-disk folder is not fatal — only the absence of BOTH the embed
-- and the on-disk folder would be a real problem, and that surfaces later
-- when a module fails to load.
g_resources.addSearchPath(g_resources.getWorkDir() .. 'data', true)
g_resources.addSearchPath(g_resources.getWorkDir() .. 'modules', true)

g_html.addGlobalStyle('/data/styles/html.css')
g_html.addGlobalStyle('/data/styles/custom.css')

g_resources.addSearchPath(g_resources.getWorkDir() .. 'mods', true)

-- setup directory for saving configurations
g_resources.setupUserWriteDir(('%s/'):format(g_app.getCompactName()))

-- search all packages
g_resources.searchAndAddPackages('/', '.otpkg', true)

-- load settings
g_configs.loadSettings('/config.otml')

g_modules.discoverModules()

-- libraries modules 0-99
g_modules.autoLoadModules(99)
g_modules.ensureModuleLoaded('corelib')
g_modules.ensureModuleLoaded('gamelib')
g_modules.ensureModuleLoaded('modulelib')
g_modules.ensureModuleLoaded("startup")

g_modules.autoLoadModules(999)
g_modules.ensureModuleLoaded('game_shaders') -- pre load

local function loadModules()
    -- client modules 100-499
    g_modules.autoLoadModules(499)
    g_modules.ensureModuleLoaded('client')
    g_modules.ensureModuleLoaded('client_terminal')

    -- game modules 500-999
    g_modules.autoLoadModules(999)
    g_modules.ensureModuleLoaded('game_interface')

    -- mods 1000-9999
    g_modules.autoLoadModules(9999)
    g_modules.ensureModuleLoaded('client_mods')

    local script = '/' .. g_app.getCompactName() .. 'rc.lua'

    if g_resources.fileExists(script) then
        dofile(script)
    end

    -- uncomment the line below so that modules are reloaded when modified. (Note: Use only mod dev)
    -- g_modules.enableAutoReload()
end

-- run updater, must use data.zip
if g_app.hasUpdater() then
    g_modules.ensureModuleLoaded("updater")
    return Updater.init(loadModules)
end

loadModules()
