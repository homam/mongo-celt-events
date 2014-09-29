{
	promises: {
		serial-map
		promise-monad
		new-promise
		from-error-only-callback
		from-error-value-callback
		to-callback
	}
} = require \async-ls
{map, id, concat-map, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
fs = require \fs
format-json = (obj) ->
	JSON.stringify obj, null, 4

start = moment \2014-09-05 


promise = [start.clone!.add \days, i for i in [0 to 22]] |> serial-map (date) ->
	succ, rej <- new-promise
	err, json <- fs.read-file "usage-data/#{date.format "YYYY-MM-DD"}.json", \utf8
	return rej err if !!err
	succ <| JSON.parse json


(err, res) <- to-callback promise
return console.log \error, err if !!err
console.log <| format-json <| res |> concat-map id