
db = require("mongojs").connect \172.30.0.160:27017/Celtra-events, [\events]
fs = require \fs
json2csv = require \./json2csv.js
{map, Obj, fold, fold1} = require \prelude-ls

exit = (msg) ->
	db.close!
	console.log msg
	process.exit <| if !!msg then 1 else 0

process.on \exit, (code) ->
	db.close!
	console.log "Exiting #code"


query = (callback) ->
	db.events.find do 
		"eventArgs.userParams.SiteID": 
			$exists: true
		ip: $ne: "80.227.47.62"
	.sort $natural: -1
	, callback





(err, res) <- query
exit err if !!err

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
