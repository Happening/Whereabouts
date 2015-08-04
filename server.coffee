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

# Get background location from player.
exports.onGeoloc = (userId, geoloc) !->
	log '[onGeoloc()] Geoloc from ' + Plugin.userName(userId) + '('+userId+'): ', JSON.stringify(geoloc)
	updateLocation(userId, geoloc.latitude+","+geoloc.longitude, geoloc.accuracy, geoloc.time)

# Update a location of a client in the database
updateLocation = (userId, latlong, accuracy, time) !->
	Timer.cancel 'locationTimeout', {userId: userId}
	return if !latlong
	currentTime = new Date()/1000
	time = currentTime if !(time?)
	time = currentTime if time>currentTime
	Db.shared.set "locations", userId, "lastUpdate", time
	Db.shared.set "locations", userId, "latlong", latlong
	if accuracy?
		Db.shared.set "locations", userId, "accuracy", accuracy
	Timer.set 1000*60*60*2, 'locationTimeout', {userId: userId}

# Checkin location for capturing a beacon
exports.client_checkinLocation = (location, accuracy, timestamp) !->
	userId = Plugin.userId()
	log '[checkinLocation()] from ' + Plugin.userName(userId) + '('+userId+'): ', location + ", accuracy="+accuracy+", time="+timestamp
	updateLocation(userId, location, accuracy, timestamp)

# Request to update all locations
exports.client_update = !->
	lastRequest = Db.shared.peek('lastBackgroundUpdate') ? 0
	now = new Date()/1000
	if now-lastRequest > 60
		Db.shared.set 'lastBackgroundUpdate', now
		userIds = []
		for userId in Plugin.userIds()
			userIds.push userId
		result = Geoloc.request(userIds)
		log 'Updating: self=', userIds, "actually=", result

# Called after a certain time to remove an old location
## args.userId
exports.locationTimeout = (args) !->
	if args.userId and args.userId?
		Db.shared.remove "locations", args.userId
		log "[locationTimeout()] "+Plugin.userName(args.userId)+" ("+args.userId+") removed (timeout)"
