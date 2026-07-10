# Pillar data for the source control (GitLab) state.
# All values below are illustrative placeholders.

gitlab:
  package_name: gitlab-ce
  package_version: '11.6.5-ce.0.el7'
  external_url: https://gitlab.example.com
  repo_baseurl: https://packages.gitlab.com/gitlab/gitlab-ce/el/7/$basearch
  repo_gpgkey: https://packages.gitlab.com/gpg.key
  timezone: America/New_York

  # Applied into /etc/gitlab/gitlab.rb via Jinja template.
  smtp:
    enable: false
    address: smtp.example.com
    port: 587
    user_name: gitlab@example.com
    password: CHANGE_ME_PLACEHOLDER
    domain: example.com

  backup:
    keep_time_seconds: 604800
