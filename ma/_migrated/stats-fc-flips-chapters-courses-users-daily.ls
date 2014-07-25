{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-01" .unix! * 1000
query-to   = moment "2014-07-30" .unix! * 1000


# if the user visits the same Flashcard / EOC twice in the same [session + subSession]
# this query count it as once

query = (callback) ->
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
					country: {$exists: 1, $in: ['CA', 'IE']}
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex" # $add: ["$event.toView.chapterIndex", $multiply: ["$event.toView.courseId", 1000]]
					card: "$event.toView.cardIndex"
					toSide: "$event.toView.side"
					fromSide: "$event.fromView.side"
					view: "$event.toView.name"
			}
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
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
