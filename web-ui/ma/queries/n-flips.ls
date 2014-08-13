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
    

query = (db, query-from, query-to, countries = null, flips = 10, sample-from = null, sample-to = null, sources = null) ->

    flips = parseInt flips
    
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
                    adId: "$device.adId"
                    day: $divide: [$subtract: ["$timeDelta", $mod: ["$timeDelta", 86400000]], 86400000]
                    event: 1
                    sameCard: $eq: ["$event.fromView.cardIndex", "$event.toView.cardIndex"]
                    timeDelta: 1
                    installationTime: $subtract: ["$creationTimestamp", "$timeDelta"]
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
                    _id: "adId": "$adId", "day": "$day"
                    count: $sum: $cond: [$and: [
                        {$eq: ["$event.name", "transition"]},
                        {$eq: ["$event.fromView.name", "Flashcard"]},
                        {$eq: ["$event.toView.name", "Flashcard"]},
                        {$eq: ["$event.fromView.side", "question"]},
                        {$eq: ["$event.toView.side", "answer"]},
                        {$eq: ["$sameCard", true]}
                    ],1,0]
            }
            {
                $group: 
                    _id: "$_id.day"
                    lt: $sum: $cond: [$lt: ["$count", flips], 1, 0]
                    gt: $sum: $cond: [$gt: ["$count", flips], 1, 0]
            }
            {
                $sort:
                    _id: 1
            }
        ]
        (err, res) ->
            return reject err if !!err            
            success <| res

module.exports = query