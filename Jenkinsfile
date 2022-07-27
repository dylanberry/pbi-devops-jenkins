pipeline {
    agent any
    parameters {
        string(name: 'SOURCE_ENVIRONMENT', description: 'Source Environment', defaultValue: 'dev')
        string(name: 'REPORT_NAME', description: 'Report Name', defaultValue: 'helloworld_pbiservice_1')
        string(name: 'WORKSPACE_NAME', description: 'Workspace Name', defaultValue: 'Source')
    }
    environment {
        TENANTID = credentials("pbi-${params.SOURCE_ENVIRONMENT}-tenantid")
        PBI_CREDS = credentials("pbi-${params.SOURCE_ENVIRONMENT}")
    }
    stages {
        stage('Export') {
            steps {
                sh "chmod +x -R $WORKSPACE"
                sh '$WORKSPACE/export-report.sh $REPORT_NAME $WORKSPACE_NAME'
            }
        }
    }
}
