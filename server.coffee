Db = require 'db'
Plugin = require 'plugin'
Timer = require 'timer'
Event = require 'event'
Http = require 'http'
Geoloc = require 'geoloc'

# ==================== Events ====================
# Game install
exports.onInstall = !->
	log "Installed"

# Game update
exports.onUpgrade = !->
	log '[onUpgrade()] at '+new Date()