connect = ->
	db = require("mongojs").connect \207.97.212.169/MobileAcdemyMobileApp-events, [\events]
	db

exports.connect = connect