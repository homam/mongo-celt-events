{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, find, filter, first, group-by, concat-map, foldl} = require \prelude-ls
utils = require "./utils"

courses = require \../data/courses.json

one-minue = 1000 * 60
one-hour = one-minue * 60
one-day =  one-hour * 24

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->

	(success, reject) <- new-promise
	(err, devices) <- utils.get-devices-from-media-sources db, sources
	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
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
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex" # $add: ["$event.toView.chapterIndex", $multiply: ["$event.toView.courseId", 1000]]
					card: "$event.toView.cardIndex"
					toSide: "$event.toView.side"
					fromSide: "$event.fromView.side"
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

					cards: $sum: $cond: [{$eq: ["$toSide", "question"]}, 1, 0]
					flips: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}], 1, 0]
			}
			{
				$group:
					_id:
						adId: "$_id.adId"
						course: "$_id.course"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					chapters: $sum: 1
			}
			{
				$group:
					_id: 
						course: "$_id.course"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					chapters: $sum: "$chapters"
					users: $sum: 1
			}
			{
				$project:
					_id: 0
					courseId: "$_id.course"
					cards: "$cards"
					flips: "$flips"
					chapters: "$chapters"
					users: "$users"
			}
		]

	console.log res
	return reject err if !!err

	success <| res |> sort-by (.users * -1) |> map ((c)-> c <<< name: courses |> find (-> c.courseId == (parseInt it.id) ) |> (?.title?.en) )


module.exports = query
