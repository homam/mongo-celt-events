{map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
db = require \./config .connect!

one-hour = 1000*60*60
one-day =  one-hour*24

from-time = 0*one-day
to-time = 10*one-day

query-from = moment "2014-07-15" .unix! * 1000
query-to   = moment "2014-07-30" .unix! * 1000

sample-from = null
sample-to = null


(err, res) <- db.IOSEvents.aggregate do 
	[
		{
			$match: 
				"event.name":"ratePopupDismissed" 
				timeDelta: $exists: 1
				country: {$in: ["CA", "IE"]}
				serverTime: $gte: query-from, $lte: query-to

		}
		{
			$project:
				event:1
				userId:1

				date: $subtract: [{$divide: ["$timeDelta", one-day]}, {$mod: [{$divide: ["$timeDelta", one-day]}, 1]}]
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
					button: "$event.buttonKey"
					date: "$date"
				count: $sum: 1
		}
		{
			$group:
				_id: "$_id.date"
				remind: $sum: $cond: [{$eq: ["$_id.button", "Remind_Me_Later"]}, "$count", 0]
				never: $sum: $cond: [{$eq: ["$_id.button", "Never_Show_Rate_Popup_Again"]}, "$count", 0]
				rate: $sum: $cond: [{$eq: ["$_id.button", "Rate_Now"]}, "$count", 0]
		}
	]


console.log err if !!err
console.log res
# db.IOSEvents.find({"userId":"53d20503377dad777434f58f", "_id": {$lte: ObjectId("53d207a693bc347474156115")}}).sort({$natural:-1}).limit(2).pretty()