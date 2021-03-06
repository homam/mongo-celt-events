{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment

one-hour = 1000*60*60
one-day =  one-hour*24


query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10) ->
	(success, reject) <- new-promise

	install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * 24 * 60 * 60 * 1000)

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"event.name": "transition"
					"event.toView.name": "Flashcard" # , "EOC", "Question", "EOQ"]
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
					chapter: "$event.toView.chapterIndex" # $add: ["$event.toView.chapterIndex", $multiply: ["$event.toView.courseId", 1000]]
					card: "$event.toView.cardIndex"
					toSide: "$event.toView.side"
					toCard: "$event.toView.cardIndex"
					fromSide: "$event.fromView.side"
					fromCard: "$event.fromView.cardIndex"
					view: "$event.toView.name"

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

					flips: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}, {$eq: ["$fromCard", "$toCard"]}], 1, 0]
			}
			# {
			# 	$group:
			# 		_id:
			# 			adId: "$_id.adId"
			# 			course: "$_id.course"

			# 		cards: $sum: "$cards"
			# 		flips: $sum: "$flips"
			# 		chapters: $sum: 1
			# }
			{
				$group:
					_id: "$_id.adId"

					flips: $sum: "$flips"
					# chapters: $sum: "$chapters"
					# courses: $sum: 1
			}
			{
				$group: 
					_id: "$flips"
					users: $sum: 1
			}
		]

	return reject err if !!err

	success <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}


module.exports = query
