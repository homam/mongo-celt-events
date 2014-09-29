{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./android-config .connect!

(err, res) <- db.events.aggregate do
	[
		{
			$match: 
				ip: $ne: "80.227.47.62"
				creationTime: $gte: new Date(2014,8,10)
		}
		{
			$project: 
				sessionId: "$sessionId"
				countryCode: 1
				creationTime: 1
				viewId: 1
				eventType: $cond: [
					{$ne: ["$eventType", "msisdnEntered"]}, "$eventType", 
						$cond: [{$eq: ["$eventArgs.valid", true]}, "MSISDN-ValidEntry", "MSISDN-WrongEntry"]
				]
				time: $subtract: ["$creationTime", new Date("1970-01-01")]
		}
		{
			$project: 
				sessionId: "$sessionId"
				eventType: $cond: [{$eq: ["$eventType", "pageReady"]}, {$concat: ["$eventType", "-", "$viewId"]}, "$eventType"]
				countryCode: 1
				time: $subtract: ["$time", $mod: ["$time", 1000 * 60 * 60 * 24]]
		}
		{
			$group:
				_id: sessionId: "$sessionId", countryCode: "$countryCode", eventType: "$eventType", time: "$time"
				count: $sum: 1
		}
		{
			$group:
				_id: countryCode: "$_id.countryCode", time: "$_id.time", eventType: "$_id.eventType"
				count: $sum: "$count"
		}
	]


format-json = (obj) ->
	JSON.stringify obj, null, 4
console.log err if !!err
console.log <|  format-json <| res |> map (-> {} <<< it._id <<< {it.count}) |> map (-> it <<< time: (moment new Date it.time).format \YYYYMMDD)

db.close!