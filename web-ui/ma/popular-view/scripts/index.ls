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

fresh-rows = ->
	data-rows = []

data-rows = fresh-rows!

document.getElementById \main-controls .add-event-listener do 
	\submit
	-> 
		data-rows := fresh-rows!
		update!
		query!
		it.preventDefault!
		return false
	true




$table = d3.select \table#main

$table.select \thead .select \tr .select-all \td
.data ['Course', 'Users', 'Cards', 'Flips', 'Chapters']
	..enter!
		.append \th
		.text id
	..exit!.remove!

update = ->
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
format-d0 = d3.format ',f'
format-d1 = d3.format ',.1f'

query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/popular-courses/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}"

	data-rows := results |> map (->  
		[
			* it.name
			* format-d0 it.users
			* format-d1 it.cards/it.users
			* format-d1 it.flips/it.users
			* format-d1 it.chapters/it.users
		])

	update!

	console.log error



query!