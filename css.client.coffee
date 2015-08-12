Dom = require 'dom'

Dom.css
	#Indication Arrow
	'.indicationArrow':
		width: '50px'
		height: '50px'
		marginLeft: "-2px"
		borderRadius: '50%'
		backgroundColor: '#0077cf'
	###
	'.indicationArrow:before':
		content: '""'
		display: 'block'
		position: 'absolute'
		width: '4px'
		backgroundColor: 'white'
		top: '8px'
		left: '8px'
		height: '7px'
	###
	'.indicationArrow:after':
		content: '""'
		display: 'block'
		width: '0'
		height: '0'
		top: '-7px'
		left: '21px'
		borderBottom: 'solid 8px #0077cf'
		borderLeft: 'solid 5px transparent'
		borderRight: 'solid 5px transparent'
		position: 'absolute'