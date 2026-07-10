# CI/CD runner host — Docker daemon + GitLab Runner (Docker executor).
# srv/salt/cicd_runner/init.sls
#
# Salt manages the Docker daemon and the GitLab Runner installation and
# registration on this dedicated host. The ephemeral, per-job containers
# that GitLab Runner spins up at CI/CD execution time are not Salt-managed —
# they're created and destroyed by the runner itself, which is exactly the
# isolation the Docker executor is meant to provide.

docker_repo:
  pkgrepo.managed:
    - name: docker-ce-stable
    - humanname: Docker CE Stable
    - baseurl: {{ pillar['docker']['repo_baseurl'] }}
    - gpgcheck: 1
    - gpgkey: {{ pillar['docker']['repo_gpgkey'] }}
    - enabled: 1

docker_pkg:
  pkg.installed:
    - name: {{ pillar['docker']['package_name'] }}
    - require:
      - pkgrepo: docker_repo

docker_service:
  service.running:
    - name: docker
    - enable: True
    - require:
      - pkg: docker_pkg

gitlab_runner_repo:
  pkgrepo.managed:
    - name: gitlab_gitlab-runner
    - humanname: GitLab Runner
    - baseurl: {{ pillar['gitlab_runner']['repo_baseurl'] }}
    - gpgcheck: 1
    - gpgkey: {{ pillar['gitlab_runner']['repo_gpgkey'] }}
    - enabled: 1

gitlab_runner_pkg:
  pkg.installed:
    - name: {{ pillar['gitlab_runner']['package_name'] }}
    - require:
      - pkgrepo: gitlab_runner_repo

# The gitlab-runner package creates its own system user; add it to the
# docker group (without clobbering other group memberships) so it can talk
# to the Docker socket when spawning per-job containers.
gitlab_runner_docker_group:
  user.present:
    - name: gitlab-runner
    - optional_groups:
      - docker
    - require:
      - pkg: gitlab_runner_pkg
      - service: docker_service

gitlab_runner_register:
  cmd.run:
    - name: >
        gitlab-runner register --non-interactive
        --url "{{ pillar['gitlab_runner']['gitlab_url'] }}"
        --registration-token "{{ pillar['gitlab_runner']['registration_token'] }}"
        --executor "{{ pillar['gitlab_runner']['executor'] }}"
        --docker-image "{{ pillar['gitlab_runner']['docker_image'] }}"
        --tag-list "{{ pillar['gitlab_runner']['tags'] | join(',') }}"
        --run-untagged={{ pillar['gitlab_runner']['run_untagged'] | lower }}
        --description "{{ grains['id'] }}"
    - unless: grep -q '{{ pillar["gitlab_runner"]["gitlab_url"] }}' /etc/gitlab-runner/config.toml 2>/dev/null
    - require:
      - user: gitlab_runner_docker_group

gitlab_runner_concurrent:
  file.replace:
    - name: /etc/gitlab-runner/config.toml
    - pattern: '^concurrent = \d+$'
    - repl: 'concurrent = {{ pillar["gitlab_runner"]["concurrent"] }}'
    - require:
      - cmd: gitlab_runner_register

gitlab_runner_service:
  service.running:
    - name: gitlab-runner
    - enable: True
    - require:
      - cmd: gitlab_runner_register
    - watch:
      - file: gitlab_runner_concurrent
