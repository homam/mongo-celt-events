{map, sort, sort-by, mean} = require \prelude-ls
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24
from-time = 0*one-day
to-time = 10*one-day

now = new Date! .get-time!

# last-day = new Date! .get-time!
# last-day := (last-day/one-day)-((last-day/one-day)%1)

# first-day = last-day - 7

# now = new Date! .get-time!

(err, res) <- db.IOSEvents.aggregate do
	[
		{
			$match:
				"device.adId": $exists: 1
				timeDelta: $gte:from-time, $lte: to-time
		}
		{
			$project:
				adId: "$device.name"
				timeDelta: 1

				# days passed since installation
				daysAfterInstallation: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
				

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
				installationDate: $subtract: [{$divide: ["$installationDate", one-day]}, {$mod: [{$divide: ["$installationDate", one-day]}, 1]}]
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
console.log <| res |> sort-by -> it._id.installationDate*1000+it._id.daysAfterInstallation
db.close!