Db = require 'db'
Time = require 'time'
Dom = require 'dom'
Modal = require 'modal'
Obs = require 'obs'
App = require 'app'
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
Server = require 'server'
# Plugin files
CSS = require 'css'

trackAll = undefined
trackSelf = undefined
trackAllShow = Obs.create {}
setInitialView = undefined
SMART_INITIALVIEW_MAX = 25
showSpinner = Obs.create {}
justOpened = true
openedAt = undefined

# ========== Events ==========
# Main function, called when plugin is started
exports.render = !->
	setInitialView = true
	Dom.div !->
		Dom.style margin: '0px', width: '100%'
		Obs.observe !->
			Dom.style height: Page.height()+'px'
		renderMap()

# Render a map
renderMap = !->
	showPopup = Obs.create ""
	tap = false
	if Db.local.get('settingPlaceToBe')
		tap = settingPlaceToBeTap
	else
		tap = !-> showPopup.set(false)
	map = Map.render
		zoom: Db.local.peek('lastMapZoom') ? 12
		minZoom: 2
		clustering: true
		clusterRadius: 45
		clusterSpreadMultiplier: 2
		latlong: Db.local.peek('lastMapLocation') ? "52.444553, 5.740644"
		onTap: tap
	, (map) !->
		renderLocations(map, showPopup)
		renderPlaceToBe(map, showPopup)
		Obs.observe !->
			Db.local.set 'lastMapLocation', map.getLatlong()
			Db.local.set 'lastMapZoom', map.getZoom()
	# Top bar
	Dom.div !->
		Dom.style
			position: "absolute"
			left: "0"
			right: "0"
			top: "0"
			zIndex: "100000"
		Obs.observe !->
			Dom.style width: Page.width()+'px'
		renderLocationSharing()
		renderSettingPlaceToBe()
		renderPointers(map)
	# Bottom
	renderPlaceToBePointer(map)

renderLocationSharing = !->
	Obs.observe !->
		if !Geoloc.isSubscribed()
			Dom.div !->
				Dom.style
					width: "100%"
					color: '#666'
					padding: '0'
					fontSize: '16px'
					boxSizing: 'border-box'
					backgroundColor: '#FFF'
					_alignItems: 'center'
					borderBottom: '1px solid #ccc'
				Dom.div !->
					Dom.style
						Box: 'horizontal', backgroundColor: App.colors().highlight, color: '#fff'
					Dom.div !->
						Dom.style padding: "13px"
						Icon.render data: 'map', color: '#fff', style: {position: "static", margin: "0"}, size: 24
					Dom.div !->
						Dom.style
							Flex: true
							padding: "8px 0 5px 0"
						Dom.text tr("Tap to share your location")
						Dom.div !->
							Dom.style
								fontSize: "75%"
							Dom.text tr("Currently others cannot see your location")
				Dom.onTap !->
					Geoloc.subscribe()

