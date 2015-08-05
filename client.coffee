Db = require 'db'
Time = require 'time'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
Plugin = require 'plugin'
Page = require 'page'
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

ownLocation = Obs.create undefined

# ========== Events ==========
# Main function, called when plugin is started
exports.render = !->
	log 'FULL RENDER'
	Obs.onClean !->
		log 'FULL CLEAN'
	# Request a background location update for the other users
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
	# Enable/disable location sharing bar
	Obs.observe !->
		if !Geoloc.isSubscribed()
			Dom.div !->
				Dom.style
					position: "absolute"
					top: "0"
					left: "0"
					right: "0"
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
		zoom: Db.local.peek('lastMapZoom') ? 12
		minZoom: 2
		clustering: true
		clusterRadius: 45
		clusterSpreadMultiplier: 2
		latlong: Db.local.peek('lastMapLocation') ? "52.444553, 5.740644"
		#onTap: !->
		#	showPopup.set ""
		#onLongTap: !->
		#	showPopup.set ""
	, (map) !->
		log "map=", map
		log "map.getBounds()=", map.state
		renderLocations(map, showPopup)
		Obs.observe !->
			Db.local.set 'lastMapLocation', map.getLatlong()
			Db.local.set 'lastMapZoom', map.getZoom()
	renderIndicationArrow(map)

# Render the locations on the map
renderLocations = (map, showPopup) !->
	log "renderLocations()"
	Obs.observe !->
		trackAll = Geoloc.trackAll()
		Plugin.users.iterate (user) !->
			userLocation = trackAll.ref(user.key())
			self = (userLocation.key()+"") is (Plugin.userId()+"")
			if self
				if !Geoloc.isSubscribed()
					return
				state = Geoloc.track(100,5)
				log "tracking own location: "+state
				Obs.onClean !->
					log "Stop tracking own location"
			return if !userLocation.isHash() and !self
			Obs.observe !->
				location = if self then state.get('latlong') else userLocation.get('latlong')
				accuracy = if self then state.get('accuracy') else userLocation.get('accuracy')
				lastTime = if self then state.peek('time') else userLocation.peek('time')
				if ((new Date()/1000)-lastTime) > 60*60*3 && !self
					log "not showing: "+userLocation.key()
					return
				log "location update: "+self+", location="+location
				if location?
					ownLocation.set(location) if self
					map.marker location, !->
						#log "user="+userLocation.key()+", location="+location+", accuracy="+accuracy
						Dom.style
							width: "42px"
							height: "42px"
							margin: "-21px 0 0 -21px"
							backgroundColor: "#FFF"
							borderRadius: "50%"
						Dom.div !->
							Ui.avatar Plugin.userAvatar(if self then Plugin.userId() else userLocation.key()), size: 40
							Dom.style
								borderRadius: "50%"
								backgroundSize: "contain"
								backgroundRepeat: "no-repeat"
								backgroundColor: "#FFF"
							Obs.observe !->
								lastUpdate = userLocation.get('time')
								if ((new Date()/1000)-lastUpdate) > 60*60 # Make old locations less visible
									Dom.style
										opacity: 0.7
								else
									Dom.style
										opacity: 1
						# Popup div
						Obs.observe !->
							lastUpdate = userLocation.get('time')
							if showPopup.get() is userLocation.key()
								Dom.div !->
									Dom.div !->
										Dom.style
											textOverflow: 'ellipsis'
											whiteSpace: 'nowrap'
											overflow: 'hidden'
										Dom.text if self then "Your location" else Plugin.userName(userLocation.key())
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
						color: if self then '#FFA200' else '#0077cf'
						fillColor: if self then '#FFA200' else '#0077cf'
						fillOpacity: 0.4
						weight: 2
						opacity: 0.5
						tap: !->
							if showPopup.peek() is userLocation.key()
								showPopup.set ""
							else
								showPopup.set userLocation.key()

renderIndicationArrow = (map) !->
	Obs.observe !->
		location = ownLocation.get()
		if location?
			[lat,long] = location.split(",")
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