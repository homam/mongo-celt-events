{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, fold, find-index, reverse} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24

fill-in-the-gaps = (query-from, query-to, days) -->

	empty-list = [query-from to query-to by 86400000]  |> map -> {day: (it - it % 86400000) / 86400000 visits: 0, installs: 0, conversion: 0}	

	days |> fold ((memo, value)-> 
		index = empty-list |> find-index -> it.day == value.day
		memo[index] = value if !!index
		memo
	),  empty-list
	

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->	
	(success, reject) <- new-promise
	
	query-from -= (new Date()).getTimezoneOffset() * 60000
	query-to -= (new Date()).getTimezoneOffset() * 60000

	db.IOSAdVisits.aggregate do
		[
			{
				$match:	
					country: $in: countries
					creationTimestamp: $gte: query-from, $lte: query-to
			}						
			{
				$project:
					day: $divide: [$subtract: ["$creationTimestamp", $mod: ["$creationTimestamp", 86400000]], 86400000]
					source: 1
					userId: $ifNull: ["$userId", "-"]
			}
			{
				$group:
					_id: 
						day: "$day"
						source: "$source"
					visits: $sum: 1
					installs: $sum: {$cond: [$eq: ["$userId", "-"], 0, 1]}
			}
			{
				$group:
					_id: source: "$_id.source"
					days: $push: 
						day: "$_id.day", 
						visits: "$visits", 
						installs: "$installs", 
						conversion: $divide: ["$installs", "$visits"]
			}			
		]
		(err, res) ->
			return reject err if !!err
			success <| res |> map ({_id, days}) ->
				source: _id.source
				days: days |> (fill-in-the-gaps query-from, query-to)
				conversion: days |> map (.conversion) |> mean
			|> sort-by (.conversion) |> reverse 

module.exports = query