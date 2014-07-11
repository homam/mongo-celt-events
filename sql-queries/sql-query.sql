USE mobitrans;

SELECT V.VID as visitId, W.RequestId as submissionId, S.SubscriberId as subscriberId, S.Active_12 as active12, S.Active as active, D.wurfl_device_id, D.brand_name, D.model_name, D.marketing_name
FROM dbo.Wap_Visits V WITH (NOLOCK) 
LEFT JOIN dbo.Web_Subscriptions W WITH (NOLOCK) ON V.VID = W.VisitId AND W.Source = 1
LEFT JOIN dbo.Subscribers S WITH (NOLOCK) ON S.SubscriberId = W.SubscriberId
LEFT JOIN dbo.Wap_Visits_Ua U WITH (NOLOCK) ON U.UA_Id = V.UA_Id
LEFT JOIN dbo.WURFL_Device_Caps D ON D.Wurfl_Id = U.Wurfl_Id

WHERE V.VID IN ({{VIDs}})