# Render the locations on the map
renderLocations = (map, showPopup) !->
	Obs.observe !->
		trackAll = Geoloc.trackAll()
		App.users.iterate (user) !->
			userLocation = trackAll.ref(user.key())
			self = (user.key()+"") is (App.userId()+"")
			if !Geoloc.isSubscribed(user.key())
				trackAllShow.remove user.key()
				return
			if self
				trackSelf = state = Geoloc.track(100,5)
			Obs.observe !->
				if !userLocation?.isHash() and !self
					if Geoloc.isSubscribed(user.key()) > 0
						showSpinner.set user.key(), justOpened
					return
				location = if self then state.get('latlong') else userLocation.get('latlong')
				accuracy = if self then state.get('accuracy') else userLocation.get('accuracy')
				lastTime = (if self then state.peek('time') else userLocation.get('time'))||0
				if ((new Date()/1000)-lastTime) > 60*60*3
					trackAllShow.remove user.key()
					showSpinner.set user.key(), justOpened
					return
				else
					trackAllShow.set user.key(), true
				if location?
					showSpinner.remove user.key()
					map.marker location, !->
						Dom.style
							width: "42px"
							height: "42px"
							margin: "-21px 0 0 -21px"
							borderRadius: "50%"
						# Popup div
						Obs.observe !->
							lastUpdate = userLocation.get('time')
							if showPopup.get() is userLocation.key()
								Dom.div !->
									Dom.div !->
										Dom.style
											whiteSpace: 'normal'
										Dom.text if self then "Your location" else App.userName(userLocation.key())
										if lastUpdate?
											Dom.div !->
												Time.deltaText lastUpdate
												Dom.style
													fontSize: "90%"
													color: "#999"
									popupStyling()
						Dom.div !->
							Obs.observe !->
								lastUpdate = userLocation.get('time')
								if ((new Date()/1000)-lastUpdate) > 60*60 # Make old locations less visible
									Dom.style opacity: 0.7
								else
									Dom.style opacity: 1
								Ui.avatar App.userAvatar(if self then App.userId() else userLocation.key()), size: 42
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
						fillOpacity: 0.1
						weight: 1
						opacity: 0.3
						tap: !->
							if showPopup.peek() is userLocation.key()
								showPopup.set ""
							else
								showPopup.set userLocation.key()
	Obs.observe !->
		# set initial view
		if setInitialView
			shownCount = trackAllShow.count().peek()
			if shownCount > SMART_INITIALVIEW_MAX or shownCount <= 2
				locations = []
				trackAll.iterate (user) !->
					if trackAllShow.peek(user.key()) is true
						locations.push user.peek('latlong')
				if locations.length > 0
					map.moveInView(locations, 0.2)
				setInitialView = false
			else
				users = Obs.create {}
				trackAll.iterate (user) !->
					if trackAllShow.peek(user.key()) is true
						users.set user.key(),
							latlong: user.peek('latlong')
							weight: 1.0
				done = false
				for i in [0..shownCount]
					if !done
						# Check reach for each (combined) user
						users.iterate (user) !->
							if (user.peek('weight')/shownCount) > 0.7 and !done # More as 70%
								locations = []
								for user in user.key().split(",")
									locations.push trackAll.peek(user, 'latlong')
								map.moveInView(locations, 0.2)
								setInitialView = false
								done = true
					if !done
						connectionFrom = undefined
						connectionTo = undefined
						connectionDistance = undefined
						doneUsers = Obs.create {}
						# Calculate best merge
						users.iterate (fromUser) !->
							users.iterate (toUser) !->
								if !(doneUsers.peek(fromUser.key()) is true) && !(fromUser.key() is toUser.key())
									# calculate distance
									distance = Map.distance(fromUser.peek('latlong'), toUser.peek('latlong'))
									if !connectionFrom? or distance < connectionDistance
										connectionFrom = fromUser.key()
										connectionTo = toUser.key()
										connectionDistance = distance
									# make connection
							doneUsers.set fromUser.key(), true
						# Calculate average location
						[latFrom, longFrom] = users.peek(connectionFrom, 'latlong').split(",")
						[latTo, longTo] = users.peek(connectionTo, 'latlong').split(",")
						weightTo = users.peek(connectionTo, 'weight')
						weightFrom = users.peek(connectionFrom, 'weight')
						latA = ((parseFloat(latFrom)*weightFrom)+(parseFloat(latTo))*weightTo)/(weightTo+weightFrom)
						longA = (parseFloat(longFrom)+parseFloat(longTo))/2.0
						averageLocation = latA + "," + longA
						# Setup new combined user
						users.set connectionFrom + "," + connectionTo,
							latlong: averageLocation
							weight: users.peek(connectionFrom, 'weight')+users.peek(connectionTo, 'weight')
						users.remove connectionFrom
						users.remove connectionTo

