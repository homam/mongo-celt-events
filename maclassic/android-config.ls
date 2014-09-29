connect = ->
	db = require("mongojs").connect \207.97.212.169/PhonegapAndroidApp-events, [\events]
	db

exports.connect = connect