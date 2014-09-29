{
	promises: {
		serial-map
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./maweb-config .connect!
fs = require \fs


format-json = (obj) ->
	JSON.stringify obj, null, 4

start = moment \2014-09-05 


query = (subscribed-on) ->
	
	(succ, rej) <- new-promise

	(err, data) <- fs.read-file "data/#{subscribed-on.format "YYYY-MM-DD"}.json", \utf8
	return rej err if !!err

	userIds = JSON.parse data


	(err, res) <- db.events.aggregate do
		[
			{
				$match: 
					ip: $ne: "80.227.47.62"
					#creationTime: $gte: new Date(2014,9,4)
					userId: $in: userIds
					eventType: \pageReady
			}
			{
				$project: 
					userId: "$userId"
					countryCode: 1
					creationTime: 1
					viewId: 1
					#eventType: 1
					eventType: $cond: [
						{$eq: ["$viewId", "Flashcard"]}, 
						"Flip", 
						"Visit"
							
					]
					time: $subtract: ["$creationTime", new Date("1970-01-01")]
			}
			{
				$project: 
					userId: "$userId"
					eventType: 1
					# eventType: $cond: [{$eq: ["$eventType", "pageReady"]}, {$concat: ["$eventType", "-", "$viewId"]}, "$eventType"]
					countryCode: 1
					time: $subtract: ["$time", $mod: ["$time", 1000 * 60 * 60 * 24]]
			}
			{
				$group:
					_id: userId: "$userId", countryCode: "$countryCode", time: "$time"
					flips: $sum: $cond: [{$eq: ["$eventType", "Flip"]}, 1, 0]
					visits: $sum: 1
			}
			{
				$group:
					_id: "$_id" #countryCode: "$_id.countryCode", time: "$_id.time"
					flips: $sum: "$flips"
					visits: $sum: "$visits"
					uvisits: $sum: 1
					uflips: $sum: $cond: [{$gt: ["$flips", 0]}, 1, 0]
			}
			{
				$group:
					_id: countryCode: "$_id.countryCode", time: "$_id.time"
					flips: $sum: "$flips"
					visits: $sum: "$visits"
					uvisits: $sum: "$uvisits"
					uflips: $sum: "$uflips"
			}
		]

	return rej err if !!err
	res := res |> map (-> o = it._id; delete it._id; it <<< o) |> map (-> time = it.time; delete it.time; it <<< day: (moment new Date time).diff subscribed-on, \days)
	(err) <- fs.write-file "usage-data/#{subscribed-on.format "YYYY-MM-DD"}.json", (format-json res), encoding: \utf8
	return rej err if !!err
	succ res





serial-map query, [start.clone!.add \days, i for i in [0 to 22]]
	..then (res) -> 
		console.log \DONE!
		console.log <| format-json res
		db.close!
	..catch (err) -> 
		console.log \err, err
		db.close!

