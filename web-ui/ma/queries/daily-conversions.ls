{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->	
	(success, reject) <- new-promise
	db.IOSAdVisits.aggregate do
		[
			{
				$match:	
					country: $in: ["CA", "IE"]
					creationTimestamp: $gte: query-from, $lte: query-to
			}						
			{
				$project:
					day: $divide: [$subtract: ["$creationTimestamp", $mod: ["$creationTimestamp", 86400000]], 86400000]
					source: 1
					userId: $ifNull: ["$userId", "-"]
			}
			{
				$group:
					_id: 
						day: "$day"
						source: "$source"
					visits: $sum: 1
					installs: $sum: {$cond: [$eq: ["$userId", "-"], 0, 1]}
			}
			{
				$group:
					_id: source: "$_id.source"
					days: $push: 
						day: "$_id.day", 
						visits: "$visits", 
						installs: "$installs", 
						conversion: $divide: ["$installs", "$visits"]
			}
		]
		(err, res) ->
			return reject err if !!err
			success <| res

module.exports = query