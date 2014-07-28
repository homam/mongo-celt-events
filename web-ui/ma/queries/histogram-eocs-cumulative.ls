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


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10, unique-count = true) ->
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
					timeDelta: $exists: 1
					
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex"
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
					_id: if unique-count then "$ueocs" else "$eocs"
					users: $sum: 1
			}
		]

	return reject err if !!err

	(err, users) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
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
	success histogram # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}


module.exports = query
