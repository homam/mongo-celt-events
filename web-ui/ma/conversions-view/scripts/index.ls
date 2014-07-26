{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \queryFrom .value = "2014-07-20"
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

print-conversion-data = (data)->
	if data.visits == 0 then "-" else "#{data.installs} / #{data.visits} = #{format-p1(data.conversion)}"

update = ->
	
	$table.select \thead .select \tr .select-all \th
	.data data-cols
		..enter!
			.append \th
			.text id
		..exit!.remove!
	
	$table.select \tbody .select-all \tr
	.data data-rows
		..enter!
			.append \tr		
		..select-all \td
			..data (-> [it.source])
				..enter!
					.append \td
				..text id
			..data (-> it.days)
				..enter!
					.append \td
				..style "text-align", (-> if it.visits == 0 then "center" else "right")				
				..text print-conversion-data
				..attr "title", (.source)
		..exit!.remove!

update!

format-p1 = d3.format \.1%
format-t = (timestamp)-> moment(new Date(timestamp)).format("DD-MM")

query = ->

	[queryFrom, queryTo] = <[queryFrom queryTo]> |> map input-date >> (.value)

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-conversions/#{queryFrom}/#{queryTo}/CA,IE"

	[queryFrom, queryTo] = <[queryFrom queryTo]> |> map input-date >> (.valueAsDate.getTime!)
	
	data-cols := ["Sources"] ++ ([queryFrom to queryTo by 86400000] |> map format-t)
	data-rows := results |> map (e)-> e <<< days: (e.days |> map -> it <<< source: e.source)

	update!

query!