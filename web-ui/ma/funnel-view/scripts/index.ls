{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj, concat, zip-with, maximum} = require \prelude-ls

format-p0 = d3.format \%
format-d0 = d3.format ',f'

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-20"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\

input-date \queryFrom .value = "2014-07-20"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\


d3.select '[name=howManyDays]' .selectAll \option .data [0 to 30]
	..enter!
		.append \option .text id




fresh-rows = ->
	data-rows = []

data-rows = fresh-rows!

document.getElementById \main-controls .add-event-listener do 
	\submit
	-> 
		data-rows := fresh-rows!
		query!
		it.preventDefault!
		return false
	true




margin = {top: 30, right: 5, bottom: 30, left: 10}
height = (Math.min screen.availHeight*0.9, 400) - margin.top - margin.bottom


svg = d3.select \#histogram
g = svg.append \g .attr \class, \view-port-g


line = d3.svg.line!.x(-> it.0).y(-> it.1).interpolate("linear");

update = ->

	width = window.innerWidth - margin.left - margin.right

	svg.attr "width", width + margin.left + margin.right
		.attr "height", height + margin.top + margin.bottom

	g.attr "transform", "translate(" + margin.left + "," + margin.top + ")"


	users-base = data-rows |> map (.users) |> maximum
	data = zip-with ((d, i) -> d <<< index: i), data-rows, [0 to data-rows.length - 1] 
		|> map (-> it <<< ratio: it.users / users-base)

	data = data |> map (d) -> d <<< relRatio: if d.index == 0 then 1 else data |> find (-> it.index == d.index - 1) |> -> d.users / it.users

	bar-width = width/data.length
	bar-height = (.ratio * height)
	bar-left = (.index * bar-width)
	bar-top = bar-height >> (height - ) >> (/ 2)


	bar = g.selectAll ".bar" .data data
		..enter!
			.append \g
				..append \rect				
				..append \path
					..attr \fill, \#265277 # .attr \stroke, \#265277 .attr \stroke-width, 2
				..append \text .attr \class, \name
				..append \text .attr \class, \ratio
		..attr "class", "bar"
		..attr "transform", -> "translate(" + (bar-left it) + "," + (bar-top it) + ")" # y(it.y)
		..exit!
			.remove!


	bar.select "rect"
		.attr "x", 1
		.attr "width", bar-width - 10
		.attr "height", -> (bar-height it) # height - y(it.y)

	bar.select \path
		.attr \d, -> 
			w = if it.index == data.length - 1 then 3 else 20
			h = if it.index == data.length - 1 then 5 else 20
			line([
				[bar-width - 10, 0]
				[bar-width+w, h]
				[bar-width+w, (bar-height it)-h]
				[bar-width - 10, (bar-height it)]
			])

	bar.selectAll \text 
		..attr \x, (bar-width / 2) 
		..attr \text-anchor, \middle
	
	bar.select '.name'
		..attr \y, -> - 5
		..text (.view)

	bar.select '.ratio'
		..attr \y, -> (bar-height it) / 2
		..text -> (format-p0 it.relRatio) + " (#{it.users})"
		..attr("dy", ".4em")

	# bar.select \text
	# 	.attr("dy", ".75em")
	# 	.attr("y", 6)
	# 	.attr("x", x(data[0].dx) / 2)
	# 	.attr("text-anchor", "middle")
	# 	.text (-> if it.y > 0 then it.y else "")

	
	




query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

	how-many-days = parseInt (input-date \howManyDays .value)

	type = input-date \histogramType .value

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/funnel-depth-#type/#{queryFrom}/#{queryTo}/CA,IE,US/#{sampleFrom}/#{sampleTo}/#{how-many-days}"

	data-rows := results

	update!

	console.log error if !!error



query!