{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
{map, sort, sort-by, mean, fold, find-index, reverse} = require \prelude-ls
utils = require "./utils"


one-hour = 1000*60*60
one-day =  one-hour*24

fill-in-the-gaps = (timezone, query-from, query-to, days) -->

    query-from += timezone * 60 * 1000
    query-to += timezone * 60 * 1000

    empty-list = [query-from til query-to by 86400000]  |> map -> {day: (it - it % 86400000) / 86400000 count: 0}

    days |> fold ((memo, value)->         
        index = empty-list |> find-index ->             
            it.day == value._id        
        memo[index] = value if index != -1
        memo
    ),  empty-list

query = (db, timezone, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->   

    (success, reject) <- new-promise
    (err, devices) <- utils.get-devices-from-media-sources db, sources
    
    db.IOSEvents.aggregate do
        [
            {
                $match: 
                    country: $in: countries
                    serverTime: $gte: query-from, $lte: query-to
                    "device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
            }
            {
                $project:
                    dubaiTime: $add: ["$serverTime", timezone * 60 * 1000]
                    adId: "$device.adId"
                    installationTime: $subtract: ["$serverTime", "$timeDelta"]
            }                        
            {
                $project:
                    day: $divide: [$subtract: ["$dubaiTime", $mod: ["$dubaiTime", 86400000]], 86400000]
                    adId: 1
                    installationTime: 1
            }
        ] ++ (
            if !!sample-to && !!sample-from        
                [
                    $match:                            
                        installationTime: $gte: sample-from, $lte: sample-to                    
                ]
            else 
                []
        ) ++ [
            {
                $group:
                    _id: 
                        day: "$day" 
                        adId: "$adId"                    
            }
            {
                $group:
                    _id: "$_id.day"
                    count: $sum: 1
            }            
        ]
        (err, res) ->
            return reject err if !!err            
            success <| res |> (fill-in-the-gaps timezone, query-from, query-to)

module.exports = query