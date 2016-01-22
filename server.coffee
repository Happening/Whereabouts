Db = require 'db'
App = require 'app'
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

exports.client_newPlaceToBe = (latlong, message='') !->
	log "[newPlaceToBe] latlong="+latlong+", message="+message
	Timer.cancel 'placeToBeTimeout', {}
	if App.userIsAdmin(App.userId()) or (Db.shared.get('placetobe', 'time')||0) < (App.time()-3600) or Db.shared.get('placetobe', 'placer')+"" is App.userId()+""
		Db.shared.set 'placetobe',
			latlong: latlong
			message: message
			time: App.time()
			placer: App.userId()
		# Send notification
		users = []
		for user in App.userIds()
			users.push user
		Event.create
			unit: 'newPlaceToBe'
			include: users
			text: "Place to be set by "+App.userName(App.userId())+(if message then ": "+message else '')
		Timer.set 1000*60*60*12, 'placeToBeTimeout', {} # Remove after 12 hours
	else
		log "cancelled"

# Remove the place to be
exports.client_removePlaceToBe = !->
	log "[removePlaceToBe] trying place to be remove"
	if App.userIsAdmin(App.userId()) or (Db.shared.get('placetobe', 'time')||0) < (App.time()-3600) or Db.shared.get('placetobe', 'placer')+"" is App.userId()+""
		log "removed"
		Db.shared.remove 'placetobe'
		Timer.cancel 'placeToBeTimeout', {}

# Remove placeToBe (used for timer)
exports.placeToBeTimeout = !->
	log "[placeToBeTimeout] removed"
	Db.shared.remove 'placetobe'
