{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj, fold, values, filter} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-20"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD

input-date \queryFrom .value = "2014-07-20"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD


how-many-days = 30

sources = "-"

fresh-rows = ->
	data-rows = [
		[\base, 'Base']
		[\used, 'Used the App']
		[\interacted, 'Visited any Course']
		[\sessions, 'Sessions']
		[\time, 'Time Spent']
		[\flips, 'Flips']
		[\backFlips, 'Back Flips']
		# [\cards, 'Cards']
		[\chapters, 'Chapters']
		[\eoc, 'Chapter Completion']
		[\courses, 'Courses']
		[\usersStartedQuiz, 'Started any Quiz']
		[\completedQuizzes, 'Quiz Completion']
		[\rated, 'Rated']
		[\remind, 'Remind me later']
		[\never, 'Never ask again']
		[\userSubscription, 'Subscribed']
	]
	data-rows = data-rows |> map (-> it ++ [["..." for _ in [0 to how-many-days]]])

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
.data [-1 to how-many-days]
	..enter!
		.append \td
		.text -> if it >= 0 then it else "Day"
	..exit!.remove!

update = ->
	$table.select \tbody .select-all \tr
	.data data-rows
		..enter!
			.append \tr
			.attr \class, (.0)
				..append \th
					.text (.1)
		..select-all \td
			..data (.2)
				..enter!
					.append \td
				..text id
		..exit!.remove!

update!

format-p0 = d3.format \%
format-p1 = d3.format \.1%
format-d1 = d3.format ',.1f'
format-d0 = d3.format ',f'

query = ->

	update-data-rows = (data-rows, name, results, day-selector, formatter) ->
		row = data-rows |> find (.0 == name) 
		row.2 = [0 to how-many-days] |> map (d) -> results |> find (-> (day-selector it) == d) |> formatter
		data-rows

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)	

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-opens/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

	base = [0 to how-many-days] |> map (d) -> 
		results |> find (.day == d) |> (-> it?.base or 0) 
	base := [0 to how-many-days] `lists-to-obj` base


	users = [0 to how-many-days] |> map (d) -> 
		results |> find (.day == d) |> (-> it?.users or 0) 
	users := [0 to how-many-days] `lists-to-obj` users



	data-rows := update-data-rows data-rows, \base, results, (.day), -> if !!it then it.base else 0
	data-rows := update-data-rows data-rows, \used, results, (.day), -> if !!it and it.base > 0 then format-p1 it.users/it.base else "-"

	update!


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-time-spent/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

	data-rows := update-data-rows data-rows, \sessions, results, (.day), -> if !!it then format-d1 it.sessions/it.users else "-"
	data-rows := update-data-rows data-rows, \time, results, (.day), -> if !!it then format-d1 (it.avgDailyDuration/60) else "-"

	update!


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-cards/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

	data-rows := update-data-rows data-rows, \interacted, results, (._id), -> if !!it then format-p0 it.users/users[it._id] else "-"

	<[flips backFlips chapters courses]> |> each (field) ->
		data-rows := update-data-rows data-rows, field, results, (._id), -> if !!it then format-d1 it[field]/it.users else "-"


	[
		* \eoc, -> if !!it then format-p0 it.eocs/it.chapters else "-"
		* \usersStartedQuiz, -> if !!it then format-p0 it.usersStartedQuiz/users[it._id] else "-"
		* \completedQuizzes, -> if !!it and !!it.quizzes then format-p0 it.eoqs/it.quizzes else "-"
	] |> each ([field, formatter]) -> 
		data-rows := update-data-rows data-rows, field, results, (._id), formatter

	update!


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/daily-ratings/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

	<[rated never remind]> |> each (field) ->
		data-rows := update-data-rows data-rows, field, results, (._id), -> if !!it then format-d0 it[field] else "-"

	update!


	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/purchased-day/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

	<[userSubscription]> |> each (field) ->
		data-rows := update-data-rows data-rows, field, results, (._id), -> if !!it then format-d0 it[field] else 0
		
	update!

query!


[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/media-sources/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{sources}"

media-source-tree.create(results)!

d3.select '#main-controls-sources div' .select-all 'label' 
	.data results
		..enter!
			.append "label"
			.html -> '<input type="checkbox" value="'+it+'" checked="checked"/>' + it.replace("|", " ").trim()
		..exit!.remove!
	


