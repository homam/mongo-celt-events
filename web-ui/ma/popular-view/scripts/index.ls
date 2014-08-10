{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj, values, maximum} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-20"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

input-date \queryFrom .value = "2014-07-20"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\


how-many-days = 30
maximum-purchase-count = 0

sources = "-"

fresh-rows = ->
	data-rows = []

data-rows = fresh-rows!

document.getElementById \main-controls .add-event-listener do 
	\submit
	-> 
		data-rows := fresh-rows!
		sources := media-source-tree.getSelectedSources!.join!
		update!
		query!
		it.preventDefault!
		return false
	true

$table = d3.select \table#main

$table.select \thead .select \tr .select-all \td
.data ['Course', 'Users', 'Cards', 'Flips', 'Chapters', 'Purchased']
	..enter!
		.append \th
		.text id
	..exit!.remove!

update = ->
	$table.select \tbody .select-all \tr
	.data data-rows 
	.style "background-color", (-> 
		
		purchase-count = parseFloat it[5]

		p = purchase-count / maximum-purchase-count
		alpha = 0.2 + p * 0.8
		red-channel = Math.floor 255 * (1 - p)

		if purchase-count > 0 
			return "rgba(#{red-channel}, 255, 0, #{alpha})" 

		else 
			return ""

	)
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
format-d0 = d3.format ',f'
format-d1 = d3.format ',.1f'

query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/popular-courses/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{sources}"

	data-rows := results |> map (->  
		[
			* it.name
			* format-d0 it.users
			* format-d1 it.cards/it.users
			* format-d1 it.flips/it.users
			* format-d1 it.chapters/it.users
			* "..."
		])

	update!

	(err, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/purchased-for/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{sources}"		

	maximum-purchase-count := results
		|> values
		|> maximum
		
	data-rows := data-rows |> map ->
		it[5] = 0
		it[5] = results[it[0]] if !!results[it[0]]
		it

	update!



query!

[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/media-sources/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{sources}"

media-source-tree.create(results)!