# last-look.nvim

> Don’t quit without a last look.

last-look.nvim improves the quit-with-unsaved-changes experience of Neovim.
Now when you quit, you will be shown the diff between the file on disk and the file in your buffer.

No keybinds, no configuration.

A Neovim plugin that intercepts `:q`
to protect you from rage-quitting unsaved buffers.

When you try to quit with any unsaved buffers,
you are shown the diff between the buffer and the file on disk.
From there, you can decide to save, discard, or cancel.

## Install

### lazy.nvim

```lua
{ "glacials/last-look.nvim" }
```

### packer.nvim

use { "glacials/last-look.nvim" }

## Commands

-   `:LastLook` — run the guard manually
-   `:lua require('last-look').diff_orig()` — open the diff manually
