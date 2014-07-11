{
	promises: {
		promise-monad
		new-promise
		from-error-value-callback
		to-callback
	}
} = require \async-ls

reduce = (db, min-user-id) -->
	query = {}
	if !!min-user-id
		query["userId"] = $gt: min-user-id

	(resolve, reject) <- new-promise
	db.events.aggregate(
		[
			{
				$match: query
			},
			{
				$project:
					"viewId": 1
					"countryCode": 1
					"eventArgs.userParams.SiteID": 1
					"eventArgs.creativeId": 1
					"eventArgs.placementId": 1
					"eventType": 1
					"userId": 1
					"uaId": 1
					"creationTime": 1
			}, 
			{
				$group:
					_id: "$userId",
					visits: $sum: 1
					
					creationTimes: $addToSet: "$creationTime"
					creativeId: $first: "$eventArgs.creativeId"
					placementId: $first: "$eventArgs.placementId"
					siteId: $first: "$eventArgs.userParams.SiteID"
					country: $first: "$countryCode"
					uaId: $first: "$uaId"
					banner: $first: "$viewId"
			}
		], 
		(err, res) ->
			return reject err if !!err
			resolve res
	)

insert-reduced-events = (db, events) -->
	(resolve, reject) <- new-promise
	return resolve null if !events or events.length == 0
	db.reducedEvents.insert events, (err, res) ->
		return reject err if !!err
		resolve res


last-reduced-user-id = (db) ->
	(resolve, reject) <- new-promise
	return resolve 0 if !db.reducedEvents
	db.reducedEvents.findOne do
		$query: {}
		$orderby: _id: -1
		(err, res) ->
			return reject err if !!err
			resolve res?._id


update-reduced-events = (db) ->
	last-reduced-user-id db
		|> promise-monad.fbind (reduce db)
		|> promise-monad.fbind (insert-reduced-events db)


exports.update-reduced-events = update-reduced-events