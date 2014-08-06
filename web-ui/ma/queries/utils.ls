{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, maximum} = require \prelude-ls

exports.get-devices-from-media-sources = (db, sources, callback)->

	return callback null, null if !sources 

	(err, result) <- db.IOSUsers.aggregate do
		[
			{
				$project:
					adId: "$device.adId"
					source: $concat: [$ifNull: ["$appsFlyer.media_source", "others"], "|", $ifNull: ["$appsFlyer.adgroup", ""]]					
			}
			{
				$match:
					source: $in: sources
			}			
		]
	return callback err, null if err != null
	callback null, (result |> map (.adId))