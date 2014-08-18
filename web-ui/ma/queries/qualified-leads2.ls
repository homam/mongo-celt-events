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

get-subscribed-devices = (db, devices, sample-from, sample-to, hours, delta-offset = 0, callback)->
    (err, result) <- db.IOSEvents.aggregate do
        [
            $match: {
                country: {$in: ["CA", "IE", "US"]}
                "event.name": "IAP-PurchaseVerified"
                "event.valid": true
                "device.adId": $in: devices
            }
        ] ++ (
            $project: {
                adId: "$device.adId"
                installTime: $subtract: ["$serverTime", "$timeDelta"]
                timeDelta: 1
            }
        ) ++ ( 
                if !!sample-from and !!sample-to then
                    [
                        $match:
                            installTime: $gte: sample-from, $lte: sample-to
                    ]
                else []
        ) ++ (
                if !!delta-offset then 
                    [
                        $match:
                            $timeDelta: {$gt: hours * 60 * 60 * 1000}
                    ]
                else []
        ) ++ (
            [
                $group:
                    _id: "$adId"
            ]
        )

    return callback err, null if err != null
    callback null, (result |> map (.adId))

flips-per-device-in-x-hours = (db, devices, countries = null, flips = 10, hours = 1, sample-from = null, sample-to = null, delta-offset = 0, callback) ->       
    # (success, reject) <- new-promise
    query =
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
                        {$lt: ["$timeDelta", delta-offset + hours * 60 * 60 * 1000]},
                        {$eq: ["$event.name", "transition"]},
                        {$eq: ["$event.fromView.name", "Flashcard"]},
                        {$eq: ["$event.toView.name", "Flashcard"]},
                        {$eq: ["$event.fromView.side", "question"]},
                        {$eq: ["$event.toView.side", "answer"]},
                        {$eq: ["$event.fromView.cardIndex", "$event.toView.cardIndex"]}
                    ]  <<< if !!delta-offset then [$gt: ["$timeDelta", hours * 60 * 60 * 1000]] else [], 1, 0]
            }
        ]

    (err, results) <- db.IOSEvents.aggregate query
        
    return callback err, null if err != null
    # result = (if results.length > 0 then results[0] else {lt: 0, gt: 0}) <<< _id: devices 
    callback null, results

query = (db, countries, flips, hours, sample-from, sample-to, sources) ->
    
    (success, reject) <- new-promise

    stats =
        day1: {}
        day2: {}

    (err, devices) <- utils.get-devices-from-media-sources db, sources

    (err, flips-per-device) <- flips-per-device-in-x-hours db, devices, countries, flips, hours, sample-from, sample-to, 0

    less-than-flip-devices = []
    more-than-flip-devices = []
    stats.day1.subscribtions = {}

    each (item)->
        if item.count <= 10
            less-than-flip-devices.push(item["_id"])
        else
            more-than-flip-devices.push(item["_id"])
    ,flips-per-device
    
    stats.day1.lt = less-than-flip-devices.length
    stats.day1.gt = more-than-flip-devices.length

    (err, subscribed-devices) <- get-subscribed-devices(db, less-than-flip-devices, sample-from, sample-to, hours, 0)
    stats.day1.subscribtions.lt = subscribed-devices.length

    (err, subscribed-devices) <- get-subscribed-devices(db, more-than-flip-devices, sample-from, sample-to, hours, 0)
    stats.day1.subscribtions.gt = subscribed-devices.length

    (err, flips-per-device) <- flips-per-device-in-x-hours db, more-than-flip-devices, countries, flips, hours, sample-from, sample-to, 24

    less-than-flip-devices = []
    more-than-flip-devices = []

    each (item)->
        if item.count <= 10
            less-than-flip-devices.push(item["_id"])
        else
            more-than-flip-devices.push(item["_id"])
    ,flips-per-device

    stats.day2.lt = less-than-flip-devices.length
    stats.day2.gt = more-than-flip-devices.length

    success stats

module.exports = query