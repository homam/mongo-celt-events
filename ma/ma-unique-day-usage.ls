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
					timeDelta: $exists: 1
			}
			{
				$project:
					adId: "$device.name"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
			}
			{
				$group: 
					_id: {
						adId: "$adId"
					}
					dates: $addToSet: "$date"
			}
			{
				$unwind: "$dates"
			}
			{
				$group:
					_id: "$_id.adId"
					days: $sum: 1
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err

console.log <| res |> sort-by (.days)
db.close!
return

