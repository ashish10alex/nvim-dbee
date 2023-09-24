local Drawer = require("dbee.drawer")
local Editor = require("dbee.editor")
local Result = require("dbee.result")
local CallLog = require("dbee.call_log")
local Ui = require("dbee.ui")
local Handler = require("dbee.handler")
local install = require("dbee.install")
local utils = require("dbee.utils")
local default_config = require("dbee.config").default

-- public and private module objects
local M = {}
local m = {}

-- is the ui open?
m.open = false
-- is the plugin loaded?
m.loaded = false
---@type Config
m.config = {}

local function lazy_setup()
  -- add install binary to path
  vim.env.PATH = install.path() .. ":" .. vim.env.PATH

  -- set up UIs
  local result_ui = Ui:new {
    window_command = m.config.ui.window_commands.result,
    window_options = {
      wrap = false,
      winfixheight = true,
      winfixwidth = true,
      number = false,
    },
    quit_handle = function()
      m.close("result")
    end,
  }
  local editor_ui = Ui:new {
    window_command = m.config.ui.window_commands.editor,
    quit_handle = function()
      m.close("editor")
    end,
  }
  local drawer_ui = Ui:new {
    window_command = m.config.ui.window_commands.drawer,
    buffer_options = {
      buflisted = false,
      bufhidden = "delete",
      buftype = "nofile",
      swapfile = false,
    },
    window_options = {
      wrap = false,
      winfixheight = true,
      winfixwidth = true,
      number = false,
    },
    quit_handle = function()
      m.close("drawer")
    end,
  }
  local call_log_ui = Ui:new {
    window_command = m.config.ui.window_commands.call_log,
    buffer_options = {
      buflisted = false,
      bufhidden = "delete",
      buftype = "nofile",
      swapfile = false,
    },
    window_options = {
      wrap = false,
      winfixheight = true,
      winfixwidth = true,
      number = false,
    },
    quit_handle = function()
      m.close("call_log")
    end,
  }

  -- set up modules
  m.handler = Handler:new(m.config.sources)
  m.result = Result:new(result_ui, m.handler, m.config.result)
  m.call_log = CallLog:new(call_log_ui, m.handler, m.result, m.config.call_log)
  m.editor = Editor:new(editor_ui, m.handler, m.result, m.config.editor)
  m.drawer = Drawer:new(drawer_ui, m.handler, m.editor, m.result, m.config.drawer)

  m.handler:helpers_add(m.config.extra_helpers)
end

---@return boolean ok was setup successful?
local function pcall_lazy_setup()
  if m.loaded then
    return true
  end

  local ok, mes = pcall(lazy_setup)
  if not ok then
    utils.log("error", tostring(mes), "init")
    return false
  end

  m.loaded = true
  return true
end

---@param opts Config
local function validate_config(opts)
  vim.validate {
    sources = { opts.sources, "table" },
    lazy = { opts.lazy, "boolean" },
    extra_helpers = { opts.extra_helpers, "table" },
    -- submodules
    drawer_disable_candies = { opts.drawer.disable_candies, "boolean" },
    drawer_disable_help = { opts.drawer.disable_help, "boolean" },
    drawer_candies = { opts.drawer.candies, "table" },
    drawer_mappings = { opts.drawer.mappings, "table" },
    result_page_size = { opts.result.page_size, "number" },
    result_progress = { opts.result.progress, "table" },
    result_mappings = { opts.result.mappings, "table" },
    editor_mappings = { opts.editor.mappings, "table" },
    call_log_mappings = { opts.call_log.mappings, "table" },

    -- ui
    ui_window_commands_drawer = { opts.ui.window_commands.drawer, { "string", "function" } },
    ui_window_commands_result = { opts.ui.window_commands.result, { "string", "function" } },
    ui_window_commands_editor = { opts.ui.window_commands.editor, { "string", "function" } },
    ui_window_commands_call_log = { opts.ui.window_commands.call_log, { "string", "function" } },
    ui_window_open_order = { opts.ui.window_open_order, "table" },
    ui_pre_open_hook = { opts.ui.pre_open_hook, "function" },
    ui_post_open_hook = { opts.ui.post_open_hook, "function" },
    ui_pre_close_hook = { opts.ui.pre_close_hook, "function" },
    ui_post_close_hook = { opts.ui.post_close_hook, "function" },
  }
end

---@param o Config
function M.setup(o)
  o = o or {}
  ---@type Config
  local opts = vim.tbl_deep_extend("force", default_config, o)
  -- validate config
  validate_config(opts)

  m.config = opts

  if m.config.lazy then
    return
  end
  pcall_lazy_setup()
end

---@param params connection_details
---@param source_id source_id id of the source to save connection to
function M.add_connection(params, source_id)
  if not pcall_lazy_setup() then
    return
  end
  m.handler:add_connection(params, source_id)
end

function M.toggle()
  if m.open then
    M.close()
  else
    M.open()
  end
end

function M.open()
  if not pcall_lazy_setup() then
    return
  end
  if m.open then
    utils.log("warn", "already open")
    return
  end

  m.config.ui.pre_open_hook()

  local order_map = {
    drawer = m.drawer,
    result = m.result,
    editor = m.editor,
    call_log = m.call_log,
  }

  for _, u in ipairs(m.config.ui.window_open_order) do
    local ui = order_map[u]
    if ui then
      ui:open()
    end
  end

  m.config.ui.post_open_hook()
  m.open = true
end

---@param exclude? "result"|"editor"|"drawer"|"call_log"
function m.close(exclude)
  if not m.open or not pcall_lazy_setup() then
    return
  end

  m.config.ui.pre_close_hook()

  if exclude ~= "result" then
    m.result:close()
  end
  if exclude ~= "drawer" then
    m.drawer:close()
  end
  if exclude ~= "editor" then
    m.editor:close()
  end
  if exclude ~= "call_log" then
    m.call_log:close()
  end

  m.config.ui.post_close_hook()
  m.open = false
end

function M.close()
  m.close()
end

function M.next()
  if not pcall_lazy_setup() then
    return
  end
  m.result:page_next()
end

function M.prev()
  if not pcall_lazy_setup() then
    return
  end
  m.result:page_prev()
end

---@param query string query to execute on currently selected connection
function M.execute(query)
  if not pcall_lazy_setup() then
    return
  end

  local conn = m.handler:get_current_connection()
  if not conn then
    error("no current connection")
  end

  local call = m.handler:connection_execute(conn.id, query)
  m.result:set_call(call)
end

---@param format "csv"|"json"|"table" format of the output
---@param output "file"|"yank"|"buffer" where to pipe the results
---@param opts { from: integer, to: integer, extra_arg: any } argument for specific format/output combination - example file path or buffer number
function M.store(format, output, opts)
  if not pcall_lazy_setup() then
    return
  end
  --- TODO: fix this on refactor
  ---@diagnostic disable-next-line
  local current_call = m.result.current_call
  m.handler:call_store_result(current_call.id, format, output, opts)
end

---@param command? install_command preffered command
function M.install(command)
  install.exec(command)
end

-- experimental and subject to change!
M.api = m

return M
