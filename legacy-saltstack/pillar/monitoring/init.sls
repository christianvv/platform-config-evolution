# Pillar data for the monitoring (Nagios) state.
# All values below are illustrative placeholders. Monitored hosts are
# referenced by minion ID / hostname rather than IP address, resolved via
# internal DNS.

monitoring:
  admin_email: oncall@example.com
  web_admin_user: nagiosadmin
  web_admin_pw_hash: placeholderHashValueNotReal

  # Hosts monitored via NRPE, matching the rest of the DevOps tooling fleet.
  monitored_hosts:
    - hostname: devops-gitlab-01
      alias: Source Control (GitLab)
      checks: [check_mem, check_disk, check_load]
    - hostname: devops-nexus-01
      alias: Artifact Repository (Nexus)
      checks: [check_mem, check_disk, check_load]
    - hostname: devops-ldap-01
      alias: Directory Services (LDAP)
      checks: [check_mem, check_disk, check_load]
    - hostname: devops-gitlabrunner-01
      alias: CI/CD Runner (GitLab Runner)
      checks: [check_mem, check_disk, check_load]

  notification_period: 24x7
  check_interval_minutes: 5
