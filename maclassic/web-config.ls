connect = ->
	db = require("mongojs").connect \207.97.212.169/MobileAcademy-events, [\events]
	db

exports.connect = connect