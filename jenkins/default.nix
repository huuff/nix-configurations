{ pkgs, lib, ... }:
with lib;
let
  cfg = config.services.jenkins;
in
{
  options = {
  
  };

  config = {
    services.jenkins = {
      enable = true;

      extraJavaOptions = [
        "-Djenkins.install.runSetupWizard=false "
      ];
      
      systemd.services = {
      
        write-jenkins-config = {
          
          script =
            #TODO: Escape these substitutions as they are jenkins' and not nix's
            let
            config = pkgs.writeText "config.xml" '' 
            <?xml version='1.1' encoding='UTF-8'?>
            <hudson>
              <disabledAdministrativeMonitors/>
              <version>2.289.1</version>
              <numExecutors>2</numExecutors>
              <mode>NORMAL</mode>
              <useSecurity>true</useSecurity>
              <authorizationStrategy class="hudson.security.AuthorizationStrategy$Unsecured"/>
              <securityRealm class="hudson.security.SecurityRealm$None"/>
              <disableRememberMe>false</disableRememberMe>
              <projectNamingStrategy class="jenkins.model.ProjectNamingStrategy$DefaultProjectNamingStrategy"/>
              <workspaceDir>${JENKINS_HOME}/workspace/${ITEM_FULL_NAME}</workspaceDir>
              <buildsDir>${ITEM_ROOTDIR}/builds</buildsDir>
              <jdks/>
              <viewsTabBar class="hudson.views.DefaultViewsTabBar"/>
              <myViewsTabBar class="hudson.views.DefaultMyViewsTabBar"/>
              <clouds/>
              <scmCheckoutRetryCount>0</scmCheckoutRetryCount>
              <views>
                <hudson.model.AllView>
                  <owner class="hudson" reference="../../.."/>
                  <name>all</name>
                  <filterExecutors>false</filterExecutors>
                  <filterQueue>false</filterQueue>
                  <properties class="hudson.model.View$PropertyList"/>
                </hudson.model.AllView>
              </views>
              <primaryView>all</primaryView>
              <slaveAgentPort>0</slaveAgentPort>
              <label></label>
              <crumbIssuer class="hudson.security.csrf.DefaultCrumbIssuer">
                <excludeClientIPFromCrumb>false</excludeClientIPFromCrumb>
              </crumbIssuer>
              <nodeProperties/>
              <globalNodeProperties/>
            </hudson>
            '';
          in
           "ln -s ${config} ${cfg.home}/config.xml";
        };

      };

    };
  };

}
