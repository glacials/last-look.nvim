-- Auto-enable with defaults unless user already called setup()
pcall(function()
  if vim.g.loaded_last_look_autoload then return end
  vim.g.loaded_last_look_autoload = true
  require('last-look').setup()
end)
