{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-15" .unix! * 1000
query-to   = moment "2014-07-22" .unix! * 1000


# How many different flashcards have been visited per day
#
# If the same chapter has been visited N times in different sessions on the same day,
# this query counts it as N different flashcards.
#
# But if the same chapter has been visited M times during the same session,
# this query counts it only one time. 

query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"event.name": "transition"
					"event.toView.name": "Flashcard"
					"event.toView.cardIndex": $exists: 1
					"event.toView.chapterIndex": $exists: 1
					"event.toView.courseId": $exists: 1
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
			}
			{
				$project:
					adId: "$device.adId"
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					
					card: 
						ca: "$event.toView.cardIndex"
						ch: "$event.toView.chapterIndex"
						co: "$event.toView.courseId"
						session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]

			}
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
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
