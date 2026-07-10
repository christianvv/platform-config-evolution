# Pillar top file — maps minions to the pillar data made available to them.
# Placed in /srv/pillar/top.sls on the Salt master. Mirrors the structure of
# the state top file: each minion gets only the pillar data its own states
# need.

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
