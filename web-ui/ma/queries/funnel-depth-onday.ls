# > http://localhost:3002/query/daily-depth/2014-07-10/2014-07-25/CA,IE/5/2014-07-10/2014-07-25

{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj, maximum} = require \prelude-ls


depths = {"": 0, "Home":1, "Chapter":2, "Flashcard":3, "EOC":4, "Question":5, "EOQ":6, "Subscription": 7}


one-hour = 1000*60*60
one-day =  one-hour*24



# today = now / one-day - ((now / one-day)%1)


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = null) ->
	(success, reject) <- new-promise

	install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * 24 * 60 * 60 * 1000)

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					
					timeDelta: $lte: (how-many-days+1) * one-day, $gte: how-many-days * one-day
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
			}
			{
				$project:
					adId: "$device.adId"
					timeDelta: 1

					# days passed since installation
					date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
					
					eventDate: $subtract: ["$serverTime", "$timeDelta"]

					view: "$event.toView.name"

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
					_id: 
						adId: "$adId"
						view: "$view"
					users: $sum: 1
			}
			{
				$group:
					_id: "$_id.view"
					users: $sum: $cond: [$gt: ["$users", 0], 1, 0]
			}
		]


	return reject err if !!err

	success <| res |> (map ({_id, users}) -> view: _id, users: users) |> sort-by (.users * -1) |> (filter ({view}) -> view is null or !!depths[view]) # |> (filter ({view}) -> !!depths[view]) |> (sort-by ({view, users}) -> depths[view])

module.exports = query
