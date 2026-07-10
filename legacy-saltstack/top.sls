# State top file — maps minions to the state modules applied to them.
# Placed in /srv/salt/top.sls on the Salt master (base environment only;
# this fleet did not use multiple Salt environments).

base:
  'devops-gitlab-01':
    - source_control

  'devops-nexus-01':
    - artifact_repo

  'devops-ldap-01':
    - directory_services

  'devops-gitlabrunner-01':
    - cicd_runner

  'devops-monitor-01':
    - monitoring
