curl "http://207.97.212.169:3010/IOSEvents.bson" > ~/Downloads/IOSEvents.bson
mongorestore --db MA --collection IOSEvents ~/Downloads/IOSEvents.bson
