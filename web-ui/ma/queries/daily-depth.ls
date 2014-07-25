# > http://localhost:3002/query/daily-depth/2014-07-10/2014-07-25/CA,IE/5/2014-07-10/2014-07-25

{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj, maximum} = require \prelude-ls


# depths = {"Home":1, "Chapter":2, "Flashcard":3, "EOC":4, "Question":5, "EOQ":6}


one-hour = 1000*60*60
one-day =  one-hour*24



# today = now / one-day - ((now / one-day)%1)


query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->
	(success, reject) <- new-promise
	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
					#"event.name": "transition"
					#"event.toView.name": $in: (Obj.keys depths)
			}
			{
				$project:
					adId: "$device.adId"
					timeDelta: 1

					# days passed since installation
					daysAfterInstallation: $subtract: [$divide: ["$timeDelta", one-day], {$mod: [$divide: ["$timeDelta", one-day], 1]}]
					
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
				$project:
					adId: 1
					daysAfterInstallation: 1
					installationDate: $subtract: ["$eventDate", "$daysAfterInstallation"]
					view: 1
			}
			{
				$project:
					adId: 1
					daysAfterInstallation: 1
					installationDate: $subtract: [$divide: ["$installationDate", one-day], {$mod: [$divide: ["$installationDate", one-day], 1]}]
					view: 1
			}
			{
				$group:
					_id: 
						daysAfterInstallation: "$daysAfterInstallation"
						installationDate: "$installationDate"
						view: "$view"
					users: $addToSet: "$adId"
			}
			{
				$unwind: "$users"
			}
			{
				$group:
					_id: 
						daysAfterInstallation: "$_id.daysAfterInstallation"
						installationDate: "$_id.installationDate"
						view: "$_id.view"
					users: $sum: 1
					#indies: $push: "$users"
			}
			{
				$group:
					_id: "$_id.installationDate"
					values: 
						$push: 
							daysAfterInstallation: "$_id.daysAfterInstallation"
							view: "$_id.view"
							users: "$users"
							#indies: "$indies"
			}
		]


	return reject err if !!err


	now = new Date! .get-time!
	n = Math.min now, query-to
	today = n / one-day - ((n / one-day)%1)

	res = res |> sort-by (._id) |> map (-> {day:it._id} <<< (values: it.values |> sort-by (.daysAfterInstallation)) )

	how-many-days = res |> map (-> today - it.day) |> maximum

	success <| [0 to how-many-days] |> map (j) ->
			[base, users] = res 
				|> filter (({day, values}) -> day <= today - j) 
				|> concat-map (.values)
				|> foldl do 
					([base, usage], {daysAfterInstallation, view, users}) ->
						view = "Others" if not view or view == ""
						usage[view] = 0 if not usage[view]
							
						[
							* base + if daysAfterInstallation == 0 and "Home" == view then users else 0
							* usage <<< (usage[view] += if daysAfterInstallation == j then users else 0)
						]
					[0, {}]
			{day: j, base, users} # , ratio: users/base}

module.exports = query
