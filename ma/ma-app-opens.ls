{map, sort, sort-by, mean} = require \prelude-ls
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

now = new Date! .get-time!


(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				#sessionNumber: $exists: 1
				#subSessionNumber: $exists: 1
				timeDelta: $gte:from-time, $lte: to-time
		}
		{
			$project:
				adId: "$device.name"
				#session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
				timeDelta: 1
				date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
				# time passed since installation
				idate: $subtract: [now, $subtract: ["$serverTime", "$timeDelta"]]
		}
		{
			$project:
				adId: 1
				date: 1
				# number of days passed since installation
				idate: $subtract: [{$divide: ["$idate", one-day]}, {$mod: [{$divide: ["$idate", one-day]}, 1]}]
		}
		{
			$group:
				_id: 
					adId: "$adId"
					idate: "$idate" 
					date: "$date"
		}
		{
			$group:
				_id: 
					idate: "$_id.idate"
					date: "$_id.date"
				opened: $sum: 1
		}
	]


console.log err
console.log <| res |> sort-by -> it._id.date*1000 + it._id.idate
db.close!