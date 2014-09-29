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
{map, filter, find, id, sum, concat-map, country, count-by, group-by, obj-to-pairs, sort, sort-by, mean} = require \prelude-ls
moment = require \moment
fs = require \fs
format-json = (obj) ->
	JSON.stringify obj, null, 4

start = moment \2014-09-05 


promise = [start.clone!.add \days, i for i in [0 to 22]] |> serial-map (date) ->
	succ, rej <- new-promise
	err, json <- fs.read-file "usage-data/#{date.format "YYYY-MM-DD"}.json", \utf8
	return rej err if !!err
	usage = (JSON.parse json) |> filter (.day == 0) |> map (-> {country: it.countryCode, uvisits: it.uvisits})
	err, json <- fs.read-file "data/#{date.format "YYYY-MM-DD"}.json", \utf8
	return rej err if !!err
	users = (JSON.parse json) |> count-by (.country) |> obj-to-pairs |> map ([country, subscribers]) -> country: country, subscribers: subscribers

	joint = users |> map ({country, subscribers}) ->
		ucoutry = country
		uvisits = usage |> filter (({country, uvisits}) -> country == ucoutry) |> map (.uvisits) |> sum
		{country, uvisits, subscribers: subscribers}

	# console.log joint
	succ <| joint


(err, res) <- to-callback promise
return console.log \error, err if !!err
console.log <| format-json <| res |> (concat-map id) |> group-by (.country) |> obj-to-pairs 
	|> map ([country, list]) -> [country, uvisits: (list |> map (.uvisits) |> sum), subscribers: (list |> map (.subscribers) |> sum)]
	|> map ([country, {uvisits, subscribers}]) -> {country, subscribers, uvisits}