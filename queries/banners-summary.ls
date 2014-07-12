{
	promises: {
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map} = require \prelude-ls


aggregate = (db, group-obj, match-obj = {}) ->
	(res, rej) <- new-promise
	group-operator = {
		uvisits: $sum: 1
		visits: $sum: "$visits"
		subscribers: $sum: { $cond: [ { $gt: [ "$sql.subscriberId", 0 ] } , 1, 0 ] }
		active12: $sum: { $cond: [ { $eq: [ "$sql.active12", true ] } , 1, 0 ] }
	} <<< group-obj
	db.reducedEvents.aggregate(
		[
			{
				$match:
					match-obj
			},
			{
				$project:
					_id: 1
					country: 1
					banner: 1
					visits: 1
					creativeId: 1
					placementId: 1
					siteId: 1
					"sql.subscriberId": 1
					"sql.active": 1
					"sql.active12": 1
					"sql.device.brand": 1
					"sql.device.model": 1
					"sql.device.marketing": 1
			},
			{
				$group: group-operator
			},
			{
				$sort:
					visits: -1
			}
		]
		, (err, results) ->
			return rej err if !!err
			res results
	)



# examples: 

query = (db) ->
	aggregate db, {
		_id: "$creativeId"
		banner: $first: "$banner"
	}

query = (db) ->
	aggregate db, {
		_id: "$siteId"
		banner: $first: "$banner"
	},
	{
		"creativeId": 'e8146c1d'
	}


module.exports = aggregate