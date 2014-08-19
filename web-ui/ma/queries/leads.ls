{
    promises: {
        fmapP
        new-promise
        parallel-map
        promise-monad
    }
} = require \async-ls

{each, filter, foldl, map} = require \prelude-ls

utils = require "./utils"

get-devices-from-media-source = (db, source, callback)->

    return callback null, null if !source

    (err, result) <- db.IOSUsers.aggregate do
        [
            {
                $project:
                    adId: "$device.adId"
                    source: "$appsFlyer.media_source"
            }
            {
                $match:
                    source: source
            }           
        ]
    return callback err, null if err != null
    callback null, (result |> map (.adId))

did-n-flips-in-x-hours = (db, source, countries = null, flips = 10, hours = 1, sample-from = null, sample-to = null) ->       
    (success, reject) <- new-promise
    (err, devices) <- get-devices-from-media-source db, source    
    (err, results) <- db.IOSEvents.aggregate do
        [
            {
                $match:                    
                    country: {$exists: 1} <<< if !!countries then $in: countries else {}
                    "device.adId": {$exists: 1} <<< if !!devices then $in: devices else {}
            }
            {
                $project: 
                    device: 1
                    event: 1                
                    installTime: $subtract: ["$serverTime", "$timeDelta"]
                    serverTime: 1
                    timeDelta: 1
            }
        ] ++ ( 
                if !!sample-from and !!sample-to then
                    [
                        $match:
                            installTime: $gte: sample-from, $lte: sample-to
                    ] 
                else []
        ) ++ [
            {
                $group:
                    _id: "$device.adId"
                    count: $sum: $cond: [$and: [
                        {$lt: ["$timeDelta", hours * 60 * 60 * 1000]},
                        {$eq: ["$event.name", "transition"]},
                        {$eq: ["$event.fromView.name", "Flashcard"]},
                        {$eq: ["$event.toView.name", "Flashcard"]},
                        {$eq: ["$event.fromView.side", "question"]},
                        {$eq: ["$event.toView.side", "answer"]},
                        {$eq: ["$event.fromView.cardIndex", "$event.toView.cardIndex"]}
                    ], 1, 0]
            }         
            {
                $group:
                    _id: ""
                    lt: $sum: $cond: [$lt: ["$count", flips], 1, 0]
                    gt: $sum: $cond: [$lt: ["$count", flips], 0, 1]
            }
        ]
    return reject err if !!err    
    result = (if results.length > 0 then results[0] else {lt: 0, gt: 0}) <<< _id: source 
    console.log result
    success <| result

query = (db, countries, flips, hours, timezone, sample-from, sample-to, sources) ->

    (success, reject) <- new-promise
    sources 
        |> parallel-map -> did-n-flips-in-x-hours db, it, countries, flips, hours, sample-from, sample-to
        |> fmapP -> success it

module.exports = query