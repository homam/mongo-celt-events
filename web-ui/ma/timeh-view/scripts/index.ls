{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, filter, lists-to-obj, concat, mean, sum, div, foldl} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \sampleFrom .value = "2014-07-20"
input-date \sampleTo .value = moment!.add \days, 1 .format \YYYY-MM-DD

input-date \queryFrom .value = "2014-07-20"
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD

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

	x = d3.scale.ordinal!
		.rangeBands [0, width], 0.1
		.domain (data-rows |> map (.time))


	data = data-rows

	y = d3.scale.linear!
		.domain [0, d3.max(data, (.users))]
		.range [height, 0]

	xAxis = d3.svg.axis!
		.scale x
		.orient \bottom


	bar = g.selectAll ".bar" .data data
		..enter!
			.append \g
				..append \rect
				..append \text
		..attr "class", "bar"
		..attr "transform", -> "translate(" + x(it.time) + "," + y(it.users) + ")"
		..exit!
			.remove!


	bar.select "rect"
		.attr "x", 1
		.attr "width", x.rangeBand!
		.attr "height", -> height - y(it.users)

	bar.select \text
		.attr("dy", ".75em")
		.attr("y", 6)
		.attr("x", x.rangeBand! / 2)
		.attr("text-anchor", "middle")
		.text (-> if it.users > 0 then it.users else "")

	
	svg.select 'g.x.axis' .call(xAxis);

	




query = ->
	
	[sampleFrom, sampleTo, queryFrom, queryTo] = <[sampleFrom sampleTo queryFrom queryTo]> |> map input-date >> (.value)
	
	isFreeChecked = document.getElementsByName("free")[0].checked
	isPurchasedChecked = document.getElementsByName("purchased")[0].checked
	user-payment-status = 'all'

	if isFreeChecked
		user-payment-status = 'free'

	if isPurchasedChecked
		user-payment-status = 'purchased'

	if isPurchasedChecked && isFreeChecked
		user-payment-status = 'all'

	how-many-days = parseInt (input-date \howManyDays .value)

	type = input-date \histogramType .value

	(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/histogram-timespent-#type/#{queryFrom}/#{queryTo}/CA,IE/#{sampleFrom}/#{sampleTo}/#{how-many-days}/#{user-payment-status}"

	total-users = results |> (map (.users)) >> sum

	console.log \mean, (results |> (map ({_id, users}) -> _id * users / total-users) |> sum)

	# data-rows := results |> (map ({_id, users}) -> [_id for i in [1 to users]]) |> concat

	data-rows := [0 to (d3.max results, (._id))] |> map (m) -> time: m, users: (results |> find ({_id}) -> _id == m)?.users or 0

	data-rows := (data-rows |> filter (.time <= 20)) ++ [{time: "20+", users: (data-rows |> filter (.time > 20) |> map (.users) |> sum)}]

	# data-rows := data-rows |> foldl do 
	# 	(res, {time, users}) ->
	# 		i = time `div` 5
	# 		res[i] = 0 if not res[i]?
	# 		res[i] += users
	# 		res
	# 	[]

	update!

	console.log error if !!error



query!