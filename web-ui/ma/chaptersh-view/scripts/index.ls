{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj, concat} = require \prelude-ls

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




margin = {top: 10, right: 5, bottom: 30, left: 10}
height = (Math.min screen.availHeight*0.9, 400) - margin.top - margin.bottom


svg = d3.select \#histogram
g = svg.append \g .attr \class, \view-port-g

g.append("g")
	.attr("class", "x axis")
	.attr("transform", "translate(0," + height + ")")


update = ->

	width = window.innerWidth - margin.left - margin.right

	svg.attr "width", width + margin.left + margin.right
		.attr "height", height + margin.top + margin.bottom

	g.attr "transform", "translate(" + margin.left + "," + margin.top + ")"

	x = d3.scale.linear!
		.range [0, width]
		.domain [0, (d3.max data-rows)]

	bins = x.ticks (Math.min width/35, (d3.max data-rows))
	data = d3.layout.histogram!.bins(bins)(data-rows)

	y = d3.scale.linear!
		.domain [0, d3.max(data, (.y))]
		.range [height, 0]

	xAxis = d3.svg.axis!
		.scale x
		.ticks bins.length
		.orient \bottom



	bar = g.selectAll ".bar" .data data
		..enter!
			.append \g
				..append \rect
				..append \text
		..attr "class", "bar"
		..attr "transform", -> "translate(" + x(it.x) + "," + y(it.y) + ")"
		..exit!
			.remove!


	bar.select "rect"
		.attr "x", 1
		.attr "width", x(data[0].dx) - 1
		.attr "height", -> height - y(it.y)

	bar.select \text
		.attr("dy", ".75em")
		.attr("y", 6)
		.attr("x", x(data[0].dx) / 2)
		.attr("text-anchor", "middle")
		.text (-> if it.y > 0 then it.y else "")

	
	svg.select 'g.x.axis' .call(xAxis);
	svg.select 'g.x.axis' .selectAll \text 
		.attr \text-anchor, \middle
	




query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)

	how-many-days = parseInt (input-date \howManyDays .value)

	type = input-date \histogramType .value

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/histogram-eocs-#type/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{how-many-days}"

	data-rows := results |> (map ({_id, users}) -> [_id for i in [1 to users]]) |> concat


	update!

	console.log error if !!error



query!