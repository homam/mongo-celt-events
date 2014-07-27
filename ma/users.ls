# The ratio of users that have been using the app on their j_th day after installation.


{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl} = require \prelude-ls
moment = require \moment

to-unix-time = (s) ->
	(moment s).unix! * 1000 

db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24

now = new Date! .get-time!
today = now / one-day - ((now / one-day)%1)


sample-from = to-unix-time \2014-07-20
sample-to = to-unix-time \2014-07-28

query-from = to-unix-time \2014-07-20
query-to = to-unix-time \2014-07-28


(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: query-from, $lte: query-to
				country: {$exists: 1, $in: ['CA', 'IE']}
		}
		{
			$project:
				adId: "$device.adId"
				timeDelta: 1
				installTime: $subtract: ["$serverTime", "$timeDelta"]
				daysAfterInstallation: $subtract: [$divide: ["$timeDelta", one-day], {$mod: [$divide: ["$timeDelta", one-day], 1]}]

		}
		{
			$match:
				installTime: $gte: sample-from, $lte: sample-to
				#daysAfterInstallation: $lt: 0
		}
		{
			$group:
				_id: "$adId"
				daysAfterInstallation: $first: "$daysAfterInstallation"
		}
	]

console.log err if !!err
console.log res

return


(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: query-from, $lte: query-to
				country: {$exists: 1, $in: ['CA', 'IE']}
		}
		{
			$project:
				adId: "$device.adId"
				timeDelta: 1

				# days passed since installation
				daysAfterInstallation: $subtract: [$divide: ["$timeDelta", one-day], {$mod: [$divide: ["$timeDelta", one-day], 1]}]
				
				eventDate: $subtract: ["$serverTime", "$timeDelta"]
		}
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
					adId: "$adId"
				users: $sum: 1
		}
		{
			$group:
				_id: 
					daysAfterInstallation: "$_id.daysAfterInstallation"
					installationDate: "$_id.installationDate"
				users: $sum: $cond: [{$gt: ["$users", 0]} , 1, 0]
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


console.log err if !!err

res = res |> sort-by (._id) |> map (-> {day:it._id} <<< (values: it.values |> sort-by (.daysAfterInstallation)) )


console.log <| [0 to 10] |> map (j) ->
		[base, users] = res 
			|> filter (({day, values}) -> day <= today - j) 
			|> concat-map (.values)
			|> foldl (([base, usage], {daysAfterInstallation, users}) -> 
				[base + if daysAfterInstallation == 0 then users else 0, usage + if daysAfterInstallation == j then users else 0] ), [0, 0]
		{day: j, base, users, ratio: users/base}

db.close!
