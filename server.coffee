Db = require 'db'
Plugin = require 'plugin'
Timer = require 'timer'
Event = require 'event'
Http = require 'http'
Geoloc = require 'geoloc'

# install
exports.onInstall = !->
	log "Installed"

# update
exports.onUpgrade = !->
	log '[onUpgrade()] at '+new Date()

exports.client_newPlaceToBe = (latlong, message) !->
	log "[newPlaceToBe] latlong="+latlong+", message="+message
	Timer.cancel 'placeToBeTimeout', {}
	if Plugin.userIsAdmin(Plugin.userId()) or (Db.shared.get('placetobe', 'time')||0) < (Plugin.time()-3600) or Db.shared.get('placetobe', 'placer')+"" is Plugin.userId()+""
		Db.shared.set 'placetobe',
			latlong: latlong
			message: message
			time: Plugin.time()
			placer: Plugin.userId()
		# Send notification
		users = []
		for user in Plugin.userIds()
			users.push user
		Event.create
			unit: 'newPlaceToBe'
			include: users
			text: "Place to be by "+Plugin.userName(Plugin.userId())+": "+message
		Timer.set 1000*60*60*12, 'placeToBeTimeout', {} # Remove after 12 hours
	else
		log "cancelled"

# Remove the place to be
exports.client_removePlaceToBe = !->
	log "[removePlaceToBe] trying place to be remove"
	if Plugin.userIsAdmin(Plugin.userId()) or (Db.shared.get('placetobe', 'time')||0) < (Plugin.time()-3600) or Db.shared.get('placetobe', 'placer')+"" is Plugin.userId()+""
		log "removed"
		Db.shared.remove 'placetobe'
		Timer.cancel 'placeToBeTimeout', {}

# Remove placeToBe (used for timer)
exports.placeToBeTimeout = !->
	log "[placeToBeTimeout] removed"
	Db.shared.remove 'placetobe'
