{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment

one-hour = 1000*60*60
one-day =  one-hour*24

get-devices = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10, user-payment-status, callback)->

	(err, results) <- db.IOSEvents.aggregate do
		[ 
			{
				$match:
					country: $in: countries
					"event.name": "IAP-Purchased"

					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					timeDelta: $exists: 1
					serverTime: $gte: query-from, $lte: query-to
			}
			{
				$project:
					adId: "$device.adId"
					name: "$device.name"    
			}
			{
				$group:
					_id: "$adId"    
			}
		]
	return callback err, null if err != null
	callback null, (results |> map (._id))


query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, how-many-days = 10, user-payment-status) ->

	(success, reject) <- new-promise

	install-time-to = (Math.min query-to, (new Date! .get-time!)) - (how-many-days * one-day)

	(err, devices) <- get-devices db, query-from, query-to, countries, sample-from, sample-to, how-many-days, user-payment-status

	query = [
		{	
			$match:
				"device.adId":
					if user-payment-status == "purchased"
						$in: devices
					else if user-payment-status == "free"
						$nin: devices
					else if user-payment-status == "all"
						{$exists: 1}

		}
		{
			$match:										
				sessionNumber: $exists: 1
				subSessionNumber: $exists: 1
				timeDelta: $exists: 1
				serverTime: $gte: query-from, $lte: query-to
				country: {$exists: 1} <<< if !!countries then $in: countries else {}
		}
		{
			$project:
				"device.adId": 1
				session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
				timeDelta: 1
				date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
				installTime: $subtract: ["$serverTime", "$timeDelta"]
		}
		{
			$match:
				date: $lte: how-many-days
				installTime: $lte: install-time-to
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
				_id: {
					adId: "$device.adId"
					session: "$session"
				}
				minDelta: $min: "$timeDelta"
				maxDelta: $max: "$timeDelta"
		}
		{
			$project:
				_id: 1
				duration: $subtract: ["$maxDelta", "$minDelta"]
		}
		{
			$group: 
				_id: adId: "$_id.adId"
				sessions: $sum: 1
				avgSessionDuration: $avg: "$duration"
				duration: $sum: "$duration"
		}
		{
			$project:
				_id: "$_id"
				duration: $subtract: [{$divide: ["$duration", 60*1000]}, {$mod: [{$divide: ["$duration", 60*1000]}, 1]}]
		}
		{
			$group:
				_id: "$duration"
				users: $sum: 1
		}
	]

	(err, res) <- db.IOSEvents.aggregate query		

	return reject err if !!err

	success <| res |> sort-by (._id)


module.exports = query
