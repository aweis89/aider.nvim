local config = require("aider").config

if config.use_toggleterm then
  return require("aider.toggleterm")
end

return require("aider.snacksterm")
