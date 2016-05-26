fs = require "fs"
path = require "path"
mongoose = require "mongoose"

envConfig = null
envConfigFilePath = path.join __dirname, "../env_config.json"
envConfigDefaultFilePath = path.join __dirname, "../env_config_default.json"

if fs.existsSync envConfigFilePath
  envConfig = JSON.parse fs.readFileSync envConfigFilePath
else
  console.log "warning! #{envConfigFilePath} is not exist, use default settings"
  envConfig = JSON.parse fs.readFileSync envConfigDefaultFilePath

mongoose.connect envConfig.dbUrl, envConfig.dbOptions

module.exports = mongoose
