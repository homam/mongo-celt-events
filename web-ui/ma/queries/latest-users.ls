{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls

query = (db, limit) ->
	limit = limit or 20
	(success, reject) <- new-promise
	db.IOSUsers.aggregate do
		[
			{
				$sort:
					_id: -1
			}
			{
				$limit: limit
			}
			{
				$project:
					_id: 1
					latestReceipt: 1
					name: "$device.name"
					model: "$device.model"
					ios: "$device.systemVersion"
					country: "$country"
					time: "$creationTimestamp"
			}
		]
		(err, res) ->
			return reject err if !!err
			success res


module.exports = query