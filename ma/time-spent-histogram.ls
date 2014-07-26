{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-01" .unix! * 1000
query-to   = moment "2014-07-30" .unix! * 1000


how-many-days = 1

install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * one-day)
install-time-from = install-time-to  - one-day

countries = [\CA, \IE]

(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				sessionNumber: $exists: 1
				subSessionNumber: $exists: 1

				#timeDelta: $exists: 1
				# non-cumulative:
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
		# {
		# 	$match:
				
		# 		# cumulative: just install-time-to
		# 		#date: $lte: how-many-days
		# 		#  installTime: $lte: install-time-to

				
		# }
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

console.log err if !!err
console.log <| res |> sort-by (._id)

db.close!