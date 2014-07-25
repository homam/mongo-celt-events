{map, sort, sort-by, find, filter, first, group-by, concat-map, foldl} = require \prelude-ls
db = require \./config .connect!
courses = require \../web-ui/ma/data/courses.json

(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				"event.name": "transition"
				"event.toView.name": "Flashcard" # , "EOC", "Question", "EOQ"]
				"event.toView.chapterIndex": $exists: 1
				"event.toView.courseId": $exists: 1

				timeDelta: $exists: 1
				#serverTime: $gte: from-time, $lte: to-time
				country: {$exists: 1, $in: ['CA', 'IE']}
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
		}
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

console.log <| res |> sort-by (.users) |> map ((c)-> c <<< name: courses |> find (-> c.courseId == (parseInt it.id) ) |> (?.title?.en) )