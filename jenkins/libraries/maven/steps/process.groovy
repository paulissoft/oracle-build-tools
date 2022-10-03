// -*- mode: groovy; coding: utf-8 -*-
void call(app_env){
    script {
        /*
        -- SCM credentials username and e-mail (pipeline config application environment, pipeline config global or environment variable).
        */
        
        // It must be possible to specify the SCM username and email as environment variables in Jenkins configuration.
        // https://github.com/paulissoft/oracle-tools/issues/70
        if ( app_env.scm_username != null ) {
            env.SCM_USERNAME = app_env.scm_username
        } else if ( pipelineConfig.scm_username != null ) {
            env.SCM_USERNAME = pipelineConfig.scm_username
        }
        assert env.SCM_USERNAME != null : "The pipeline configuration must contain a value for 'scm_username' (in application environment '${app_env.long_name}' or global) or environment variable SCM_USERNAME must be defined"
        
        if ( app_env.scm_email != null ) {
            env.SCM_EMAIL = app_env.scm_email
        } else if ( pipelineConfig.scm_email != null ) {
            env.SCM_EMAIL = pipelineConfig.scm_email
        }
        assert env.SCM_EMAIL != null : "The pipeline configuration must contain a value for 'scm_email' (in application environment '${app_env.long_name}' or global) or environment variable SCM_EMAIL must be defined"

        /*
        -- The SCM Oracle Tools project needed to build the SCM project (pipeline config application environment, pipeline config global or environment variable).
        */

        if ( app_env.scm_url_oracle_tools != null ) {
            env.SCM_URL_ORACLE_TOOLS = app_env.scm_url_oracle_tools
        } else if ( pipelineConfig.scm_url_oracle_tools != null ) {
            env.SCM_URL_ORACLE_TOOLS = pipelineConfig.scm_url_oracle_tools
        }
        assert env.SCM_URL_ORACLE_TOOLS != null : "The pipeline configuration must contain a value for 'scm_url_oracle_tools' (in application environment '${app_env.long_name}' or global) or environment variable SCM_URL_ORACLE_TOOLS must be defined"

        if ( app_env.scm_branch_oracle_tools != null ) {
            env.SCM_BRANCH_ORACLE_TOOLS = app_env.scm_branch_oracle_tools
        } else if ( pipelineConfig.scm_branch_oracle_tools != null ) {
            env.SCM_BRANCH_ORACLE_TOOLS = pipelineConfig.scm_branch_oracle_tools
        }
        assert env.SCM_BRANCH_ORACLE_TOOLS != null : "The pipeline configuration must contain a value for 'scm_branch_oracle_tools' (in application environment '${app_env.long_name}' or global) or environment variable SCM_BRANCH_ORACLE_TOOLS must be defined"

        env.SCM_PROJECT_ORACLE_TOOLS = env.SCM_URL_ORACLE_TOOLS.substring(env.SCM_URL_ORACLE_TOOLS.lastIndexOf("/") + 1).replaceAll("\\.git$", "")
        env.SCM_PROJECT_ORACLE_TOOLS += ( env.SCM_BRANCH_ORACLE_TOOLS.matches("^(master|main)$") ? "" : "." + env.SCM_BRANCH_ORACLE_TOOLS )
        
        /*
        -- The SCM (database) configuration project needed to build the SCM project (pipeline config application environment, pipeline config global or environment variable).
        */

        if ( app_env.scm_url_config != null ) {
            env.SCM_URL_CONFIG = app_env.scm_url_config
        } else if ( pipelineConfig.scm_url_config != null ) {
            env.SCM_URL_CONFIG = pipelineConfig.scm_url_config
        }
        assert env.SCM_URL_CONFIG != null : "The pipeline configuration must contain a value for 'scm_url_config' (in application environment '${app_env.long_name}' or global) or environment variable SCM_URL_CONFIG must be defined"

        if ( app_env.scm_branch_config != null ) {
            env.SCM_BRANCH_CONFIG = app_env.scm_branch_config
        } else if ( pipelineConfig.scm_branch_config != null ) {
            env.SCM_BRANCH_CONFIG = pipelineConfig.scm_branch_config
        }
        assert env.SCM_BRANCH_CONFIG != null : "The pipeline configuration must contain a value for 'scm_branch_config' (in application environment '${app_env.long_name}' or global) or environment variable SCM_BRANCH_CONFIG must be defined"

        env.SCM_PROJECT_CONFIG = env.SCM_URL_CONFIG.substring(env.SCM_URL_CONFIG.lastIndexOf("/") + 1).replaceAll("\\.git$", "")
        env.SCM_PROJECT_CONFIG += ( env.SCM_BRANCH_CONFIG.matches("^(master|main)$") ? "" : "." + env.SCM_BRANCH_CONFIG )
        
        /*
        -- The SCM project to work on (pipeline config application environment).
        */
        
        env.SCM_BRANCH = app_env.scm_branch
        assert env.SCM_BRANCH != null : "The pipeline configuration must contain a value for 'scm_branch' in application environment '${app_env.long_name}'"

        env.SCM_BRANCH_PREV = ( app_env.scm_branch_prev != null ? app_env.scm_branch_prev : ( app_env.previous != null ? app_env.previous.scm_branch : '' ) )

        env.SCM_CREDENTIALS = ( app_env.scm_credentials != null ? app_env.scm_credentials : pipelineConfig.scm_credentials )
        // assert env.SCM_CREDENTIALS != null : "The pipeline configuration must contain a value for 'scm_credentials' (in application environment '${app_env.long_name}' or global)"

        env.SCM_URL = ( app_env.scm_url != null ? app_env.scm_url : pipelineConfig.scm_url )
        assert env.SCM_URL != null : "The pipeline configuration must contain a value for 'scm_url' (in application environment '${app_env.long_name}' or global)"

        env.SCM_PROJECT = env.SCM_URL.substring(env.SCM_URL.lastIndexOf("/") + 1).replaceAll("\\.git$", "")
        env.SCM_PROJECT += ( env.SCM_BRANCH.matches("^(master|main)$") ? "" : "." + env.SCM_BRANCH )

        /*
        -- The configuration directory to work on (pipeline config application environment, pipeline config global).
        */
        
        env.CONF_DIR = ( app_env.conf_dir != null ? app_env.conf_dir : pipelineConfig.conf_dir )
        assert env.CONF_DIR != null : "The pipeline configuration must contain a value for 'conf_dir' (in application environment '${app_env.long_name}' or global)"

        /*
        -- The database info to work on (pipeline config application environment, pipeline config global).
        */
        
        env.DB = app_env.db
        assert env.DB != null : "The pipeline configuration must contain a value for 'db' in application environment '${app_env.long_name}'"

        env.DB_CREDENTIALS = app_env.db_credentials
        assert env.DB_CREDENTIALS != null : "The pipeline configuration must contain a value for 'db_credentials' in application environment '${app_env.long_name}'"

        env.DB_DIR = ( app_env.db_dir != null ? app_env.db_dir : pipelineConfig.db_dir )
        assert env.DB_DIR != null : "The pipeline configuration must contain a value for 'db_dir' (in application environment '${app_env.long_name}' or global)"

        env.DB_ACTIONS = app_env.db_actions
        assert env.DB_ACTIONS != null : "The pipeline configuration must contain a value for 'db_actions' (in application environment '${app_env.long_name}' or global)"

        /*
        -- The APEX info to work on (pipeline config application environment, pipeline config global).
        */
        
        env.APEX_DIR = ( app_env.apex_dir != null ? app_env.apex_dir : pipelineConfig.apex_dir )
        assert env.APEX_DIR != null : "The pipeline configuration must contain a value for 'apex_dir' (in application environment '${app_env.long_name}' or global)"

        env.APEX_ACTIONS = app_env.apex_actions
        assert env.APEX_ACTIONS != null : "The pipeline configuration must contain a value for 'apex_actions' in application environment '${app_env.long_name}'"
    }
    
    withCredentials([usernamePassword(credentialsId: env.DB_CREDENTIALS, passwordVariable: 'DB_PASSWORD', usernameVariable: 'DB_USERNAME')]) {
        // Clean before build
        cleanWs()

        // checkout of configuration project (maybe credentials needed)
        script {
            if (env.SCM_PROJECT_CONFIG != null) {
                dir(env.SCM_PROJECT_CONFIG) {
                    git url: env.SCM_URL_CONFIG, branch: env.SCM_BRANCH_CONFIG, credentialsId: env.SCM_CREDENTIALS_CONFIG
                }
            }
        }
        
        // checkout of Oracle Tools (no credentials needed)
        script {
            if (env.SCM_PROJECT_CONFIG == null || env.SCM_PROJECT_CONFIG.equals(env.SCM_PROJECT_ORACLE_TOOLS)) {
                dir(env.SCM_PROJECT_ORACLE_TOOLS) {
                    checkout([
                        $class: 'GitSCM', 
                        branches: [[name: '*/' + env.SCM_BRANCH_ORACLE_TOOLS]], 
                        doGenerateSubmoduleConfigurations: false, 
                        extensions: [[$class: 'CleanCheckout']], 
                        submoduleCfg: [], 
                        userRemoteConfigs: [[url: env.SCM_URL_ORACLE_TOOLS]]
                    ])
                }
            }
        }

        // checkout of project to build (maybe credentials needed)
        script {
            dir(env.SCM_PROJECT) {
                git url: env.SCM_URL, branch: env.SCM_BRANCH, credentialsId: env.SCM_CREDENTIALS

                withMaven(options: [artifactsPublisher(disabled: true), 
                                    findbugsPublisher(disabled: true), 
                                    openTasksPublisher(disabled: true)]) {
                    if (env.SCM_CREDENTIALS != null) {
                        sshagent([env.SCM_CREDENTIALS]) {
                            sh('chmod +x $WORKSPACE/oracle-tools/jenkins/process.sh')
                            sh('$WORKSPACE/oracle-tools/jenkins/process.sh')
                        }
                    } else {
                        sh('chmod +x $WORKSPACE/oracle-tools/jenkins/process.sh')
                        sh('$WORKSPACE/oracle-tools/jenkins/process.sh')
                    }
                }
            }
        }
    }
}
