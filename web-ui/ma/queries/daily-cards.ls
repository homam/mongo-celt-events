{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->
	(success, reject) <- new-promise
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"event.name": "transition"
					"event.toView.name": "Flashcard"
					"event.toView.cardIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					timeDelta: $exists: 1
					
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					installTime: $subtract: ["$serverTime", "$timeDelta"]

					card: 
						ch: "$event.toView.chapterIndex"
						co: "$event.toView.courseId"
						ca: "$event.toView.cardIndex"
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
						date: "$date"
						adId: "$adId"
					}
					cards: $addToSet: "$card"
			}
			{
				$unwind: "$cards"
			}
			{
				$group:
					_id: "$_id"
					cards: $sum: 1
			}
			{
				$group: 
					_id: "$_id.date"
					cards: $sum: "$cards"
					users: $sum: 1
			}
			
		]
		(err, res) ->
			return reject err if !!err
			success <| res |> sort-by (._id)

module.exports = query
