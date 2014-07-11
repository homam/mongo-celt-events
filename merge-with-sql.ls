#!/usr/local/bin/lsc

# db = require("mongojs").connect \172.30.0.160:27017/Celtra-events, [\events, \reducedEvents]
db = require("mongojs").connect \localhost/Celtra-events, [\events, \reducedEvents]

fs = require \fs
{
	promises: {
		promise-monad
		serial-sequence
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map, find, Obj, fold, fold1} = require \prelude-ls
{update-reduced-events} = require \./reduce-events
{query-sql, fake-query-sql} = require \./query-sql

exit = (msg) ->
	db.close!
	console.log msg
	process.exit <| if !!msg then 1 else 0

process.on \exit, (code) ->
	db.close!
	console.log "Exiting #code"


batch-process = (query-sql, batch-size, db) -->
	update-reduced-events db
		|> promise-monad.fbind ->
			(res, rej) <- new-promise
			db.reducedEvents
			.find sql: $exists: false
			.sort $natural: 1
			.limit batch-size
			, (err, records) ->
				return rej err if !!err
				res records
		|> promise-monad.fbind (records) ->
			query-sql <| map (._id), records
		|> promise-monad.fbind (records) ->
			serial-sequence <|
				records |> map (r) ->
					(res, rej) <- new-promise 
					db.reducedEvents.update do
						_id: r.visitId
						{
							$set: 
								sql:
									subscriberId: r.subscriberId
									submissionId: r.submissionId
									active: r.active
									active12: r.active12
									device:
										brand: r.brand_name
										model: r.model_name
										marketing: r.marketing_name
						}
						(err, results) ->
							return rej err if !!err
							res results
					


do-batch-process = -> batch-process fake-query-sql, 500, db

do-batch-process-loop = (processd-count = 0) ->
	console.log \do-batch-process-loop
	do-batch-process!
		|> promise-monad.fbind (res) ->
			if !!res and res.length > 0
				do-batch-process-loop processd-count + res.length
			else
				promise-monad.pure processd-count
#(err, res) <- to-callback <| batch-process fake-query-sql, 5000, db
(err, res) <- to-callback do-batch-process-loop!
console.log \error, err if !!err
console.log "Updated #{res}"
db.close!

return



# CSV conversion

_ <- fs.write-file \./results.json, (JSON.stringify res, null, 4)

res := res |> map -> {
	it.viewId
	siteId: it.eventArgs?.userParams?.SiteID
	creativeId: it.eventArgs?.creativeId
	placementId: it.eventArgs?.placementId
	it.countryCode
	it.creationTime
	it.userId
	it.uaId
	it.sessionId }


fix-commas = ->
	s = it + ""
	if (s.index-of ',') > -1 then "\"#s\"" else s

all-keys = (Obj.keys res[0])
csv =  res |> map ((r) ->
		fold ((acc,k)-> acc += (if !!acc then ', ' else '') + fix-commas r[k]), '', all-keys ) 

# head, first row
csv = [(fold ((acc, k) -> acc += (if !!acc then ', ' else '') + fix-commas k), '', all-keys)] ++ csv

csv = csv |> (fold1 ((acc,a) -> acc + '\n' + a))

_ <- fs.write-file \./results.csv, csv

exit null
