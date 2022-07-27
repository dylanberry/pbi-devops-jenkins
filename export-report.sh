#!/bin/bash
accessToken=$(curl "https://login.microsoftonline.com/$TENANTID/oauth2/token" \
	-H "Content-Type: application/x-www-form-urlencoded" \
	-d "grant_type=client_credentials" \
  -d "client_id=$PBI_CREDS_USR" \
  -d "client_secret=$PBI_CREDS_PSW" \
  -d "resource=https://analysis.windows.net/powerbi/api" \
  -d "scope=https://analysis.windows.net/powerbi/api" | jq -r '.access_token')
echo "accessToken: $accessToken"

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
sourceGroupId=$(curl -sS "$baseUri/groups?%24filter=name%20eq%20%27${encodedSourceWorkspaceName}%27" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[0].id')
echo "Found source workspace id $sourceGroupId"

echo "Get source $SourceReportName report"
sourceReport=$(curl -sS "$baseUri/groups/$sourceGroupId/reports" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$SourceReportName'")')
sourceReportId=$(echo $sourceReport | jq -r '.id')
echo "Found source report id $sourceReportId"

echo "Get dummy $DummyReportName report"
dummyReport=$(curl -sS "$baseUri/groups/$sourceGroupId/reports" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$DummyReportName'")')
dummyReportId=$(echo $dummyReport | jq -r '.id')
echo "Found dummy report id $dummyReportId"

exportReportName="$SourceReportName-export"
echo "Clone $DummyReportName to $exportReportName report"
exportReport=$(curl -sSX POST "$baseUri/groups/$sourceGroupId/reports/$dummyReportId/Clone" \
  -H "Authorization: Bearer $accessToken" \
  -d "{ \"name\": \""$exportReportName"\" }" \
  -H "Content-Type: application/json")  
exportReportId=$(echo $exportReport | jq -r '.id')
echo "Cloned export report id $exportReportId"

updateReportContentBody="{ 
    \"sourceReport\":
        {
            \"sourceReportId\": \"$sourceReportId\",
            \"sourceWorkspaceId\": \"$sourceGroupId\"
        },
    \"sourceType\": \"ExistingReport\"
}"

echo "Copy report content from $sourceReportName to $exportReportName"
curl -sSX POST "$baseUri/groups/$sourceGroupId/reports/$exportReportId/UpdateReportContent" \
  -H "Authorization: Bearer $accessToken" \
  -d "$updateReportContentBody" \
  -H "Content-Type: application/json"

echo "Get $DummyDatasetName dataset"
dummyDatasetId=$(curl -sS "$baseUri/groups/$sourceGroupId/datasets" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$DummyDatasetName'") | .id')
echo "Found dummy dataset id $dummyDatasetId"

echo "Rebinding report $exportReportName to $DummyDatasetName"
curl -sSX POST "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Rebind" \
  -H "Authorization: Bearer $accessToken" \
  -d "{ \"datasetId\": \"$dummyDatasetId\" }" \
  -H "Content-Type: application/json"

sourceReportFilePath="$PWD/$SourceReportName.pbix"
echo "Exporting report $exportReportName ($exportReportId) to $sourceReportFilePath"
echo "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Export?preferClientRouting=true"
curl -sS "$baseUri/groups/$sourceGroupId/reports/$exportReportId/Export?preferClientRouting=true" \
  -H "Authorization: Bearer $accessToken" \
  -o $sourceReportFilePath

# TODO: unzip
unzip -o $sourceReportFilePath