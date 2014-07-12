{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id} = require \prelude-ls

always-fields = 
	* "Visits", "visits", noop, (d) -> @text (d3.format \,) d.visits
	* "Unique Visits", "uvisitsR", noop, (d) -> @text (d3.format \%) d.uvisitsR
	* "Subscribers", "subscribers", noop, (d) -> @text (d3.format \,) d.subscribers
	* "Conversion", "conversionR", noop, (d) -> @text (d3.format \.2%) d.conversionR
	* "Active 12", "active12R", noop, (d) -> @text (d3.format \%) `format-nan` d.active12R

render-query-banners = (banners) ->
	fields = 
		* 
			* "Creative Id"
			* "_id"
			* (d)-> @append 'a'
						..on \click, -> 
							d3.event.preventDefault!
							window.change-route <| d3.select this .attr \href
			* (d) -> @select \a
						..text (d._id) .attr \href, -> "/creative/#{d._id}"
		* "Banner Name", "banner", noop, (d) -> @text d.banner

	fields := fields ++ always-fields 
	table = d3.select '[data-main-view=main] table.banners'
	
	graph-table table, fields, banners


render-devices = (res) ->
	fields = 
		* 
			* "Device Name"
			* "_id"
			* noop
			* (d) -> @text d._id
		...

	fields := fields ++ always-fields

	table = d3.select '[data-main-view=main] table.devices'
	
	graph-table table, fields, res



map-results = map -> 
	{
		uvisitsR: it.uvisits/it.visits
		conversionR: it.subscribers/it.uvisits
		active12R: it.active12/it.subscribers
	} <<< it
<- window.register-route-handler 'main', _
(error, results) <- to-callback <| (from-error-value-callback d3.json, d3) '/query/banners'
	|> promise-monad.fmap map-results
	|> promise-monad.fbind (res) ->
		render-query-banners res
		(from-error-value-callback d3.json, d3) '/q/_/sql.device.marketing'
	|> promise-monad.fmap map-results
	|> promise-monad.fbind render-devices


console.log error if !!error
