# > http://localhost:3002/query/histogram-timespent-onday/2014-07-10/2014-07-27/CA,IE/2014-07-20/2014-07-27/0

{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment

one-hour = 1000*60*60
one-day =  one-hour*24




query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10) ->
	(success, reject) <- new-promise

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1

					timeDelta: $lte: (how-many-days+1) * one-day, $gte: how-many-days * one-day
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
					minDelta: $min: "$timeDelta"
					maxDelta: $max: "$timeDelta"
			}
			{
				$project:
					_id: 1
					duration: $subtract: ["$maxDelta", "$minDelta"]
			}
			{
				$group: 
					_id: adId: "$_id.adId"
					sessions: $sum: 1
					avgSessionDuration: $avg: "$duration"
					duration: $sum: "$duration"
			}
			{
				$project:
					_id: "$_id"
					duration: $subtract: [{$divide: ["$duration", 60*1000]}, {$mod: [{$divide: ["$duration", 60*1000]}, 1]}]
			}
			{
				$group:
					_id: "$duration"
					users: $sum: 1
			}
		]

	return reject err if !!err

	success <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}


module.exports = query
