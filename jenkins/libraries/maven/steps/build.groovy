void call() {
    pipeline {
        agent any
        options {
            skipDefaultCheckout()
        }
        stages {
            stage("build") {
                steps {
                    script {
                        pipelineConfig.application_environments.each{ k, v ->
                            stage(k) {
                                println "environment: ${k}"
                                process(k, v)
                            }
                        }
                    }
                }
            }
        }
        post {
            // Clean after build
            always {
                cleanWs(cleanWhenNotBuilt: false,
                        deleteDirs: true,
                        disableDeferredWipeout: true,
                        notFailBuild: true,
                        patterns: [[pattern: '.gitignore', type: 'INCLUDE'],
                                   [pattern: '.propsfile', type: 'EXCLUDE']])
            }
        }
    }
}
