{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./web-config .connect!

(err, res) <- db.events.aggregate do
	[
		{
			$match: 
				userId: $ne: 0 
				ip: $ne: "80.227.47.62"
				creationTime: $gte: new Date(2014,8,10)
				"eventArgs.userAgent": /.*iPhone.*/
				eventType: $in: ['bannerMAClassic', 'gotoMAClassic']
		}
		{
			$project: 
				userId: "$userId"
				countryCode: 1
				creationTime: 1
				eventType: 1
				time: $subtract: ["$creationTime", new Date("1970-01-01")]
		}
		{
			$project: 
				userId: "$userId"
				eventType: 1
				countryCode: 1
				time: $subtract: ["$time", $mod: ["$time", 1000 * 60 * 60 * 24]]
		}
		{
			$group:
				_id: countryCode: "$countryCode", time: "$time", eventType: "$eventType"
				count: $sum: 1
		}
	]


format-json = (obj) ->
	JSON.stringify obj, null, 4
console.log err if !!err
console.log <| format-json <| res |> map (-> {} <<< it._id <<< {it.count}) |> map (-> it <<< time: (moment new Date it.time).format \YYYYMMDD)

db.close!