Db = require 'db'
Time = require 'time'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
Server = require 'server'
Ui = require 'ui'
Geoloc = require 'geoloc'
Form = require 'form'
Icon = require 'icon'
Toast = require 'toast'
Event = require 'event'
Photo = require 'photo'
Map = require 'map'
{tr} = require 'i18n'
# Plugin files
CSS = require 'css'

# ========== Events ==========
# Main function, called when plugin is started
exports.render = !->
	log 'FULL RENDER'
	Obs.onClean !->
		log 'FULL CLEAN'
	# Request a background location update for the other users
	Server.sync 'update'
	Dom.div !->
		Dom.style
			position: "absolute"
			top: "0"
			right: "0"
			bottom: "0"
			left: "0"
		# Map view
		Obs.observe !->
			renderMap()
	Dom.div !->
		Dom.style
			position: "absolute"
			top: "0"
			left: "0"
			right: "0"
		# Enable/disable location sharing bar
		Obs.observe !->
			if !Geoloc.isSubscribed()
				Dom.style
					width: "100%"
					zIndex: "10000"
					color: '#666'
					padding: '0'
					fontSize: '16px'
					boxSizing: 'border-box'
					backgroundColor: '#FFF'
					_alignItems: 'center'
					borderBottom: '1px solid #ccc'
				Dom.div !->
					Dom.style
						Box: 'horizontal'
					Dom.div !->
						Dom.style
							width: '30px'
							height: "30px"
							padding: "10px 5px 10px 5px"
						Icon.render data: 'map', color: Plugin.colors().highlight, style: {position: "static", margin: "0"}, size: 30
					Dom.div !->
						Dom.style
							Flex: true
							padding: "8px 0 5px 0"
						Dom.text tr("Tap to share your location")
						Dom.div !->
							Dom.style
								fontSize: "75%"
							Dom.text "Currently others cannot see your location"
				Dom.onTap !->
					Geoloc.subscribe()

# Render a map
renderMap = !->
	log " renderMap()"
	showPopup = Obs.create ""
	map = Map.render
		zoom: 12
		minZoom: 2
		clustering: true
		clusterRadius: 45
		clusterSpreadMultiplier: 2
		#onTap: !->
		#	showPopup.set ""
		#onLongTap: !->
		#	showPopup.set ""
	, (map) !->
		log "map=", map
		log "map.getBounds()=", map.state
		restoreMapLocation(map)
		renderLocations(map, showPopup)
		renderOwnLocation(map, showPopup)
		Obs.observe !->
			Db.local.set 'lastMapLocation', map.getLatlong()
			Db.local.set 'lastMapZoom', map.getZoom()

# Restore the old map location (used to center the map on the previous view after reloading the app)
restoreMapLocation = (map) !->
	lastLocation = Db.local.peek('lastMapLocation')
	lastZoom = Db.local.peek('lastMapZoom')
	if lastLocation? and lastZoom?
		log "Map settings restored: location="+lastLocation+", zoom="+lastZoom
		map.setLatlong lastLocation
		map.setZoom lastZoom

