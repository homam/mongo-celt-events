{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, maximum} = require \prelude-ls

query = (db) ->
	(success, reject) <- new-promise	
	(err, result) <- db.IOSUsers.aggregate do 
		[
			{
				$project:
					source: $concat: [$ifNull: ["$appsFlyer.media_source", "others"], "|", $ifNull: ["$appsFlyer.adgroup", ""]]
			}
			{
				$group:
					_id: "$source"
			}
			{
				$sort:
					_id: 1
			}
		]	
	return reject err if !!err
	success <| result |> map (._id)

module.exports = query