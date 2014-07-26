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
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-01" .unix! * 1000
query-to   = moment "2014-07-30" .unix! * 1000




query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10) ->
	(success, reject) <- new-promise

	install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * 24 * 60 * 60 * 1000)

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
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
			{
				$match:
					date: $lte: how-many-days
					installTime: $lte: install-time-to
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
