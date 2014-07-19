{map, sort, sort-by, mean} = require \prelude-ls
db = require("mongojs").connect \localhost/MA, [\IOSEvents]
one-day =  1000*60*60*24
from-time = 0*one-day
to-time = 2*one-day


query = (callback) ->
	db.IOSEvents.aggregate do
		[
			{
				$match:
					"device.adId": $exists: 1
					sessionNumber: $exists: 1
					subSessionNumber: $exists: 1
					timeDelta: $gte:from-time, $lte: to-time
			}
			{
				$group: 
					_id: {
						adId: "$device.adId"
						session: $add: [$multiply: ["$sessionNumber", 1000], "$subSessionNumber"]
					}
					minDelta: $min: "$timeDelta"
					maxDelta: $max: "$timeDelta"
			}
			{
				$project:
					_id: "$_id.adId",
					duration: $subtract: ["$maxDelta", "$minDelta"]
			}
			{
				$group: 
					_id: "$_id"
					duration: $sum: "$duration"
			}
		]
		callback

(err, res) <- query
console.log "Error", err if !!err
res = res |> map (.duration) >> (/1000) >> Math.round
	|> sort


variance = (avg, res) -> 
	res |> (map -> (it - avg)^2) |> mean

median = (res) ->
	i = Math.floor(res.length / 2)
	res[i]

quantile = (res) ->
	left = Math.floor (res.length / 4)
	right = left * 3
	res[left to right]

console.log res.length

res = quantile res
console.log <| res |> mean >> Math.round
console.log <| variance (mean res), res |> Math.sqrt >> Math.round

db.close!