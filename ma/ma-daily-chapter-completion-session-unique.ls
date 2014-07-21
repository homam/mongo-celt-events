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
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
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
					chapters: $addToSet: "$_id.chapter"
			}
			{
				$unwind: "$chapters"
			}
			{
				$group:
					_id: "$_id"
					date: $first: "$date"
					cards: $first: "$cards"
					eocs: $first: "$eocs"
					chapters: $sum: 1

			}
			{
				$group:
					_id: date: "$date", adId: "$_id.adId"
					sessions: $addToSet: "$_id.session"
					cards: $sum: "$cards"
					eocs: $sum: "$eocs"
					chapters: $sum: "$chapters"
			}
			{
				$unwind: "$sessions"
			}
			{
				$group:
					_id: "$_id"
					sessions: $sum: 1
					cards: $first: "$cards"
					chapters: $first: "$chapters"
					eocs: $first: "$eocs"
			}
			{
				$group:
					_id: "$_id.date"
					sessions: $sum: "$sessions"
					users: $addToSet: "$_id.adId"
					cards: $sum: "$cards"
					chapters: $sum: "$chapters"
					eocs: $sum: "$eocs"
			}
			{
				$unwind: "$users"
			}
			{
				$group:
					_id: "$_id"
					sessions: $first: "$sessions"
					users: $sum: 1
					card: $first: "$cards"
					chapters: $first: "$chapters"
					eocs: $first: "$eocs"
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err



console.log <| res |> sort-by (._id) # |> map ({_id, users, chapters}) -> {day: _id, users, chapters: (Math.round chapters*10)/10}
db.close!
return
