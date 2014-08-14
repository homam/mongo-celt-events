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
		
	number-of-flips = parseInt (document.getElementById "flips").value
	hours = parseInt (document.getElementById "hours").value

	
	sources = ["apploop_int","appnexus_int","Facebook Ads","googleadwords_int","iAd,tapjoy_int"]

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/n-flips/CA,IE,US/#{number-of-flips}/#{hours}/#{sampleFrom}/#{sampleTo}/#{sources}"	

	flip-text = pluralize "flip", number-of-flips
	hour-text = pluralize "hour", hours

	data-cols := ["Sources", "Installs", "Less than #{number-of-flips} #{flip-text} in #{hours} #{hour-text}", "#{number-of-flips} or more #{flip-text} in #{hours} #{hour-text}", "%"]

	data-rows := results 
		|> map ({_id, lt, gt})->
			d = lt + gt
			[_id, lt + gt, lt, gt, if d == 0 then "-" else format-p1 gt / d]

	update!

query!
