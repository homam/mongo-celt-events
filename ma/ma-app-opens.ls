{map, sort, sort-by, mean, filter, first, group-by, flatten, foldl} = require \prelude-ls
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24

now = new Date! .get-time!

first-day = 16259
today = now / one-day - ((now / one-day)%1)

from-time = first-day * one-day
to-time = today * one-day + one-day


# last-day = new Date! .get-time!
# last-day := (last-day/one-day)-((last-day/one-day)%1)

# first-day = last-day - 7

# now = new Date! .get-time!

(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: from-time, $lte: to-time
				country: {$exists: 1, $ne: 'AE'}
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

				# number of days passed since installation
				# eventDate: $subtract: [{$divide: ["$eventDate", one-day]}, {$mod: [{$divide: ["$eventDate", one-day]}, 1]}]
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
		}
		{
			$group:
				_id: "$_id.installationDate"
				values: 
					$push: 
						daysAfterInstallation: "$_id.daysAfterInstallation"
						users: "$users"
		}
		# {
		# 	$group:
		# 		_id: 
		# 			adId: "$adId"
		# 			eventDate: "$eventDate" 
		# 			daysAfterInstallation: "$daysAfterInstallation"
		# }
		# {
		# 	$group:
		# 		_id: 
		# 			eventDate: "$_id.eventDate"
		# 			daysAfterInstallation: "$_id.daysAfterInstallation"
		# 		opened: $sum: 1
		# }
	]


console.log err
res = res |> sort-by (._id) |> map (-> {day:it._id} <<< (values: it.values |> sort-by (.daysAfterInstallation)) )


console.log <| [0 to 10] |> map (j) ->
		[base, users] = res 
			|> filter (({day, values})-> day <= today - j) 
			|> map (.values) |> flatten 
			|> foldl (([base, usage], {daysAfterInstallation, users}) -> 
				[base + if daysAfterInstallation == 0 then users else 0, usage + if daysAfterInstallation == j then users else 0] ), [0, 0]
		{day: j, base, users, ratio: users/base}
		#{day: j, base: base, users: users}

db.close!
return

console.log <| JSON.stringify res, null, 2
#console.log <| res |> sort-by -> it._id.installationDate*1000+it._id.daysAfterInstallation
db.close!