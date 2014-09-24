{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!


query-from = moment "2014-07-11" .unix! * 1000
query-to   = moment "2014-08-18" .unix! * 1000
now = moment!.unix! * 1000


add-push-message = ->
	(res, error) <- db.IOSPushMessages.insert do
		{
			"alert" : "Homam 6",
			"device" : {
				"adId" : "11E6213D-AB12-40DF-9F67-67F2D21287CE",
				"token" : "e952f676cff4cb629217616664a508bbb757ecc929bfea037474e86a3f9b391f"
			},
			"payload" : {
				"type" : "Route",
				"viewControllerName" : "Chapter",
				"viewModelDefinition" : {
				"courseId" : 108,
				"resumeCourse" : true
				}
			}
			"sendTime": 1409061011000 #new Date!.getTime! - (1000 * 60 * 60 * 4)
			"userStatus" : null,
			"transmissionTime" : null,
			"transmissionStatus" : "pending"
		}

	console.log res, error
	
add-push-message!

return

filter-devices-that-support-push = (adIds, callback) ->

	(err, results) <- db.collection("IOSUsers").aggregate do 
		[
			{
				$match: 					
					"device.token": $exists: true					
					"device.adId": $in: adIds
			}
			{
				$sort: _id: 1	
			}			
			{
				$project:
					adId: "$device.adId"
					token: "$device.token"
					installed: "$gt": ["$creationTimestamp", "$ifNull": ["$lastUninstallTime", 0]]
			}
			{
				$match:
					installed: true
			}			
			{
				$group:
					_id: "$token"
					adId: $last: "$adId"
			}
		]        
	return callback err, null if err != null
	callback null, (results |> map ({_id, adId})-> token: _id, adId: adId)


(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"event.name": "transition"
				"event.toView.name": "Flashcard"
				"event.toView.chapterIndex": $exists: 1
				"event.toView.courseId": $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: query-from, $lte: query-to
				country: {$exists: 1, $in: ['CA', 'IE', 'US']}
		}
		{
			$project:
				adId: "$device.adId"
				course: "$event.toView.courseId"
				chapter: "$event.toView.chapterIndex" 
				card: "$event.toView.cardIndex"
				toSide: "$event.toView.side"
				fromSide: "$event.fromView.side"
				view: "$event.toView.name"
				serverTime: "$serverTime"

				installTime: $subtract: ["$serverTime", "$timeDelta"]
		}
		{
			$group: 
				_id: "$adId"

				flips: $sum: $cond: [$and: [{$eq: ["$toSide", "answer"]}, {$eq: ["$fromSide", "question"]}], 1, 0]
				lastAccess: $last: "$serverTime"
		}
		{
			$match:
				"flips": $gt: 9
				"lastAccess": $lt: (now - 2 * 24 * 60 * 60 * 1000)
		}
		{
			$project:
				_id: "$_id"
		}
	]

throw err if !!err
console.log res.length

(err, res) <- filter-devices-that-support-push (res |> map (._id))

throw err if !!err
console.log res
console.log res.length



db.close!