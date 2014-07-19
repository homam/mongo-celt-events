{map, sort, sort-by, mean} = require \prelude-ls
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day


query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					timeDelta: $gte:from-time, $lte: to-time
			}
			{
				$project:
					"device.adId": 1
					session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					timeDelta: 1
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
			}
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
		callback

(err, res) <- query
console.log "Error", err if !!err

pretty = (/(1000)) >> Math.round
console.log <| res |> sort-by (._id) |> map ({_id, users, sessions, avgSessionDuration, duration}) -> {day: _id, users, sessions, avgSessionDuration: (pretty avgSessionDuration), avgDailyDuration: (pretty duration) }
db.close!
return
