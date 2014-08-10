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

fill-in-the-gaps = (query-from, query-to, days) -->

    empty-list = [query-from to query-to by 86400000]  |> map -> {day: (it - it % 86400000) / 86400000 subscriptionPageViews: 0, purchases: 0}

    days |> fold ((memo, value)->         
        index = empty-list |> find-index -> it.day == value._id
        memo[index] = value if !!index
        memo
    ),  empty-list
    

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null, sources = null) ->
    
    (success, reject) <- new-promise

    (err, devices) <- utils.get-devices-from-media-sources db, sources
    
    query-from -= (new Date()).getTimezoneOffset() * 60000
    query-to -= (new Date()).getTimezoneOffset() * 60000

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
                    day: $divide: [$subtract: ["$serverTime", $mod: ["$serverTime", 86400000]], 86400000]
                    adId: "$device.adId"
                    event: "$event"                    
                    installationTime: $subtract: ["$serverTime", "$timeDelta"]
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
                    subscriptionPageViews: $sum: {$cond: [$eq: ["$event.toView.name", "Subscription"], 1, 0]}
                    purchases: $sum: {$cond: [$eq: ["$event.name", "IAP-Purchased"], 1, 0]} 
                    buyTries: $sum: {$cond: [$eq: ["$event.name", "IAP-BuyTry"], 1, 0]} 
            }
            {
                $group:
                    _id: "$_id.day",
                    subscriptionPageViews: $sum: {$cond: [$gt:["$subscriptionPageViews", 0], 1, 0]}
                    purchases: $sum: {$cond: [$gt:["$purchases", 0], 1, 0]}
                    buyTries: $sum: {$cond: [$gt:["$buyTries", 0], 1, 0]}
            }
        ]
        (err, res) ->
            return reject err if !!err            
            success <| res |> (fill-in-the-gaps query-from, query-to)

module.exports = query