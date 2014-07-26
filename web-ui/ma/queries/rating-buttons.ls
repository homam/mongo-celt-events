{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj, maximum} = require \prelude-ls


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->
	(success, reject) <- new-promise
	(err, res) <- db.IOSEvents.aggregate do 
		[
			{
				$match: 
					"event.name":"ratePopupDismissed" 
					timeDelta: $exists: 1
					country: {$in: ["CA", "IE"]}
					serverTime: $gte: query-from, $lte: query-to

			}
			{
				$project:
					event:1
					userId:1
					installTime: $subtract: ["$serverTime", "$timeDelta"]					

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
					_id: "$event.buttonKey"
					count: $sum: 1
			}
		]

		return reject err if !!err
		success res

module.exports = query
