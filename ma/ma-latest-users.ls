db = require \./config .connect!

query = (callback) ->
	db.IOSUsers.aggregate do
		[
			{
				$sort:
					_id: -1
			}
			{
				$limit: 20
			}
			{
				$project:
					_id: 1
					name: "$device.name"
					model: "$device.model"
					ios: "$device.systemVersion"
					country: "$country"
					time: "$creationTimestamp"

			}
		]
		callback


(err, res) <- query
console.log "Error", err if !!err

console.log <| res

db.close!