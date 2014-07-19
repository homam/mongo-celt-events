{
	promises: {
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map, sort-by} = require \prelude-ls
sql = require \mssql
fs = require \fs

db = require("mongojs").connect \localhost/Celtra-events, [\events, \reducedEvents]

_query = ->
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
		"creationTimes": $slice: 1
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

_query = ->
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


query = ->
	(res, rej) <- new-promise
	db.reducedEvents.aggregate(
		[
			# {
			# 	$project:
			# 		_id: 1
			# 		creationTimes: $slice: 1
			# 		country: 1
			# 		banner: 1
			# 		visits: 1
			# 		creativeId: 1
			# 		placementId: 1
			# 		siteId: 1
			# 		"sql.subscriberId": 1
			# 		"sql.device.marketing": 1

			# },
			{
				$group:
					_id: $avg: "$creationTimes"
					uvisits: $sum: "$uvisits"
					visits: $sum: "$visits"
					subscribers: $sum: "$subscribers"
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


# using keyf
query = ->
	(res, rej) <- new-promise
	db.reducedEvents.group(
		{
			#cond: "sql.subscriberId": $ne: null
			keyf: (-> 
				t = it.creationTimes.0
				time: "#{t.get-full-year!}-#{t.get-month! + 1}-#{t.get-date!}"
			)
			reduce: (a, acc) ->
				acc.uvisits += 1
				acc.visits += a.visits
				acc.subscribers += if !!a.subscriberId then 1 else 0
				acc
			initial: uvisits: 0, visits: 0, subscribers: 0
		}, (err, results) ->
			return rej err if !!err
			res results
	)


query = ->
	(res, rej) <- new-promise
	db.reducedEvents.map-reduce do
		-> 
			t = this.creationTimes[0]
			pad-left = (d) ->
				if (d+"").length == 1 then "0#d" else "#d"
			#key = new ISODate "#{t.get-full-year!}-#{pad-left <| t.get-month! + 1}-#{pad-left t.get-date!}T00:00:00.000Z"
			key = new Date t.getFullYear() , t.getMonth(), t.getDate()
			is-subscribed = if this.sql?.subscriberId == null then 0 else 1
			emit key, {visits: this.visits, subscribers: is-subscribed }
		(key, values) ->
			values.reduce do
				(acc, a) ->
					acc.visits += a.visits;
					acc.subscribers += a.subscribers;
					acc
				{visits: 0, subscribers: 0}
		out: inline: 1
		(err, results) ->
			return rej err if !!err
			res results
	# in shell:
	# db.run-command(
	# 	{
	# 		map-reduce: 'reducedEvents'
	# 		map: -> 
	# 			t = this.creationTimes[0]
	# 			key = "#{t.get-full-year!}-#{t.get-month! + 1}-#{t.get-date!}"
	# 			emit(key, this.visits)
	# 		reduce: (key, values) ->
	# 			return Array.sum(values)
	# 		out: inline: 1
	# 	}, (err, results) ->
	# 		return rej err if !!err
	# 		res results
	# )



query = ->
	(res, rej) <- new-promise
	db.events.map-reduce do
		-> 
			t = this.creationTime
			# pad-left = (d) ->
			# 	if (d+"").length == 1 then "0#d" else "#d"
			#key = new ISODate "#{t.get-full-year!}-#{pad-left <| t.get-month! + 1}-#{pad-left t.get-date!}T00:00:00.000Z"
			#key = new Date t.getFullYear() , t.getMonth(), t.getDate()
			#is-subscribed = if this.sql?.subscriberId == null then 0 else 1
			emit this.userId, 0
			emit this.userId, this.creationTime
		(key, values) ->
			one-day = 1000*60

			values.filter (!=0) .sort!.reduce do
				(acc, a) ->
					if (a - acc.mint) > one-day
						acc.visits += 1
						acc.mint = a
					acc
				{visits: 0, mint: 0}
		{out: {inline: 1}, query: {"countryCode": "JO"}}
		(err, results) ->
			return rej err if !!err
			res results

(err, res) <- to-callback <| query!
console.log \error, err if !!err
console.log "results", (res |> sort-by (._id))
db.close!