# Render the locations on the map
renderLocations = (map, showPopup) !->
	log "renderLocations()"
	Db.shared.iterate 'locations', (userLocation) !->
		if (userLocation.key()+"") is (Plugin.userId()+"")
			return
		Obs.observe !->
			location = userLocation.get('latlong')
			accuracy = userLocation.get('accuracy')
			if location?
				map.marker location, !->
					#log "user="+userLocation.key()+", location="+location+", accuracy="+accuracy
					Dom.style
						width: "42px"
						height: "42px"
						margin: "-21px 0 0 -21px"
						backgroundColor: "#FFF"
						borderRadius: "50%"
					Dom.div !->
						Ui.avatar Plugin.userAvatar(userLocation.key()), size: 40
						Dom.style
							borderRadius: "50%"
							backgroundSize: "contain"
							backgroundRepeat: "no-repeat"
							backgroundColor: "#FFF"
						Obs.observe !->
							lastUpdate = userLocation.get('lastUpdate')
							if ((new Date()/1000)-lastUpdate) > 60*60 # Make old locations less visible
								Dom.style
									opacity: 0.7
							else
								Dom.style
									opacity: 1
					# Popup div
					Obs.observe !->
						lastUpdate = userLocation.get('lastUpdate')
						if showPopup.get() is userLocation.key()
							Dom.div !->
								Dom.div !->
									Dom.style
										textOverflow: 'ellipsis'
										whiteSpace: 'nowrap'
										overflow: 'hidden'
									Dom.text Plugin.userName(userLocation.key())
									if lastUpdate?
										Dom.br()
										Time.deltaText lastUpdate
								popupStyling()
					# Popup trigger
					Dom.onTap !->
						if showPopup.peek() is userLocation.key()
							showPopup.set ""
						else
							showPopup.set userLocation.key()
				radius = accuracy
				if radius > 1000
					radius = 1000
				map.circle location, radius,
					color: '#0077cf',
					fillColor: '#0077cf',
					fillOpacity: 0.4
					weight: 2
					opacity: 0.5
					tap: !->
						if showPopup.peek() is userLocation.key()
							showPopup.set ""
						else
							showPopup.set userLocation.key()

