{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id} = require \prelude-ls

render = (creative-id, res) ->
	fields = 
		* 
			* "Placement Id"
			* "_id"
			* (d)-> @append 'a'
						..on \click, -> 
							d3.event.preventDefault!
							window.change-route <| d3.select this .attr \href
			* (d) -> @select \a
						..text (d._id) .attr \href, -> "/placement/#{d._id}/creative/#{creative-id}"
		* "Visits", "visits", noop, (d) -> @text (d3.format \,) d.visits
		* "Unique Visits", "uvisitsR", noop, (d) -> @text (d3.format \%) d.uvisitsR
		* "Subscribers", "subscribers", noop, (d) -> @text (d3.format \,) d.subscribers
		* "Conversion", "conversionR", noop, (d) -> @text (d3.format \.2%) d.conversionR
		* "Active 12", "active12R", noop, (d) -> @text (d3.format \%) `format-nan` d.active12R


	table = d3.select '[data-main-view=creative] table.placements'
	
	graph-table table, fields, res


(creative-id) <- window.register-route-handler 'creative', _
(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) "/query/banners/#{creative-id}/placementId"
	|> promise-monad.fmap (res) ->
		res |> map -> 
			{
				uvisitsR: it.uvisits/it.visits
				conversionR: it.subscribers/it.uvisits
				active12R: it.active12/it.subscribers
			} <<< it
	|> promise-monad.fbind (res) ->
		render creative-id, res
		res
	
console.log error if !!error