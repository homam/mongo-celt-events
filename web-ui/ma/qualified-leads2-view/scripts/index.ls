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

pluralize = (word, count)->
	if count > 1 then "#{word}s" else word

query = ->	

	[sampleFrom, sampleTo] = <[sampleFrom sampleTo]> |> map input-date >> (.value)
		
	number-of-flips = 10
	hours = 24
	
	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/qualified-leads/CA,IE,US/#{number-of-flips}/#{hours}/#{sampleFrom}/#{sampleTo}/#{sources}"

	flip-text = pluralize "flip", number-of-flips
	hour-text = pluralize "hour", hours

	data-cols := ["Filtered", "Day 1", "Subscribed", "Day 2"]

	data-rows := [
		["Less than 10 flips", results.day1.lt, results.day1.subscribtions.lt, results.day2.lt]
		["More than 10 flips", results.day1.gt, results.day1.subscribtions.gt, results.day2.gt]
	]

	update!

query!

[sampleFrom, sampleTo] = <[sampleFrom sampleTo]> |> map input-date >> (.value)

(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/media-sources/-/-/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

media-source-tree.create(results)!

d3.select '#main-controls-sources div' .select-all 'label' 
	.data results
		..enter!
			.append "label"
			.html -> '<input type="checkbox" value="'+it+'" checked="checked"/>' + it.replace("|", " ").trim()
		..exit!.remove!