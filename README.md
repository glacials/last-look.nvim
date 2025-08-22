# last-look.nvim

A Neovim plugin that shows a visual diff
any time `:q` is called with unsaved changes.

![A screenshot of a side-by-side diff in Neovim between a buffer and its respective file on disk.](.github/screenshot.png)

The diff is between your buffer and the file on disk.

## Install

### lazy.nvim

```lua
{ "glacials/last-look.nvim" }
```

### packer.nvim

```lua
use { "glacials/last-look.nvim" }
```

## Commands

-   `:LastLook` — manually run the guard and then quit
