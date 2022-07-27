pipeline {
    agent any
    parameters {
        string(name: 'REPORT_NAME', description: 'Report Name', defaultValue: 'helloworld_pbiservice_1')
        string(name: 'WORKSPACE_NAME', description: 'Workspace Name', defaultValue: 'Source')
    }
    environment {
        PBI_CREDS = credentials('pbi-dev')
    }
    stages {
        // stage('Preparation') {
        //     steps {
        //         git branch: 'main', url: 'https://github.com/dylanberry/pbi-devops-jenkins/'
        //         sh 'ls $WORKSPACE'
        //     }
        // }
        stage('Export') {
            steps {
                withEnv(['TENANTID=3a738245-bbdf-42b4-a0b9-0a3324c8c85e']) {
                    sh "chmod +x -R $WORKSPACE"
                    sh '$WORKSPACE/export-report.sh $REPORT_NAME $WORKSPACE_NAME'
                }
            }
        }
    }
}
