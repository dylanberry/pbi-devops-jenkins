#!/bin/bash
accessToken=$(curl -sS "https://login.microsoftonline.com/$TENANTID/oauth2/token" \
	-H "Content-Type: application/x-www-form-urlencoded" \
	-d "grant_type=client_credentials" \
  -d "client_id=$PBI_CREDS_USR" \
  -d "client_secret=$PBI_CREDS_PSW" \
  -d "resource=https://analysis.windows.net/powerbi/api" \
  -d "scope=https://analysis.windows.net/powerbi/api" | jq -r '.access_token')

baseUri="https://api.powerbi.com/v1.0/myorg"

TargetWorkspaceName="$1"
echo "TargetWorkspaceName: $TargetWorkspaceName"
TargetReportName="$2"
echo "TargetReportName: $TargetReportName"
TargetDatasetName="$3"
echo "TargetDatasetName: $TargetDatasetName"


##### Restore #####
encodedSpace="%20"
encodedTargetWorkspaceName="${TargetWorkspaceName// /"$encodedSpace"}"

echo "Get target workspace $TargetWorkspaceName"
targetGroupId=$(curl -sS "$baseUri/groups?%24filter=name%20eq%20%27${encodedTargetWorkspaceName}%27" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[0].id')
echo "Found source workspace id $targetGroupId"

echo "Get target $TargetDatasetName dataset"
targetDataset=$(curl -sS "$baseUri/groups/$targetGroupId/datasets" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$TargetDatasetName'")')
targetDatasetId=$(echo $targetDataset | jq -r '.id')
echo "Found target dataset id $targetDatasetId"

sourceReportConnectionsFilePath="$PWD/$TargetReportName/Connections"

echo "Updating dataset connection string in $sourceReportConnectionsFilePath"
cat $sourceReportConnectionsFilePath | jq '.RemoteArtifacts[0].DatasetId = "'$targetDatasetId'"' > $sourceReportConnectionsFilePath

sourceReportFolder="$PWD/$TargetReportName"
restoredReportPath="$PWD/$TargetReportName.pbix"
echo "Zipping $sourceReportFolder to $restoredReportPath"
cd $sourceReportFolder
zip -r $restoredReportPath ./*
cd -

echo "Uploading report $restoredReportPath"
curl -F "data=@$restoredReportPath" "$baseUri/groups/$targetGroupId/imports?datasetDisplayName=$TargetReportName.pbix&nameConflict=CreateOrOverwrite" \
  -H "Authorization: Bearer $accessToken"

# Pause for 2 seconds to allow report to be uploaded
sleep 2

echo "Get reports"
targetReportId=$(curl -sS "$baseUri/groups/$targetGroupId/reports" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$TargetReportName'") | .id')
echo "Found target report id $targetReportId"

echo "Rebinding report $TargetReportName to $TargetDatasetName"
curl -X POST "$baseUri/groups/$targetGroupId/reports/$targetReportId/Rebind" \
  -H "Authorization: Bearer $accessToken" \
  -d "{ \"datasetId\": \"$targetDatasetId\" }" \
  -H "Content-Type: application/json"

echo "Get datasets"
restoredDatasetId=$(curl -sS "$baseUri/groups/$targetGroupId/datasets" \
  -H "Authorization: Bearer $accessToken" | jq -r '.value[] | select(.name == "'$TargetReportName'") | .id')
echo "Cleaning up dataset"
curl -X Delete "$baseUri/groups/$targetGroupId/datasets/$restoredDatasetId" \
  -H "Authorization: Bearer $accessToken" \
  -H "Content-Type: application/json"