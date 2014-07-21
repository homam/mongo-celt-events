{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-15" .unix! * 1000
query-to   = moment "2014-07-22" .unix! * 1000


# if the user visits the same Flashcard / EOC twice in the same [session + subSession]
# this query count it as once

query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"event.name": "transition"
					"event.toView.name": $in: ["Flashcard", "EOC"]
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex"
					card: "$event.toView.cardIndex"
					view: "$event.toView.name"
			}
			{
				$group: 
					_id: {
						date: "$date"
						adId: "$adId"
					}
					courses: $addToSet: "$course"
			}
			{
				$unwind: "$courses"
			}
			{
				$group:
					_id: "$_id"
					courses: $sum: 1
			}
			{
				$group: 
					_id: "$_id.date"
					courses: $sum: "$courses"
					users: $sum: 1
			}
			# {
			# 	$group:
			# 		_id: "$_id.date"
			# 		coursesPerUser: $avg: "$coursesPerUserPerDay"
			# }
			
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
