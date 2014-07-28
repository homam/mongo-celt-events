{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, filter, id, find, lists-to-obj, concat, drop, sum} = require \prelude-ls

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

	x2 = d3.scale.linear!
		.range [0, width]
		.domain [1, (d3.max data-rows)]

	bins = x2.ticks (Math.min width/35, (d3.max data-rows))
	data = d3.layout.histogram!.bins(bins)(data-rows)

	y = d3.scale.linear!
		.domain [0, d3.max(data, (.y))]
		.range [height, 0]

	xAxis = d3.svg.axis!
		.scale x2
		.ticks bins.length
		.orient \bottom



	bar = g.selectAll ".bar" .data data
		..enter!
			.append \g
				..append \rect
				..append \text
		..attr "class", "bar"
		..attr "transform", -> "translate(" + (x2(it.x) - 1) + "," + y(it.y) + ")"
		..exit!
			.remove!


	bar.select "rect"
		.attr "x", 1
		.attr "width", x(data[0].dx)
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
	



format-p0 = d3.format \%
format-d0 = d3.format ',f'


query = ->

	[sampleFrom, sampleTo, queryFrom, queryTo, uniqueCount] = <[sampleFrom sampleTo queryFrom queryTo uniqueCount]> |> map input-date >> (.value)

	how-many-days = parseInt (input-date \howManyDays .value)

	type = input-date \histogramType .value

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/histogram-eocs-#type/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{how-many-days}/#{uniqueCount}"

	zero-users = results.0.users
	one-or-more-users = results |> filter (._id >= 1) |> map (.users) |> sum
	two-or-more-users = results |> filter (._id >= 2) |> map (.users) |> sum
	total-users = results |> map (.users) |> sum

	data-rows := results |> (drop 1) |> (map ({_id, users}) -> [_id for i in [1 to users]]) |> concat

	d3.select \#zero-chapter-count .text "#{format-d0 zero-users} = #{format-p0 (zero-users/total-users)}"
	d3.select \#one-or-more-chapter-count .text "#{format-d0 one-or-more-users} = #{format-p0 (one-or-more-users/total-users)}"
	d3.select \#two-or-more-chapter-count .text "#{format-d0 two-or-more-users} = #{format-p0 (two-or-more-users/total-users)}"

	update!

	console.log error if !!error



query!