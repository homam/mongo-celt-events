db.IOSEvents.aggregate([
    {"$match": {
        "country": {"$in": ["CA", "IE", "US"]},
        "event.fromView.name": "Home",
        "event.toView.name": "Chapter",
        "event.toView.courseKey": "WhyWeGetFatBookSummary"
    }},
    {"$group": {
        "_id": {"adId": "$device.adId", "trigger": "$event.trigger"}
    }},
    {"$group": {
        "_id": "$_id.trigger",
        "count": {"$sum": 1}
    }}
])

{
    promises: {
        promise-monad
        new-promise
    }
} = require \async-ls
{map, sort, sort-by, mean, fold, find-index, reverse} = require \prelude-ls


one-hour = 1000*60*60
one-day =  one-hour*24

query = (db, query-from, query-to, countries = null, sample-from = null, sample-to = null) ->   
    (success, reject) <- new-promise
    
    query-from -= (new Date()).getTimezoneOffset() * 60000
    query-to -= (new Date()).getTimezoneOffset() * 60000

    db.IOSEvents.aggregate do
        [
            {
                $match: 
                    country: $in: countries
                    serverTime: $gte: query-from, $lte: query-to
                    "event.fromView.name": "Home"
                    "event.toView.name": "Chapter"
                    "event.toView.courseKey": ""
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
                    _id: adId: "$device.adId", trigger: "$event.trigger"
            }
            {
                $group:
                    _id: "$_id.trigger"
                    count: $sum: 1
            }
        ]
        (err, res) ->
            return reject err if !!err            
            success <| res 

module.exports = query