{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-20"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

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
				..text (-> "#{it.installs} / #{it.visits} = #{format-p1(it.conversion)}")
		..exit!.remove!

update!

format-p1 = d3.format \.1%
format-d0 = d3.format ',f'
format-d1 = d3.format ',.1f'

query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-conversions/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}"

	[queryFrom, queryTo] = <[queryFrom queryTo]> |> map input-date >> (.valueAsDate.getTime!)
	
	data-cols := ["Sources"] ++ ([queryFrom to queryTo by 86400000] |> map (-> new Date(it).toDateString!))
	data-rows := results

	update!

query!