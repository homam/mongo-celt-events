#!/usr/local/bin/lsc

db = require("mongojs").connect \172.30.0.160:27017/Celtra-events, [\events]
sql = require \mssql
fs = require \fs
{map, Obj, fold, fold1} = require \prelude-ls

exit = (msg) ->
	db.close!
	console.log msg
	process.exit <| if !!msg then 1 else 0

process.on \exit, (code) ->
	db.close!
	console.log "Exiting #code"

config =
	user: 'Mobitrans_EF_User'
	password: 'g^h8yt#H'
	server: '172.30.0.165'
	database: 'Mobitrans'




query = (callback) ->
	db.events.find do 
		"eventArgs.userParams.SiteID": 
			$exists: true
		ip: $ne: "80.227.47.62"
	.sort $natural: -1
	.limit 10
	, callback





(err, res) <- query
exit err if !!err

#TODO: First reduce the events then merge it with SQL
sql-query = fs.readFileSync 'sql-queries/sql-query.sql', 'utf8'
sql-query = sql-query.replace "{{VIDs}}", (( map (.userId)) <| res)

(err) <- sql.connect config
exit err if !!err

request = new sql.Request!

(err, sql-records) <- request.query sql-query
exit err if !!err

updaters = sql-records |> map (r) -> -> 
	console.log "Updating #{r.VID}"
	db.events.update do
		userId: r.VID
		{
			$set: 
				merged:
					sid: r.SubscriberId
					submissionId: r.RequestId
					active: r.Active
					active12: r.Active_12
					device:
						brand: r.brand_name
						model: r.model_name
						marketing: r.marketing_name
		} 



console.log updaters.0!
console.log updaters.2!

#TODO: update node

return exit null



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
