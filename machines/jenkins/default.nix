{ config, pkgs, lib, ... }:
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
        #withCLI = true;

        extraJavaOptions = [
          "-Djenkins.install.runSetupWizard=false "
        ];
      };

      systemd.services = {

        write-jenkins-config = {
          description = "Write Jenkins' config.xml";

          script =
            let
              config = pkgs.writeText "config.xml" '' 
                <?xml version='1.1' encoding='UTF-8'?>
                <hudson>
                <disabledAdministrativeMonitors/>
                <version>${cfg.package.version}</version>
                <numExecutors>2</numExecutors>
                <mode>NORMAL</mode>
                <useSecurity>true</useSecurity>
                <authorizationStrategy class="hudson.security.AuthorizationStrategy$Unsecured"/>
                <securityRealm class="hudson.security.SecurityRealm$None"/>
                <disableRememberMe>false</disableRememberMe>
                <projectNamingStrategy class="jenkins.model.ProjectNamingStrategy$DefaultProjectNamingStrategy"/>
                <workspaceDir>''${JENKINS_HOME}/workspace/''${ITEM_FULL_NAME}</workspaceDir>
                <buildsDir>''${ITEM_ROOTDIR}/builds</buildsDir>
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
            in ''
              rm ${cfg.home}/config.xml
              ln -s ${config} ${cfg.home}/config.xml
            '';

            wantedBy = [ "multi-user.target" ];

            unitConfig = {
              After = [ "jenkins.service"];
              Requires = [ "jenkins.service" ];
            };

            serviceConfig = {
              User = cfg.user;
              Type = "oneshot";
              RemainAfterExit = true;
            };

          };

        };

      };

    }
