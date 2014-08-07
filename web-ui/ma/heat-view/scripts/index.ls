{
	from-error-value-callback
	promise-monad
	to-callback
} = require \promises-ls
{each, map, id, find, lists-to-obj} = require \prelude-ls

input-date = (name) ->
	d3.select '#main-controls [name=' + name + ']' .node!

input-date \queryFrom .value = "2014-07-27"   
input-date \queryTo .value = moment!.add \days, 1 .format \YYYY-MM-DD\


