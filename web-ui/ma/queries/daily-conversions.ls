{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
{map, sort, sort-by, mean, fold, find-index, reverse} = require \prelude-ls


one-minute = 60 * 1000
one-day = 86400000

fill-in-the-gaps = (timezone, query-from, query-to, days) -->

    query-from += timezone * one-minute
    query-to += timezone * one-minute

    empty-list = [query-from til query-to by one-day] |> map -> {day: (it - it % one-day) / one-day, visits: 0, installs: 0, conversion: 0} 

    days |> fold ((memo, value)-> 
        index = empty-list |> find-index -> it.day == value.day
        memo[index] = value if index != -1
        memo
    ),  empty-list
    

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->     

    (success, reject) <- new-promise
    
    db.IOSAdVisits.aggregate do
        [
            {
                $match: 
                    country: $in: countries
                    creationTimestamp: $gte: query-from, $lte: query-to
            }               
            {
                $project:
                    dubaiCreationTimestamp: $add: ["$creationTimestamp", timezone * one-minute]
                    source: 1
                    userId: $ifNull: ["$userId", "-"]
            }       
            {
                $project:
                    day: $divide: [$subtract: ["$dubaiCreationTimestamp", $mod: ["$dubaiCreationTimestamp", one-day]], one-day]
                    source: 1
                    userId: 1
            }
            {
                $group:
                    _id: 
                        day: "$day"
                        source: "$source"
                    visits: $sum: 1
                    installs: $sum: {$cond: [$eq: ["$userId", "-"], 0, 1]}
            }
            {
                $group:
                    _id: source: "$_id.source"
                    days: $push: 
                        day: "$_id.day", 
                        visits: "$visits", 
                        installs: "$installs", 
                        conversion: $divide: ["$installs", "$visits"]
            }           
        ]
        (err, res) ->
            return reject err if !!err
            success <| res |> map ({_id, days}) ->
                source: _id.source
                days: days |> (fill-in-the-gaps timezone, query-from, query-to)
                conversion: days |> map (.conversion) |> mean
            |> sort-by (.conversion) |> reverse 

module.exports = query