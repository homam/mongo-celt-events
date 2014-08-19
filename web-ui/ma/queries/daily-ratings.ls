# > http://localhost:3002/query/daily-ratings/2014-07-20/2014-07-27/CA,IE/2014-07-20/2014-07-27

{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj, maximum} = require \prelude-ls
utils = require "./utils"

one-hour = 1000*60*60
one-day =  one-hour*24

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->

	(success, reject) <- new-promise

	(err, devices) <- utils.get-devices-from-media-sources db, sources
	return reject err if !!err

	(err, res) <- db.IOSEvents.aggregate do 
		[
			{
				$match: 
					"device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
					"event.name":"ratePopupDismissed" 
					timeDelta: $exists: 1
					country: {$in: ["CA", "IE"]}
					serverTime: $gte: query-from, $lte: query-to

			}
			{
				$project:
					event:1
					userId:1

					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					installTime: $subtract: ["$serverTime", "$timeDelta"]					

			}
		] ++ ( 
				if !!sample-from and !!sample-to then
					[
						$match:
							installTime: $gte: sample-from, $lte: sample-to
					] 
				else []
		) ++ [
			{
				$group:
					_id: 
						button: "$event.buttonKey"
						date: "$date"
					count: $sum: 1
			}
			{
				$group:
					_id: "$_id.date"
					remind: $sum: $cond: [{$eq: ["$_id.button", "Remind_Me_Later"]}, "$count", 0]
					never: $sum: $cond: [{$eq: ["$_id.button", "Never_Show_Rate_Popup_Again"]}, "$count", 0]
					rated: $sum: $cond: [{$eq: ["$_id.button", "Rate_Now"]}, "$count", 0]
			}
		]
	return reject err if !!err
	success <| res

module.exports = query
