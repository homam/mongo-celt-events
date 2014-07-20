{map, sort, sort-by, mean} = require \prelude-ls
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day


query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					"event.name": "transition"
					"event.toView.name": $in: ["Flashcard", "EOC"]
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					timeDelta: $exists: 1
			}
			{
				$project:
					adId: "$device.adId"
					session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					timeDelta: 1
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex"
					card: "$event.toView.cardIndex"
					view: "$event.toView.name"
			}
			{
				$group: 
					_id: {
						adId: "$adId"
						course: "$course"
						chapter:
							co: "$course" 
							ch: "$chapter"
						card: "$card"
					}
					date: $min: "$date"
					cards: $sum: $cond: [{$eq: ["$view", "Flashcard"]}, 1, 0]
					eocs: $sum: $cond: [{$eq: ["$view", "EOC"]}, 1, 0]
			}
			{
				$group: 
					_id: {
						adId: "$_id.adId"
						date: "$date"
					}
					courses: $addToSet: "$_id.course"
					chapters: $addToSet: "$_id.chapter"
					cards: $sum: "$cards"
					eocs: $sum: "$eocs"
			}
			# {
			# 	$group:
			# 		_id: "$_id.date"
			# 		users: $sum: 1
			# 		cards: $sum: "$cards"
			# 		eocs: $sum: "$eocs"
			# }
		]
		callback




query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					"event.name": "transition"
					"event.toView.name": $in: ["Flashcard", "EOC"]
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					timeDelta: $exists: 1
			}
			{
				$project:
					adId: "$device.adId"
					session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					timeDelta: 1
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					course: "$event.toView.courseId"
					chapter: "$event.toView.chapterIndex"
					card: "$event.toView.cardIndex"
					view: "$event.toView.name"
			}
			{
				$group: 
					_id: {
						chapter: $add: ["$chapter", $multiply: ["$course", 1000]]
						session: "$session"
						adId: "$adId"
					}
					date: $min: "$date"
					cards: $addToSet: "$card" # $sum: $cond: [{$eq: ["$view", "Flashcard"]}, 1, 0]
					eocs: $sum: $cond: [{$eq: ["$view", "EOC"]}, 1, 0]
			}
			{
				$project:
					_id: 1
					date: 1
					cards: 1
					eocs: $cond: [{$gte: ["$eocs", 1]}, 1, 0]
			}
			{
				$unwind: "$cards"
			}
			{
				$group: 
					_id: "$_id"
					date: $first: "$date"
					cards: $sum: 1
					eocs: $first: "$eocs"
			}
			{
				$group:
					_id: date: "$date", adId: "$_id.adId"
					users: $sum: 1
					cards: $sum: "$cards"
					eocs: $sum: "$eocs"
			}
			{
				$group:
					_id: "$_id.date"
					users: $sum: "$users"
					cards: $sum: "$cards"
					eocs: $sum: "$eocs"
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
