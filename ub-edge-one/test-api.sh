export KEY=TEST2; export BASE="https://dataprovider-x-controlplane.construct-x.ub-edge-one.de/management"
 
curl -sS -X POST "$BASE/v3/assets/request" -H "X-Api-Key: $KEY"
 
curl -sS -X POST "$BASE/v3/policydefinitions/request" -H "X-Api-Key: $KEY"
 
curl -sS -X POST "$BASE/v3/contractdefinitions/request" -H "X-Api-Key: $KEY"
