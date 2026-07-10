# Source control server — GitLab CE (Omnibus package), native install.
# srv/salt/source_control/init.sls

gitlab_repo:
  pkgrepo.managed:
    - name: gitlab_gitlab-ce
    - humanname: GitLab CE
    - baseurl: {{ pillar['gitlab']['repo_baseurl'] }}
    - gpgcheck: 1
    - gpgkey: {{ pillar['gitlab']['repo_gpgkey'] }}
    - enabled: 1

gitlab_pkg:
  pkg.installed:
    - name: {{ pillar['gitlab']['package_name'] }}
    - version: {{ pillar['gitlab']['package_version'] }}
    - require:
      - pkgrepo: gitlab_repo

gitlab_config_file:
  file.managed:
    - name: /etc/gitlab/gitlab.rb
    - source: salt://source_control/templates/gitlab.rb.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - pkg: gitlab_pkg

gitlab_reconfigure:
  cmd.run:
    - name: gitlab-ctl reconfigure
    - onchanges:
      - file: gitlab_config_file

# Omnibus manages GitLab's own services (nginx, unicorn/puma, postgres,
# redis, sidekiq) under runit, supervised by this single systemd unit.
gitlab_running:
  service.running:
    - name: gitlab-runsvdir
    - enable: True
    - require:
      - cmd: gitlab_reconfigure
