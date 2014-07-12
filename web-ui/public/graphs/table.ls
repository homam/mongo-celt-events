{each, map, last} = require \prelude-ls
clone = JSON.parse . JSON.stringify

# > D3Selector -> [[Name, StringSelector, Creator, Updater]] -> [x] -> void
graph-table = (table, fields, data) -->
	append-data-fields = ->
		tr = this.append \tr 
		fields |> each ([_, selector, creator, _]) ->
			creator <| tr.append \td .attr \data-field, selector

	append-data-values = ->
		tr = this
		tr.data fields
			..enter!
				.append \td
				.attr \data-field, (.1)
				#.call(-> console.log it; debugger)
		# fields |> each ([_, selector, _, updater]) !->
		# 	tr.select "[data-field=#selector]" .call updater

	table.select 'thead' .select \tr .select-all \td 
	.data fields
		..enter!
			.append \td 
		..exit!.remove!
		..text (.0)

	table.select 'tbody' .select-all \tr
	.data data 
		..enter!.append \tr
		..select-all \td
			..data ((d) -> fields |> map (-> it ++ [d] ))
				..enter!
					.append \td
					.each (d) -> d.2.apply (d3.select this), [(last d)]
				..attr \data-field, (.1)
				..each (d) ->  d.3.apply (d3.select this), [(last d)]
				..exit!.remove!
		..exit!.remove!


exports = exports or this
exports.graph-table = graph-table