# > http://localhost:3002/query/daily-cards/2014-07-10/2014-07-30/CA,IE
{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls

{map, sort, sort-by, mean} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24


# if the user visits the same Flashcard / EOC twice in the same [session + subSession]
# this query count it as once

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->
	(success, reject) <- new-promise
	db.IOSEvents.aggregate do
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
					installTime: $subtract: ["$serverTime", "$timeDelta"]

					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex" # $add: ["$event.toView.chapterIndex", $multiply: ["$event.toView.courseId", 1000]]
					card: "$event.toView.cardIndex"
					toSide: "$event.toView.side"
					fromSide: "$event.fromView.side"
					view: "$event.toView.name"
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
						date: "$date"
						course: "$course"
						chapter: "$chapter"

					cards: $sum: $cond: [{$eq: ["$toSide", "question"]}, 1, 0]
					flips: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}], 1, 0]
			}
			{
				$group:
					_id:
						adId: "$_id.adId"
						date: "$_id.date"
						course: "$_id.course"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					chapters: $sum: 1
			}
			{
				$group:
					_id: 
						adId: "$_id.adId"
						date: "$_id.date"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					chapters: $sum: "$chapters"
					courses: $sum: 1
			}
			{
				$group:
					_id: "$_id.date"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					chapters: $sum: "$chapters"
					courses: $sum: "$courses"
					users: $sum: 1
			}
		]
		(err, res) ->
			return reject err if !!err
			success <| res |> sort-by (._id)

module.exports = query