# Render and track own location
renderOwnLocation = (map, showPopup) !->
	log "renderOwnLocation()"
	latest = undefined
	diff = undefined
	Obs.observe !->
		if Geoloc.isSubscribed()
			state = Geoloc.track(100, 5)
			log "geoloc start tracking"
			Obs.onClean !->
				log "geoloc stop tracking"
			Obs.observe !->
				location = state.get('latlong') # TODO: should change
				latest = state.get('timestamp')
				if location?
					[lat,long] = location.split(",")
					log '  location update: location='+location+", accuracy="+state.peek('accuracy')
					if location? and lat? and long?
						map.marker location, !->
							Dom.style
								width: "42px"
								height: "42px"
								margin: "-21px 0 0 -21px"
								backgroundColor: "#FFF"
								borderRadius: "50%"
							Dom.div !->
								Ui.avatar Plugin.userAvatar(Plugin.userId()), size: 40
								Obs.observe !->
									lastUpdate = Db.shared.get('locations', Plugin.userId(), 'lastUpdate') ? 0
									if ((new Date()/1000)-lastUpdate) > 60*60 # Make old locations less visible
										Dom.style
											opacity: 0.7
									else
										Dom.style
											opacity: 1
								Dom.style
									borderRadius: "50%"
									backgroundColor: "#FFF"
							Dom.style
								backgroundSize: "contain"
								backgroundRepeat: "no-repeat"
								zIndex: "10000"
							# Popup div
							Obs.observe !->
								if showPopup.get() is Plugin.userId()
									Dom.div !->
										Dom.div !->
											Dom.style
												textOverflow: 'ellipsis'
												whiteSpace: 'nowrap'
												overflow: 'hidden'
											Dom.text "Your location"
											lastUpdate = Db.shared.get 'locations', Plugin.userId(), 'lastUpdate'
											if lastUpdate?
												Dom.br()
												Time.deltaText lastUpdate
										popupStyling()
							# Popup trigger
							Dom.onTap !->
								if showPopup.peek() is Plugin.userId()
									showPopup.set ""
								else
									showPopup.set Plugin.userId()
					# Render accuracy circle
					Obs.observe !->
						accuracy = state.get('accuracy')
						radius = accuracy
						if radius > 1000
							radius = 1000
						map.circle location, radius,
							color: '#FFA200',
							fillColor: '#FFA200',
							fillOpacity: 0.4
							weight: 2
							opacity: 0.5
							onTap: !->
								if showPopup.peek() is Plugin.userId()
									showPopup.set ""
								else
									showPopup.set Plugin.userId()
						Obs.observe !->
							# Send location to server if it is outdated or has bad accuracy
							lastRemoteUpdate = Db.shared.peek("locations", Plugin.userId(), "lastUpdate") ? 0
							lastLocalUpdate = Db.local.peek("lastUpdate") ? 0
							lastAccuracy = Db.shared.peek("locations", Plugin.userId(), "accuracy") ? Infinity
							if (lastAccuracy > 100 and accuracy < lastAccuracy) or (lastRemoteUpdate < ((new Date()/1000)-60) and lastLocalUpdate < ((new Date()/1000)-60))
								Db.local.set "lastUpdate", new Date()/1000
								log "checking in location"
								Server.send 'checkinLocation', location, accuracy, latest/1000
					Obs.observe !->
						# Render an arrow that points to your location if you do not have it on your screen already
						if !(Map.inBounds(location, map.getLatlongNW(), map.getLatlongSE()))
							#log 'Your location is outside your viewport, rendering indication arrow'
							anchor = map.getLatlongSW() # Location closest to the position of the indication arrow
							[anchorLat,anchorLong] = anchor.split(",")
							pi = 3.14159265
							difLat = Math.abs(lat - anchorLat)
							difLng = Math.abs(long - anchorLong)
							angle = 0
							if long > anchorLong and lat > anchorLat
								angle = Math.atan(difLng/difLat)
							else if long > anchorLong and lat <= anchorLat
								angle = Math.atan(difLat/difLng)+ pi/2
							else if long <= anchorLong and lat <= anchorLat
								angle = Math.atan(difLng/difLat)+ pi
							else if long <= anchorLong and lat > anchorLat
								angle = (pi-Math.atan(difLng/difLat)) + pi
							t = "rotate(" +angle + "rad)"
							distance = Map.distance(location, anchor)
							if distance <= 1000
								distance = Math.round(distance) + "m"
							if distance > 1000
								distance = Math.round(distance/1000) + "km"
							Dom.div !->
								Dom.cls 'indicationArrow'
								Dom.style
									mozTransform: t
									msTransform: t
									oTransform: t
									webkitTransform: t
									transform: t
									backgroundColor: '#0077cf'
							Dom.div !->
								Dom.cls 'indicationArrowText'
								Dom.text "You're " + distance + " away"
							Dom.div !->
								Dom.onTap !->
									map.setLatlong(location)
									map.setZoom(16)
								Dom.style
									position: 'absolute'
									bottom: '0px'
									left: '0px'
									width: '160px'
									height: '45px'
									zIndex: '11'

					# Geoloc testing
					###
					Dom.div !->
						diff = state.get('timestamp') - latest
						latest = state.get('timestamp')
						Dom.style
							width: '100%'
							position: 'absolute'
							bottom: '49px'
							left: '0'
							zIndex: '2000'
							padding: '11px'
							fontSize: '16px'
							boxSizing: 'border-box'
							backgroundColor: '#888888'
							color: 'white'
							_display: 'flex'
							_alignItems: 'center'
						Dom.div !->
							Dom.style
								float: 'left'
								marginRight: '10px'
								width: '30px'
								_flexGrow: '0'
								_flexShrink: '0'
							Icon.render data: 'info', color: '#fff', style: { paddingRight: '10px'}, size: 30
						Dom.div !->
							Dom.style
								_flexGrow: '1'
								_flexShrink: '1'
							Dom.text "lat=" + lat + ", long=" + long + ", accuracy=" + state.get('accuracy') + ", slow=" + state.get('slow') + ", time=" + state.get('timestamp') + " ("
							Time.deltaText state.get('timestamp')/1000
							Dom.text ")"
							Dom.br()
							Dom.text "diff="+diff/1000
					###
				else
					log 'Location could not be found'

# Style a marker popup
popupStyling = () !->
	Dom.style
		padding: "4px"
		backgroundColor: "#FFF"
		width: "100px"
		margin: "-87px 0 0 -32px"
		borderRadius: "5px"
		border: "1px solid #ccc"
		textAlign: "center"
		overflow: "visible"
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		lineHeight: "125%"
		zIndex: "10000000"
	Dom.div !->
		t = "rotate(45deg)"
		Dom.style
			width: "10px"
			height: "10px"
			margin: "-2px 0 -9px 43px"
			backgroundColor: "#FFF"
			_boxShadow: "1px 1px 0 #BBB"
			mozTransform: t
			msTransform: t
			oTransform: t
			webkitTransform: t
			transform: t
			borderRadius: "100% 0 0 0"