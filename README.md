# auto-header.nvim
A neovim plugin to automatically create and update code file headers inspired by the Psioniq File Header extension for Visual Studio (https://github.com/davidquinn/psi-header).

## Features
Manually, or automatically when saving a file, this module creates or updates the header according to a template and variables defined by the current project. The configuration is done at two levels:

### Global configuration

First globally, to define the behaviour of the application no matter on which project you are currently working on:

```lua
require("auto-header").setup({
    -- if true, a header will automatically be added when a file is first saved
    create = true,  
    -- if true, some fields of the existing header will be updated
    update = true,  
    -- languages for which the plugin is enabled. To enable it to all files, add "*"
    languages = { "cpp", "python", "bash", "rust", "lua" }, 
    -- The keybinding to use (in normal mode only) that will add or refresh the header
    key = "<leader>ah",
    -- The templates to use to create the headers, one by language ("*" will be used if no specific one was found)
    -- The language is determined by neovim’s buffer filetype.
    templates = {
        {
            -- The language for which this template applies
            language = "*",
            -- The prefix of each line of the header ("auto" is allowed, the buffer’s commentstring will then be used)
            prefix = "--",
            -- If block and block_length are both set, the header will take the form of a block
            block = "-",
            block_length = 0,
            -- Lines to add before the header
            before = {},
            -- Lines to add after the header
            after = { "" },
            -- The comment lines of the buffer
            -- Some fields preceded by # will be set if known or given
            template = {
                "File: #file_relative_path",
                "Project: #project_name",
                "Creation date: #date_now",
                "Author: #author_name <#author_mail>",
                "-----",
                "Last modified: #date_now",
                "Modified By: #author_name",
                "-----",
                module.licenes.MIT
            },
            -- All the lines beginning with these patterns will be updated
            track_change = {
                "File: ",
                "Last modified: ",
                "Modified By: ",
                "Copyright ",
            },
        }
    },
})

```

The fields "#field" can come from two places: they are either defined in the data fields of the projects’ configurations, or they are special ones that are determined automatically (if possible).
author_name and author_mail can be set from the current git’s repository values.

Note that the module stores the text of a few licenses:

- Apache-2.0
- GPL-2.0
- GPL-3.0
- ISC
- MIT

To use them in you header, just use:
```lua
require("auto-header").licenses.MIT
```

### Project Configuration

Projects configuration has precedence over the global configuration regarding the create / update and templates values. On top of those, they also define a few more important values:

```lua
    projects = {
        {
            project_name = "Vincent’s projects",
            root = "/home/vincent/code/",
            create = true,
            update = true,
            data = {
                cp_holders = "Vincent Berthier",
                author_mail = "my.email@isp.com",
            },
        },
        {
            project_name = "auto-header.nvim",
            root = "/home/vincent/code/auto-header.nvim",
            create = false,
            update = true,
            template = {
                "File: #file_relative_path",
                "Project: #project_name",
                "Creation date: #date_now",
                "Author: #author_name",
                "-----",
                "Last modified: #date_now",
                "Modified By: #author_name",
                "-----",
                headers.licenses.MIT,
            },
            data = {
                cp_holders = "Vincent Berthier",
                author_mail = ""
            }
        }
    }
```

In there, you can define special templates (non-language specific), and more importantly, the data dictionnary holds all the values that will be used to populate you templates.
You can put anything you want in there, the values of all the keys will replace #key markers in the templates.

Note that if you change the template of your headers and try to update an existing header, auto-header will try to recognize it and abort. No guarantees though, so be careful!

