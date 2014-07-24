{map, sort, sort-by, mean} = require \prelude-ls
db = require \./../config .connect!

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
					"event.toView.name": "Flashcard"
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					timeDelta: $exists: 1
					country: {$exists: 1, $in: ['CA', 'IE']}
			}
			{
				$project:
					adId: "$device.adId"
					session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					timeDelta: 1
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					courseChapter: course: "$event.toView.courseId", chapter: "$event.toView.chapterIndex"
			}
			{
				$group: 
					_id: {
						adId: "$adId"
						session: "$session"
					}
					date: $min: "$date"
					courseChapters: $addToSet: "$courseChapter"
			}
			{
				$unwind: "$courseChapters"
			}
			{
				$group: 
					_id: {
						adId: "$_id.adId"
						date: "$date"
					}
					courseChapters: $sum: 1
			}
			{
				$group:
					_id: "$_id.date"
					users: $sum: 1
					courseChapters: $avg: "$courseChapters"
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) |> map ({_id, users, courseChapters}) -> {day: _id, users, chapters: (Math.round courseChapters*10)/10}
db.close!
return