renderPointers = (map) !->
	Obs.observe !->
		trackAllCount = trackAll.count().get()
		visible = Obs.create 0
		possibleItems = 2*Math.floor(Page.width()/62.0)
		if trackAllShow.count().get() > possibleItems
			return
		Dom.div !->
			Dom.style
				padding: "2px 2px 0 2px"
			trackAll.iterate (user) !->
				if !(trackAllShow.get(user.key()) is true)
					return
				self = App.userId()+"" is user.key()+""
				if self
					tracker = trackSelf
				else
					tracker = user
				if tracker?
					location = tracker.get('latlong')
					lastTime = tracker.get('time')
					if location?
						[lat,long] = location.split(",")
						# Render an arrow that points to your location if you do not have it on your screen already
						if !(Map.inBounds(location, map.getLatlongNW(), map.getLatlongSE()))
							if visible.peek() >= possibleItems
								return
							Dom.div !->
								visible.modify((v) -> v+1)
								Obs.onClean !->
									visible.modify((v) -> v-1)
								Dom.style
									display: 'inline-block'
									padding: '7px'
									width: '50px'
									height: '50px'
								Dom.onTap !->
									map.setLatlong location
									map.setZoom 16
								Dom.div !->
									styleTransformAngle map.getLatlongNW(), location
									Dom.style
										width: '50px'
										height: '50px'
										borderRadius: '50%'
										backgroundColor: '#0077cf'
									Dom.cls 'pointerArrow'
								Dom.div !->
									avatarKey = App.userAvatar(user.key())
									Dom.style
										width: '50px'
										height: '50px'
										Box: 'middle center'
										marginTop: '-50px'
										_transform: "translate3d(0,0,0)"
									Ui.avatar avatarKey, size: 44, style:
										display: 'block'
										margin: '0'
								Dom.div !->
									Dom.style
										overflow: "hidden"
										width: '50px'
										height: '50px'
										marginTop: "-50px"
										borderRadius: '50%'
										_transform: "translate3d(0,0,0)"
									Dom.div !->
										Dom.style
											backgroundColor: "#0077cf"
											color: "#FFF"
											fontSize: "50%"
											width: "50px"
											height: "20px"
											paddingTop: "2px"
											marginTop: "35px"
											textAlign: 'center'
										Dom.text getDistanceString map.getLatlongNW(), location

			# Remove spinners after a minute
			if justOpened
				justOpened = false
				openedAt = Date.now()
				Obs.onTime 60*1000, !->
					showSpinner.set {}
			else
				if (diff = (Date.now() - openedAt)) < 60*1000
					Obs.onTime 60*1000-diff, !->
						showSpinner.set {}
			# Render spinners
			App.users.iterate (user) !->
				if !showSpinner.get(user.key())
					return
				#log "showing as spinner: "+App.userName(user.key())
				self = App.userId()+"" is user.key()+""
				if visible.peek() >= possibleItems
					return
				Dom.div !->
					visible.modify((v) -> v+1)
					Obs.onClean !->
						visible.modify((v) -> v-1)
					Dom.style
						display: "inline-block"
						textAlign: "center"
						padding: "7px"
						height: "43px"
					Dom.div !->
						Dom.style
							width: '50px'
							height: '50px'
							marginLeft: "-2px"
							borderRadius: '50%'
							backgroundColor: '#929292'
					Dom.div !->
						Dom.style
							_transform: "translate3d(0,0,0)"
						Ui.avatar App.userAvatar(user.key()), size: 40, style:
							display: "block"
							position: 'absolute'
							top: '4px'
							left: '3px'
						Ui.spinner 50, !->
							Dom.style
								margin: "-49px 0 0 -2px"
								opacity: "0.3"

renderPlaceToBe = (map, showPopup) !->
	Obs.observe !->
		info = Db.shared.ref 'placetobe'
		exists = info.isHash()
		if exists
			pLocation = info.get 'latlong'
			# Render marker
			map.marker pLocation, !->
				# Popup div
				Obs.observe !->
					placedTime = info.get('time')
					if showPopup.get() is 'placeToBe'
						Dom.div !->
							Dom.style width: "150px"
							Dom.div !->
								Dom.style Box: 'center', whiteSpace: 'normal'

								Dom.div !->
									Dom.style Flex: true
									Dom.userText info.get('message')||tr("Place to be")
									if placedTime?
										Dom.div !->
											Time.deltaText placedTime
											Dom.text " by "+App.userName(info.get('placer'))
											Dom.style
												fontSize: "90%"
												color: "#999"

								if App.userIsAdmin() or (Db.shared.get('placetobe', 'time')||0) < (App.time()-3600) or Db.shared.get('placetobe', 'placer')+"" is App.userId()+""
									Icon.render
										data: 'delete'
										style: padding: '4px'
										onTap: !->
											Modal.confirm null, "Are you sure you want to remove the place to be?", !->
												Server.sync 'removePlaceToBe', !->
													Db.shared.remove 'placetobe'
											, ['cancel', "Cancel", 'remove', "Remove"]

							popupStyling(150)
				Dom.style
					width: "42px"
					height: "42px"
					margin: "-21px 0 0 -21px"
					borderRadius: "50%"
				Dom.div !->
					Dom.style
						width: "42px"
						height: "42px"
						borderRadius: "50%"
						backgroundSize: "contain"
						backgroundRepeat: "no-repeat"
						backgroundImage: "url("+App.resourceUri('placetobe.png')+")"
				# Popup trigger
				Dom.onTap !->
					if showPopup.peek() is 'placeToBe'
						showPopup.set ""
					else
						showPopup.set 'placeToBe'

