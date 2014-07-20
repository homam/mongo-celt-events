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
					courseChapter: course: "$event.toView.courseId", chapter: "$event.toView.chapterIndex"
					view: "$event.toView.name"
			}
			{
				$group: 
					_id: {
						adId: "$adId"
						session: "$session"
					}
					date: $min: "$date"
					chapters: $addToSet: "$courseChapter"
					flashcards: $sum: $cond: [{$eq: ["$view", "Flashcard"]}, 1, 0]
					eocs: $sum: $cond: [{$eq: ["$view", "EOC"]}, 1, 0]
			}
			{
				$unwind: "$chapters"
			}
			{
				$group: 
					_id: {
						adId: "$_id.adId"
						date: "$date"
					}
					chapters: $sum: 1
					flashcards: $first: "$flashcards"
					eocs: $first: "$eocs"
			}
			{
				$group:
					_id: "$_id.date"
					users: $sum: 1
					chapters: $avg: "$chapters"
					flashcards: $avg: "$flashcards"
					eocs: $avg: "$eocs"
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
