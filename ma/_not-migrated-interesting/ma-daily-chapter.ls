{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-15" .unix! * 1000
query-to   = moment "2014-07-30" .unix! * 1000


# how many unique chapters have been visited every day
# it does not take session into account

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
					country: {$exists: 1, $in: ['CA', 'IE']}

			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					
					chapter: 
						ch: "$event.toView.chapterIndex"
						co: "$event.toView.courseId"
			}
			{
				$group: 
					_id: {
						date: "$date"
						adId: "$adId"
					}
					chapters: $addToSet: "$chapter"
			}
			{
				$unwind: "$chapters"
			}
			{
				$group:
					_id: "$_id"
					chapters: $sum: 1
			}
			{
				$group: 
					_id: "$_id.date"
					chapters: $sum: "$chapters"
					users: $sum: 1
			}
			
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
