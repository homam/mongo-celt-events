{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-27"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

input-date \queryFrom .value = "2014-07-27"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\


how-many-days = 30

data-cols = []
data-rows = []

document.getElementById \main-controls .add-event-listener do 
	\submit
	-> 
		data-cols := []
		data-rows := []
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
	
	console.log JSON.stringify(data-rows, null, 4)

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

format-p1 = d3.format \.1%
format-t = (timestamp)-> moment(new Date(timestamp)).format("DD-MM")

query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

	(error, daily-users) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-active-users/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}"
	(error, daily-subscriptions) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-subscriptions/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}"

	pretty = (m)-> JSON.stringify(m, null, 4)

	data-rows := [
		["Active users"] ++ (daily-users |> map (.count))
		["Viewed Payment page"] ++ (daily-subscriptions |> map (.subscriptionPageViews))
		["Tapped Buy Button"] ++ (daily-subscriptions |> map (.buyTries))
		["Purchased"] ++ (daily-subscriptions |> map (.purchases))		
	]

	[queryFrom, queryTo] = <[queryFrom queryTo]> |> map input-date >> (.valueAsDate.getTime!)
	
	data-cols := [""] ++ ([queryFrom to queryTo by 86400000] |> map format-t)	

	update!

query!