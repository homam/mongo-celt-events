# > http://localhost:3002/query/histogram-flips-onday/2014-07-10/2014-07-27/CA,IE/2014-07-20/2014-07-27/0
{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, sum} = require \prelude-ls
moment = require \moment

one-hour = 1000*60*60
one-day =  one-hour*24


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10) ->
	(success, reject) <- new-promise

	install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * 24 * 60 * 60 * 1000)

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"event.name": "transition"
					"event.toView.name": "EOC" # , "EOC", "Question", "EOQ"]
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					
					timeDelta: $lte: (how-many-days+1) * one-day, $gte: how-many-days * one-day
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex" # $add: ["$event.toView.chapterIndex", $multiply: ["$event.toView.courseId", 1000]]
					card: "$event.toView.cardIndex"
					toSide: "$event.toView.side"
					toCard: "$event.toView.cardIndex"
					fromSide: "$event.fromView.side"
					fromCard: "$event.fromView.cardIndex"
					view: "$event.toView.name"

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
					_id: 
						adId: "$adId"
						course: "$course"
						chapter: "$chapter"

					eocs: $sum: 1
			}
			{
				$group:
					_id: "$_id.adId"
					eocs: $sum: "$eocs"
					ueocs: $sum: $cond: [$gt: ["$eocs", 0] , 1, 0]
			}
			{
				$group: 
					_id: "$ueocs"
					users: $sum: 1
			}
		]

	return reject err if !!err

	(err, users) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					timeDelta: $lte: (how-many-days+1) * one-day, $gte: how-many-days * one-day
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
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
					_id: 
						adId: "$adId"

					events: $sum: 1
			}
			{
				$group:
					_id: "users"
					users: $sum: $cond: [$gt: ["$events", 0] , 1, 0]
			}
		]


	return reject err if !!err


	users0 = users?.0?.users - (res |> map (.users) |> sum)
		
	histogram = [_id: 0, users: users0] ++ (res |> sort-by (._id))
	success histogram 


module.exports = query
