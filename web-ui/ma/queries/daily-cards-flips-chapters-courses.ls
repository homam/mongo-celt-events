# > http://localhost:3002/query/daily-cards/2014-07-10/2014-07-30/CA,IE
{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
utils = require "./utils"

one-hour = 1000*60*60
one-day =  one-hour*24

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->
	(success, reject) <- new-promise				
	(err, devices) <- utils.get-devices-from-media-sources db, sources		
	(err, result) <- daily-cards db, query-from, query-to, countries, sample-from, sample-to, devices
	return reject err if !!err
	success <| result

# if the user visits the same Flashcard / EOC / etc. twice in the same day
# this query count it as once

daily-cards = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, devices = null, callback) ->	
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
					"event.name": "transition"
					# "event.toView.name": "Flashcard" # , "EOC", "Question", "EOQ"]
					"event.toView.name": $in: ["Flashcard" , "EOC", "Question", "EOQ"]
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
					toCard: "$event.toView.cardIndex"
					fromSide: "$event.fromView.side"
					fromCard: "$event.fromView.cardIndex"
					view: "$event.toView.name"
					questionIndex: "$event.toView.questionIndex"
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
					flips: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}, {$eq: ["$fromCard", "$toCard"]}], 1, 0]
					backFlips: $sum: $cond: [$and: [{$eq: ["$toSide", "question"]}, {$eq: ["$fromSide", "answer"]}, {$eq: ["$fromCard", "$toCard"]}], 1, 0]
					
					forwards: $sum: $cond: [$and: [{$eq: ["$toSide", "question"]}, {$eq: ["$fromSide", "answer"]}, {$lt: ["$fromCard", "$toCard"]}], 1, 0]
					backwards: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}, {$gt: ["$fromCard", "$toCard"]}], 1, 0]

					eocs: $sum: $cond: [$and: [{$eq: ["$view", "EOC"]}, {$eq: ["$fromSide", "answer"]}], 1, 0]
					quizzes: $sum: $cond: [$and: [{$eq: ["$view", "Question"]}, {$eq: ["$questionIndex", 1]}], 1, 0]
					eoqs: $sum: $cond: [{$eq: ["$view", "EOQ"]}, 1, 0]

					# chapters: $sum: $cond: [$and: [{$eq: ["$view", "Flashcard"]}, {$eq: ["$toCard", 1]}], 1, 0]
			}
			{
				$group:
					_id:
						adId: "$_id.adId"
						date: "$_id.date"
						course: "$_id.course"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					backFlips: $sum: "$backFlips"
					forwards: $sum: "$forwards"
					backwards: $sum: "$backwards"
					eocs: $sum: "$eocs"
					quizzes: $sum: "$quizzes"
					eoqs: $sum: "$eoqs"
					#chapters: $sum: $cond: [$gt: ["$chapters", 0], 1, 0]
					chapters: $sum: 1
			}
			{
				$group:
					_id: 
						adId: "$_id.adId"
						date: "$_id.date"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					backFlips: $sum: "$backFlips"
					forwards: $sum: "$forwards"
					backwards: $sum: "$backwards"
					chapters: $sum: "$chapters"
					eocs: $sum: "$eocs"
					quizzes: $sum: "$quizzes"
					eoqs: $sum: "$eoqs"
					courses: $sum: 1
			}
			{
				$group:
					_id: "$_id.date"

					cards: $sum: "$cards"
					flips: $sum: "$flips"
					backFlips: $sum: "$backFlips"
					forwards: $sum: "$forwards"
					backwards: $sum: "$backwards"
					chapters: $sum: "$chapters"
					courses: $sum: "$courses"
					eocs: $sum: "$eocs"
					quizzes: $sum: "$quizzes"
					eoqs: $sum: "$eoqs"
					usersStartedQuiz: $sum: $cond: [{$gt: ["$quizzes", 0]}, 1, 0]
					usersEndedQuiz: $sum: $cond: [{$gt: ["$eoqs", 0]}, 1, 0]
					users: $sum: 1
			}
		]
		(err, res) ->
			return callback err, null if !!err
			callback null, (res |> sort-by (._id))

module.exports = query
