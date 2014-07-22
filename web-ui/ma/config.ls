#172.30.0.160
connect = ->
	db = require("mongojs").connect \207.97.212.169/MA, [\IOSEvents, \IOSUsers]
	db

exports.connect = connect
exports.port = 3002