renderPlaceToBePointer = (map) !->
	Obs.observe !->
		info = Db.shared.ref 'placetobe'
		exists = info.isHash()
		if exists
			pLocation = info.get 'latlong'
			[lat,long] = pLocation.split(",")
			inBounds = Map.inBounds(pLocation, map.getLatlongNW(), map.getLatlongSE())
		if (!exists and !Db.local.get('settingPlaceToBe')) or (exists and !inBounds)
			Dom.div !->
				Dom.style
					position: "absolute"
					bottom: "0"
					left: "0"
					width: "62px"
					height: "65px"
					padding: "0 0 7px 2px"
				Dom.div !->
					Dom.style
						padding: "7px"
					Dom.div !->
						if exists
							styleTransformAngle map.getLatlongSW(), pLocation
							Dom.cls 'indicationArrow'
						else
							Dom.style
								width: '50px'
								height: '50px'
								marginLeft: "-2px"
								borderRadius: '50%'
					Dom.div !->
						Dom.style
							margin: "-47px 0 0 1px"
							_transform: "translate3d(0,0,0)"
							backgroundSize: "contain"
							backgroundRepeat: "no-repeat"
							width: "44px"
							height: "44px"
							borderRadius: "50%"
							backgroundImage: "url("+App.resourceUri('placetobe.png')+")"
							backgroundPosition: "50% 50%"
					if exists
						Dom.div !->
							Dom.style
								overflow: "hidden"
								width: '50px'
								height: '50px'
								marginLeft: "-2px"
								marginTop: "-47px"
								borderRadius: '50%'
								_transform: "translate3d(0,0,0)"
							Dom.div !->
								Dom.style
									backgroundColor: "#0077cf"
									color: "#FFF"
									fontSize: "50%"
									width: "50px"
									height: "20px"
									paddingTop: "2px"
									marginTop: "35px"
									textAlign: "center"
								Dom.text getDistanceString map.getLatlongSW(), pLocation
						Dom.onTap !->
							map.setLatlong pLocation
							map.setZoom 16
					else
						Dom.style
							opacity: 0.7
						Dom.onTap !->
							Db.local.set 'settingPlaceToBe', true
						# Tap to place place to be :S

renderSettingPlaceToBe = !->
	if Db.local.get('settingPlaceToBe')
		Dom.div !->
			Dom.style
				Box: 'horizontal'
				backgroundColor: "#eaeaea"
				borderBottom: '1px solid #ccc'
			Dom.div !->
				Dom.style
					width: "24px"
					height: "24px"
					padding: "13px"
				Dom.div !->
					Dom.style
						background: "url("+App.resourceUri("placetobe.png")+")"
						backgroundRepeat: "no-repeat"
						backgroundSize: "contain"
						width: "100%"
						height: "100%"
			Dom.div !->
				Dom.style
					Flex: true
					padding: "8px 0 5px 0"
				Dom.text tr("Place to be")
				Dom.div !->
					Dom.style fontSize: "75%"
					Dom.text tr("Tap the map to set its location...")
			Dom.div !->
				Dom.style
					padding: "5px 5px 0 5px"
					textAlign: "right"
				Ui.button "Cancel", !->
					Db.local.remove 'settingPlaceToBe'
					Db.local.remove 'placetobe'

settingPlaceToBeTap = (latlong) !->
	Db.local.set 'placetobe', latlong
	result = ''
	Modal.show tr("Set place to be?")
		, !->
			Form.text
				text: tr("Description (optional)")
				onChange: (v) !-> result = v
		, (confirmed) ->
			if confirmed
				result = Form.smileyToEmoji result
				Server.sync 'newPlaceToBe', latlong, result, !->
					Db.shared.set 'placetobe',
						latlong: latlong
						message: result
						time: Date.now()/1000
						placer: App.userId()
				Toast.show tr("Place to be set!")
			else
				Toast.show tr("Setting place to be cancelled")
			Db.local.remove 'settingPlaceToBe'
			Db.local.remove 'placetobe'
		, [false,tr('Cancel'),true,tr('Set')]

# Style a marker popup
popupStyling = (fullWidth = 100) !->
	Dom.style
		width: fullWidth
		padding: "8px"
		border: "1px solid #ccc"
	Dom.div !->
		t = "rotate(45deg)"
		if (width = Dom.get().width()) is 0 then width = fullWidth
		Dom.style
			width: "10px"
			height: "10px"
			margin: "0 0 -12px "+((width+10)/2-9)+"px"
			backgroundColor: "#FFF"
			_boxShadow: "1px 1px 0 #BBB"
			mozTransform: t
			msTransform: t
			oTransform: t
			webkitTransform: t
			transform: t
			borderRadius: "100% 0 0 0"
	Dom.style
		backgroundColor: "#FFF"
		borderRadius: "5px"
		textAlign: "center"
		overflow: "visible"
		textOverflow: 'ellipsis'
		whiteSpace: 'nowrap'
		lineHeight: "125%"
		zIndex: "10000000"
		color: "#222"
	height = Dom.get().height()
	width = Dom.get().width()
	width = fullWidth if width is 0
	Dom.style
		margin: (-height-7-21)+"px 0 7px -"+(width/2-21)+"px" # 21=half height of marker itself

styleTransformAngle = (anchor, to) !->
	[anchorLat,anchorLong] = anchor.split(",")
	[lat,long] = to.split(",")
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
	Dom.style
		mozTransform: t
		msTransform: t
		oTransform: t
		webkitTransform: t
		_transform: t

getDistanceString = (from, to) !->
	distance = Map.distance(from, to)
	if distance <= 1000
		distanceString = Math.round(distance) + "m"
	else
		distanceString = Math.round(distance/1000) + "km"
	return distanceString
