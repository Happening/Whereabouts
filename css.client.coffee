Dom = require 'dom'

Dom.css
	# Pointer Arrow
	'.pointerArrow:after':
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