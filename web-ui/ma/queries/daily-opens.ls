# The ratio of users that have been using the app on their j_th day after installation.
# > http://localhost:3002/query/app-opens/2014-07-01/2014-08-01/30

{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, maximum} = require \prelude-ls
utils = require "./utils"

one-hour = 1000*60*60
one-day =  one-hour*24

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->

	now = new Date! .get-time! 
	today = now / one-day - ((now / one-day)%1)
	
	(success, reject) <- new-promise
	
	(err, devices) <- utils.get-devices-from-media-sources db, sources	
	return reject err if !!err

	(err, res) <- db.IOSEvents.aggregate do
		[
			{
				$match:										
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
					country: {$exists: 1} <<< if !!countries then $in: countries else {}
					"device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
			}
			{
				$project:
					adId: "$device.adId"
					timeDelta: 1
					installTime: $subtract: ["$serverTime", "$timeDelta"]
					# days passed since installation
					daysAfterInstallation: $subtract: [$divide: ["$timeDelta", one-day], {$mod: [$divide: ["$timeDelta", one-day], 1]}]					
					eventDate: $subtract: ["$serverTime", "$timeDelta"]
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
			}
			{
				$project:
					adId: 1
					daysAfterInstallation: 1
					installationDate: $subtract: [$divide: ["$installationDate", one-day], {$mod: [$divide: ["$installationDate", one-day], 1]}]
			}
			{
				$group:
					_id: 
						daysAfterInstallation: "$daysAfterInstallation"
						installationDate: "$installationDate"
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
					users: $sum: 1
					#indies: $push: "$users"
			}
			{
				$group:
					_id: "$_id.installationDate"
					values: 
						$push: 
							daysAfterInstallation: "$_id.daysAfterInstallation"
							users: "$users"
							#indies: "$indies"
			}
		]

	return reject err if !!err

	res = res |> sort-by (._id) |> map (-> {day:it._id} <<< (values: it.values |> sort-by (.daysAfterInstallation)) )

	how-many-days = res |> map (-> today - it.day) |> maximum

	result = [0 to how-many-days] |> map (j) ->
			[base, users] = res 
				|> filter (({day, values}) -> day <= today - j) 
				|> concat-map (.values)
				|> foldl (([base, usage], {daysAfterInstallation, users}) -> 
					[base + if daysAfterInstallation == 0 then users else 0, usage + if daysAfterInstallation == j then users else 0] ), [0, 0]
			{day: j, base, users, ratio: users/base}

	success <| result

module.exports = query