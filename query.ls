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
sql = require \mssql
fs = require \fs

db = require("mongojs").connect \localhost/Celtra-events, [\events, \reducedEvents]

query = ->
	(res, rej) <- new-promise
	db.reducedEvents
	.find {},
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
	.limit 10
	, (err, results) ->
		return rej err if !!err
		res results


query = ->
	(res, rej) <- new-promise
	db.reducedEvents.aggregate(
		[
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
				$group:
					_id: "$sql.device.marketing"
					uvisits: $sum: 1
					visits: $sum: "$visits"
					subscribers: $sum: { $cond: [ { $gt: [ "$sql.subscriberId", 0 ] } , 1, 0 ] }
			},
			{
				$sort:
					subscribers: 1
			}
		]
		, (err, results) ->
			return rej err if !!err
			res results
	)

(err, res) <- to-callback <| query!
console.log \error, err if !!err
console.log "results", res
db.close!