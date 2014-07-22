{drop} = require \prelude-ls
window.noop = ->
window.format-nan = (formatter, value) -->
	if isNaN value then '-' else formatter value

handlers = {}
window.register-route-handler = (controller, renderer) ->
	handlers[controller] = {
		renderer: renderer
	}


window.change-route = (route, skip-history = false) ->
	[controller, ...params] = drop 1, route.split '/'
	controller = 'main' if '' == controller
	handlers[controller].renderer.apply null, params

	d3.select-all '.visible[data-main-view]' .classed \visible, false
	d3.select "[data-main-view=#controller]" .classed \visible, true

	e = new CustomEvent \routechanged, detail: route: route, name: name, previous: location.pathname
	if not skip-history
		history.pushState {}, name, route
	window.dispatch-event e



window.add-event-listener \routechanged, ({detail:{route, name, previous}}) ->
	
	console.log route,name,previous

window.onpopstate = (state) ->
	console.log state
	window.change-route document.location.pathname, true


window.onload = ->
	window.change-route document.location.pathname, true
# var stateObj = { foo: "bar" };
# history.pushState(stateObj, "page 2", "bar.html");