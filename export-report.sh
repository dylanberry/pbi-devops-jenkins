#!/bin/bash
accessToken=$(curl "https://login.microsoftonline.com/$TENANTID/oauth2/token" \
	-H "Content-Type: application/x-www-form-urlencoded" \
	-d "grant_type=client_credentials" \
  -d "client_id=$PBI_CREDS_USR" \
  -d "client_secret=$PBI_CREDS_PSW" \
  -d "resource=https://analysis.windows.net/powerbi/api" \
  -d "scope=https://analysis.windows.net/powerbi/api" | jq -r '.access_token')

baseUri="https://api.powerbi.com/v1.0/myorg"

SourceWorkspaceName="Source"
SourceReportName="helloworld_pbiservice_1"

DummyDatasetName="blank"
DummyReportName="blank"

TargetWorkspaceName="Target"
TargetDatasetName="helloworld"
TargetReportName="helloworld_restored"


##### Backup #####
encodedSpace="%20"
encodedSourceWorkspaceName="${SourceWorkspaceName// /"$encodedSpace"}"

echo "Get source workspace $SourceWorkspaceName"
sourceGroupId=$(curl "$baseUri/groups?%24filter=name%20eq%20%27${encodedSourceWorkspaceName}%27" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[0].id')

echo "Get source $SourceReportName report"
sourceReport=$(curl -s "$baseUri/groups/$sourceGroupId/reports" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$SourceReportName'")')

echo "Get dummy $DummyReportName report"
dummyReport=$(curl -s "$baseUri/groups/$sourceGroupId/reports" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$DummyReportName'")')

sourceReportName=$(echo $sourceReport | jq -r '.name')
sourceReportId=$(echo $sourceReport | jq -r '.id')

dummyReportId=$(echo $dummyReport | jq -r '.id')

exportReportName="$SourceReportName-export"
echo "Clone $DummyReportName to $exportReportName report"
exportReport=$(curl -X POST "$baseUri/groups/$sourceGroupId/reports/$dummyReportId/Clone" \
  -H "Authorization: Bearer $accessToken" \
  -d "{ \"name\": \""$exportReportName"\" }" \
  -H "Content-Type: application/json")
  
exportReportId=$(echo $exportReport | jq -r '.id')

updateReportContentBody="{ 
    \"sourceReport\":
        {
            \"sourceReportId\": \"$sourceReportId\",
            \"sourceWorkspaceId\": \"$sourceGroupId\"
        },
    \"sourceType\": \"ExistingReport\"
}"

echo "Copy report content from $sourceReportName to $exportReportName"
curl -X POST "$baseUri/groups/$sourceGroupId/reports/$exportReportId/UpdateReportContent" \
  -H "Authorization: Bearer $accessToken" \
  -d "$updateReportContentBody" \
  -H "Content-Type: application/json"

echo "Get $DummyDatasetName dataset"
dummyDatasetId=$(curl -s "$baseUri/groups/$sourceGroupId/datasets" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$DummyDatasetName'") | .id')

echo "Rebinding report $exportReportName to $DummyDatasetName"
curl -X POST "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Rebind" \
  -H "Authorization: Bearer $accessToken" \
  -d "{ \"datasetId\": \"$dummyDatasetId\" }" \
  -H "Content-Type: application/json"

sourceReportFilePath="$PWD/$SourceReportName.pbix"
echo "Exporting report $exportReportName to $sourceReportFilePath"
echo "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Export?preferClientRouting=true"
curl "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Export?preferClientRouting=true" \
  -H "Authorization: Bearer $accessToken" \
  -o $sourceReportFilePath

# TODO: unzip
unzip -o $sourceReportFilePath