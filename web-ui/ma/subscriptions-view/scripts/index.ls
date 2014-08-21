{
	from-error-value-callback
	promise-monad
	parallel-sequence
	serial-sequence
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj, drop, zip-with} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-27"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

input-date \queryFrom .value = moment!.add \days, -21 .format \YYYY-MM-DD\
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

data-cols = []
data-rows = []

sources = "-"

document.getElementById \main-controls .add-event-listener do 
	\submit
	-> 
		data-cols := []
		data-rows := []
		sources := media-source-tree.getSelectedSources!.join!
		update!
		query!
		it.preventDefault!
		return false
	true

$table = d3.select \table#main

update = ->
	
	$table.select \thead .select \tr .select-all \th
	.data data-cols
		..enter!
			.append \th
			.text id
		..exit!.remove!
	
	# console.log JSON.stringify(data-rows, null, 4)

	$table.select \tbody .select-all \tr
	.data data-rows
		..enter!
			.append \tr		
		..select-all \td
			..data id
				..enter!
					.append \td				
				..text (-> if !!it then it else "-")
		..exit!.remove!

update!

format-d1 = d3.format \.1f
format-t = (timestamp)-> moment(new Date timestamp).format "DD-MM"

fill = (func)->
	[start, end] = <[queryFrom queryTo]> |> map input-date >> (.valueAsDate.getTime!)
	[start til end by 86400000] |> map func

s-div = (a,b)-> if a == b == 0 then 0 else a / b

query = ->	

	timezone = parseInt (document.getElementById "timezone").value	
	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)
	
	data-cols := [""] ++ fill format-t
	data-rows := [		
		["Active users"] ++ fill -> "..."
		["Unique payment page views"] ++ fill -> "..."
		["<Payment page views>"] ++ fill -> "..."
		["Unique buy button taps"] ++ fill -> "..."
		["<Buy button taps>"] ++ fill -> "..."
		["Genuine subscriptions"] ++ fill -> "..."
		["Jail-Broken subscriptions"] ++ fill -> "..."
		["Known renewals"] ++ fill -> "..."
	]
	update!

	(results) <- (`promise-monad.bind`) parallel-sequence [
		((from-error-value-callback d3.json, d3) "/query/daily-active-users/240/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) ->
			data-rows[0] := ["Active users"] ++ (results |> map (.count))
			update!

		((from-error-value-callback d3.json, d3) "/query/daily-subscription-page-views/240/#{queryFrom}/#{queryTo}/true/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) -> 
			unique-subscription-page-views = results |> map (.count)
			data-rows[1] := ["Unique payment page views"] ++ unique-subscription-page-views
			update!

			((from-error-value-callback d3.json, d3) "/query/daily-subscription-page-views/240/#{queryFrom}/#{queryTo}/false/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) -> 
				data-rows[2] := ["<Payment page views>"] ++ ((zip-with s-div, (results |> map (.count)), unique-subscription-page-views) |> map format-d1)
				update!

		((from-error-value-callback d3.json, d3) "/query/daily-buy-button-taps/240/#{queryFrom}/#{queryTo}/true/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) ->			
			unique-button-taps = results |> map (.count)
			data-rows[3] := ["Unique buy button taps"] ++ unique-button-taps
			update!

			((from-error-value-callback d3.json, d3) "/query/daily-buy-button-taps/240/#{queryFrom}/#{queryTo}/false/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) ->			
				data-rows[4] := ["<Buy button taps>"] ++ ((zip-with s-div, (results |> map (.count)), unique-button-taps) |> map format-d1)
				update!

		((from-error-value-callback d3.json, d3) "/query/daily-subscriptions/240/#{queryFrom}/#{queryTo}/true/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.bind` (results) ->
			subscriptions = results |> map (.count)
			data-rows[5] := ["Genuine subscriptions"] ++ subscriptions
			update!		

			((from-error-value-callback d3.json, d3) "/query/daily-payments/240/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.ffmap` (results) ->
				data-rows[7] := ["Known renewals"] ++ (zip-with (-), (results |> map (.count)), subscriptions)
				update!

		((from-error-value-callback d3.json, d3) "/query/daily-subscriptions/240/#{queryFrom}/#{queryTo}/false/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}") `promise-monad.bind` (results) ->
			subscriptions = results |> map (.count)
			data-rows[6] := ["Jail-Broken subscriptions"] ++ subscriptions
			update!				

	]

populate-sources = ->
	(results) <- (`promise-monad.ffmap`) (from-error-value-callback d3.json, d3) "/query/media-sources"
	media-source-tree.create results

(error, results) <- to-callback <| parallel-sequence [populate-sources!, query!]
throw error if !!error
console.log "DONE!", results

