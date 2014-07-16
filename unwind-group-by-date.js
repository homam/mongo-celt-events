db.reducedEvents.aggregate([
    {"$match": {"sql.subscriberId": { $ne: null} }},
    
    // Unwind the array
    { "$unwind": "$creationTimes" },

    // Find the minimal key per document
    { "$group": {
         "_id": "$_id",
         "creationTimes": { "$min": "$creationTimes" },
         "visits": { "$first": "$visits" }
    }},
 
    {
      "$project": {
          creationTimes: { 
              doy: {"$multiply": [{"$second": "$creationTimes" }, 1000]},
              year: {"$year": "$creationTimes"}
              
          },
          visits: 1
      }  
    },

    // Group with the average value
    { "$group": {
        "_id":  "$creationTimes",
        "visits": { "$sum": "$visits" }
    }},

    // Group does not sort results
    { "$sort": { "_id": 1 } }
])