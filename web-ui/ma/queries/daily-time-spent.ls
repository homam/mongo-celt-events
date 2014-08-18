# Average daily / per session time spent per user per day.
# > http://localhost:3002/query/time-spent/2014-07-01/2014-08-01/CA,IE/2014-07-01/2014-07-23T12:00:00
{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
utils = require "./utils"

one-hour = 1000*60*60
one-day =  one-hour*24

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->	

	(success, reject) <- new-promise

	(err, devices) <- utils.get-devices-from-media-sources db, sources	
	return reject err if !!err

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
					
			}
			{
				$project:
					"device.adId": 1
					session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					timeDelta: 1
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
					_id: {
						adId: "$device.adId"
						session: "$session"
					}
					date: $min: "$date"
					minDelta: $min: "$timeDelta"
					maxDelta: $max: "$timeDelta"
			}
			{
				$project:
					_id: 1
					date: 1
					duration: $subtract: ["$maxDelta", "$minDelta"]
			}
			{
				$match: 
					duration: $lte: one-hour
			}
			{
				$group: 
					_id: {
						adId: "$_id.adId"
						date: "$date"
					}
					sessions: $sum: 1
					avgSessionDuration: $avg: "$duration"
					duration: $sum: "$duration"
			}
			{
				$group:
					_id: "$_id.date"
					sessions: $sum: "$sessions"
					users: $sum: 1
					avgSessionDuration: $avg: "$avgSessionDuration"
					duration: $avg: "$duration"
			}
		]

	return reject err null if !!err

	pretty = (/(1000)) >> Math.round

	success <| res 
		|> sort-by (._id) 
		|> map ({_id, users, sessions, avgSessionDuration, duration}) -> {day: _id, users, sessions, avgSessionDuration: (pretty avgSessionDuration), avgDailyDuration: (pretty duration)}

module.exports = query
