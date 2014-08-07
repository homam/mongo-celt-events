{
	promises: {
		promise-monad
		new-promise
	}
} = require \async-ls
{map, sort, sort-by, mean, filter, first, group-by, concat-map, foldl, Obj, maximum} = require \prelude-ls

query = (db, query-from, query-to, countries, sample-from, sample-to)-> 

	(success, reject) <- new-promise
	(err, results) <- db.IOSEvents.aggregate do 
		[
			{
				$match: 
					country: $in: countries					
					"event.fromView.name": "Home"
					"event.toView.name": "Chapter"
			}
			{
				$group:
					_id: "$event.toView.courseKey"
					trigger: $addToSet: "$event.trigger"
			}
		]
	return reject err if !!err
	success <| results |> map ({_id, trigger})-> courseKey: _id, trigger: trigger


module.exports = query