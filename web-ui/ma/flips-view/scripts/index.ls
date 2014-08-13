{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-23"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

input-date \queryFrom .value = "2014-07-23"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

how-many-days = 30

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
				..text id
		..exit!.remove!

update!

format-p1 = d3.format \.1%
format-t = (timestamp)-> moment(new Date(timestamp)).format("DD-MM")

fill = (func)->
	[start, end] = <[queryFrom queryTo]> |> map input-date >> (.valueAsDate.getTime!)
	[start to end by 86400000] |> map func

query = ->	

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)
		
	number-of-flips = (parseInt (document.getElementById "flips").value)	

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/n-flips/#{queryFrom}/#{queryTo}/CA,IE,US/#{number-of-flips}/#{sampleFrom}/#{sampleTo}/#{sources}"	

	data-cols := [""] ++ results |> map (._id)

	data-rows := [
		["#{number-of-flips} or more flips"] ++ (results |> map (.gt))
		["less than #{number-of-flips} flips"] ++ (results |> map (.lt))
		["%"] ++ (results |> map -> Math.floor(10000 * it.gt / (it.gt + it.lt)) / 100)
	]	

	update!

query!

[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/media-sources/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{sources}"

media-source-tree.create(results)!