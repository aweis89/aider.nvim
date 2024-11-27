# nvim-aider

A Neovim plugin for seamless integration with [Aider](https://github.com/paul-gauthier/aider), an AI pair programming tool.

## Features

- Toggle Aider terminal window
- Load files into Aider session
- Ask questions about code with visual selection support
- Integration with fzf-lua for file selection
- Maintains persistent Aider sessions

## Prerequisites

- Neovim 0.5+
- [Aider](https://github.com/paul-gauthier/aider) installed (`pip install aider-chat`)
- [fzf-lua](https://github.com/ibhagwan/fzf-lua) (optional, for enhanced file selection)

## Installation

Using [lazy.nvim](https://github.com/folke/lazy.nvim):

```lua
{
    "aweis89/aider.nvim",
    dependencies = {
        "ibhagwan/fzf-lua",
    },
    init = function()
        require("aider").setup()
    end,
    keys = {
        {
            "<leader>a<space>",
            "<cmd>AiderToggle<CR>",
            desc = "Toggle Aider",
        },
        {
            "<leader>al",
            "<cmd>AiderLoad<CR>",
            desc = "Add file to aider",
        },
        {
            "<leader>ad",
            "<cmd>AiderAsk<CR>",
            desc = "Ask with selection",
            mode = { "v", "n" },
        },
    },
}
```

## Commands

- `:AiderToggle` - Toggle the Aider terminal window
- `:AiderLoad [files...]` - Load files into Aider session
- `:AiderAsk` - Ask a question about code (works in visual mode)

## Suggested Keymaps

Here are some suggested keymaps you can add to your lazy.nvim configuration:

```lua
keys = {
    {
        "<leader>a<space>",
        "<cmd>AiderToggle<CR>",
        desc = "Toggle Aider",
    },
    {
        "<leader>al",
        "<cmd>AiderLoad<CR>",
        desc = "Add file to aider",
    },
    {
        "<leader>ad",
        "<cmd>AiderAsk<CR>",
        desc = "Ask with selection",
        mode = { "v", "n" },
    },
}
```

## FZF-lua Integration

When fzf-lua is installed, you can use `Ctrl-l` in the file picker to load files into Aider:

- Single file: Navigate to a file and press `Ctrl-l` to load it into Aider
- Multiple files: Use `Shift-Tab` to select multiple files, then press `Ctrl-l` to load all selected files
- The files will be automatically added to your current Aider session if one exists, or start a new session if none is active

## Configuration

The plugin can be configured during setup:

```lua
require('aider').setup({
    -- Override the default editor command (defaults to 'tmux popup -E nvim' in tmux)
    editor_command = 'your-custom-editor-command',
    
    -- Change the FZF action key (defaults to 'ctrl-l')
    fzf_action_key = 'ctrl-x',

    -- Set default arguments for aider CLI
    aider_args = '--model gpt-4 --dark-mode --no-auto-commits'
})
```

### Editor Command Behavior

When running in a tmux session, the plugin automatically sets `AIDER_EDITOR` to use a tmux popup with Neovim by default. This provides a better experience than the default `/editor` command, which can have issues when running nested Neovim sessions in terminal mode. You can override this behavior by setting `editor_command` in the setup options.

The default FZF action key is `ctrl-l`, but this can be customized using the `fzf_action_key` option during setup.

## Usage Examples

1. Toggle Aider window:
```vim
:AiderToggle
```

2. Load current file into Aider:
```vim
:AiderLoad
```

3. Load specific files:
```vim
:AiderLoad path/to/file1.lua path/to/file2.lua
```

4. Ask about code:
   - Select code in visual mode
   - Run `:AiderAsk`
   - Enter your prompt
   - Aider will respond in the terminal window

## License

MIT
