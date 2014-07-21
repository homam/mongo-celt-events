#172.30.0.160
connect = ->
	db = require("mongojs").connect \localhost/MA, [\IOSEvents, \IOSUsers]
	db

exports.connect = connect
exports.port = 3002