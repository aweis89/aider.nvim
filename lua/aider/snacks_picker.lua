M = {}

---@param selected snacks.picker.Item[]
local function selected_files(selected)
  local files = {}
  for _, s in ipairs(selected) do
    table.insert(files, s.file)
  end
  return files
end


---@param cmd string|table
---@param opts? table
---@param on_exit? fun(out: vim.SystemCompleted) Called when subprocess exits. When provided, the command runs
local function system(cmd, opts, on_exit)
  if type(cmd) == "string" then
    cmd = vim.split(cmd, " ")
  end

  vim.notify(table.concat(cmd, " "))
  vim.system(cmd, opts, on_exit)
end

---@param opts snacks.picker.Config
---@type snacks.picker.finder
local function git_stash_finder(opts, ctx)
  local stash_msg_prefix = require("aider.aider").StashMsgPrefix
  local args = {
    "stash", "list",
    "--grep-reflog", stash_msg_prefix,
  }
  return require("snacks.picker.source.proc").proc({
    opts,
    {
      cmd = "git",
      args = args,
      ---@param item snacks.picker.finder.Item
      transform = function(item)
        local stash = item.text:match("^stash@{(%d+)}")
        local message = item.text:match("^stash@{%d+}: %s*(.+)$")
        local prompt = string.sub(message, #stash_msg_prefix + 1)
        item.stash = stash
        item.prompt = vim.trim(prompt)
      end,
    },
  }, ctx)
end

function M.aider_changes()
  local ok, picker = pcall(require, "snacks.picker")
  if not ok then
    return nil
  end
  return picker("aider_history", {
    title = "Aider History",
    finder = git_stash_finder,
    format = function(item, p)
      return { { string.format("#%d ", item.idx), "Function" }, { item.prompt } }
    end,
    preview = function(ctx)
      local stash = ctx.item.stash
      local cmd = {
        "git",
        "-c",
        "delta." .. vim.o.background .. "=true",
        "diff",
        string.format("stash@{%d}..stash@{%d}", stash, stash + 1),
      }
      local native = ctx.picker.opts.previewers.git.native
      if not native then
        table.insert(cmd, 2, "--no-pager")
      end
      Snacks.picker.preview.cmd(cmd, ctx, {
        ft = not native and "git" or nil
      })
      ctx.preview:show(ctx.picker)
      return false
    end,
    win = {
      input = {
        keys = {
          ["<CR>"] = "apply",
          ["<C-r>"] = "reverse",
        },
      }
    },
    actions = {
      apply = function(p)
        local item = p:current()
        if item and item.stash then
          p:close()
          system("git stash apply " .. item.stash)
        end
      end,
      reverse = function(p)
        local item = p:current()
        if item and item.stash then
          p:close()
          local target_stash = item.stash - 1
          system("git stash apply " .. target_stash)
        end
      end,
      pop = function(p)
        local item = p:current()
        if item and item.stash then
          p:close()
          system("git stash pop " .. item.stash)
        end
      end,
      drop = function(p)
        local item = p:current()
        if item and item.stash then
          p:close()
          system("git stash drop " .. item.stash)
        end
      end,
    }
  })
end

---@param sopts AiderConfig
function M.setup(sopts)
  local ok, snacks_picker = pcall(require, "snacks.picker")
  if not ok then
    return
  end

  local actions = snacks_picker.actions
  actions.aider_add = function(picker)
    picker:close()
    local files = selected_files(picker:selected({ fallback = true }))
    require("aider.terminal").add(files)
  end

  actions.aider_read_only = function(picker)
    picker:close()
    local files = selected_files(picker:selected({ fallback = true }))
    require("aider.terminal").read_only(files)
  end

  actions.aider_drop = function(picker)
    picker:close()
    local files = selected_files(picker:selected({ fallback = true }))
    require("aider.terminal").drop(files)
  end
end

return M
