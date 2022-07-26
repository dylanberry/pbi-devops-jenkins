#az login --service-principal -u $env:ClientId -p $env:ClientSecret --tenant $env:TenantId
accessToken=$(az account get-access-token --resource 'https://analysis.windows.net/powerbi/api' | jq -r '.accessToken')
tenantId=$(az account show | jq -r '.tenantId')

baseUri="https://api.powerbi.com/v1.0/myorg"

TargetWorkspaceName="Target"
TargetDatasetName="helloworld"
TargetReportName="helloworld_restored"



##### Restore #####

echo "Get workspace $TargetWorkspaceName"
groups=$(curl -X GET \
  "$baseUri/groups?`$filter=name eq '$TargetWorkspaceName'" \
  -H "Authorization: Bearer $accessToken")
targetGroupId = $groups.value[0].Id

echo "Get datasets"
datasets=$(curl -X GET "$baseUri/groups/$targetGroupId/datasets" \
  -H "Authorization: Bearer $accessToken")
targetDataset = $datasets.value | ? name -eq $TargetDatasetName

sourceReportConnectionsFilePath = Join-Path $PWD.Path $SourceReportName "Connections"

echo "Updating dataset connection string in $sourceReportConnectionsFilePath"
connections = Get-Content $sourceReportConnectionsFilePath | ConvertFrom-Json
connections.RemoteArtifacts[0].DatasetId = $targetDataset.id

echo "Saving updated connections file $sourceReportConnectionsFilePath"
connections | ConvertTo-Json -Depth 32 | Out-File -FilePath $sourceReportConnectionsFilePath -Encoding utf8 -Force

sourceReportFolder = Join-Path $PWD.Path $SourceReportName
restoredReportPath = Join-Path $PWD.Path "$TargetReportName.pbix"
echo "Zipping $sourceReportFolder to $restoredReportPath"
Compress-Archive $sourceReportFolder\* $restoredReportPath -Force

echo "Uploading report $restoredReportPath"
uri = "$baseUri/groups/$($targetGroupId)/imports?datasetDisplayName=$($TargetReportName).pbix&nameConflict=CreateOrOverwrite"
boundary = "---------------------------" + (Get-Date).Ticks.ToString("x")
boundarybytes = [System.Text.Encoding]::ASCII.GetBytes("`r`n--" + $boundary + "`r`n")

request = [System.Net.WebRequest]::Create($uri)
request.ContentType = "multipart/form-data; boundary=" + $boundary
request.Method = "POST"
request.KeepAlive = $true
request.Headers.Add("Authorization", "Bearer $($token.accessToken)")
rs = $request.GetRequestStream()

rs.Write($boundarybytes, 0, $boundarybytes.Length);
header = "Content-Disposition: form-data; filename=`"temp.pbix`"`r`nContent-Type: application / octet - stream`r`n`r`n"
headerbytes = [System.Text.Encoding]::UTF8.GetBytes($header)
rs.Write($headerbytes, 0, $headerbytes.Length);
fileContent = [System.IO.File]::ReadAllBytes($restoredReportPath)
rs.Write($fileContent,0,$fileContent.Length)
trailer = [System.Text.Encoding]::ASCII.GetBytes("`r`n--" + $boundary + "--`r`n");
rs.Write($trailer, 0, $trailer.Length);
rs.Flush()
rs.Close()

response = $request.GetResponse()
stream = $response.GetResponseStream()
streamReader = [System.IO.StreamReader]($stream)
content = $streamReader.ReadToEnd() | convertfrom-json
jobId = $content.id
streamReader.Close()
response.Close()
echo "Import job created $jobId"

Start-Sleep -Milliseconds 500

echo "Get reports"
sourceReports=$(curl -X GET "$baseUri/groups/$targetGroupId/reports" \
  -H "Authorization: Bearer $accessToken")
targetReport = $sourceReports.value | ? name -EQ $TargetReportName

echo "Rebinding report $($targetReport.name) to $($targetDataset.name)"
rebindBody = @{ "datasetId" = "$($targetDataset.id)" } | ConvertTo-Json -Compress
curl -X POST "$baseUri/groups/$targetGroupId/reports/$($targetReport.id)/Rebind" \
  -H "Authorization: Bearer $accessToken") \
  -Body $rebindBody -H "Content-Type: application/json" -Verbose

echo "Get datasets"
datasets=$(curl -X GET "$baseUri/groups/$targetGroupId/datasets" \
  -H "Authorization: Bearer $accessToken")
restoredDataset = $datasets.value | ? name -eq $targetReport.name
echo "Cleaning up dataset"
curl -X Delete "$baseUri/groups/$targetGroupId/datasets/$($restoredDataset.id)" \
  -H "Authorization: Bearer $accessToken") \
  -H "Content-Type: application/json" -Verbose