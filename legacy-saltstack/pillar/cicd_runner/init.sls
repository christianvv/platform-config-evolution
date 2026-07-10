# Pillar data for the CI/CD runner (GitLab Runner + Docker executor) state.
# All values below are illustrative placeholders. In a real deployment the
# registration token would live in an encrypted pillar (GPG), not plaintext.

gitlab_runner:
  gitlab_url: https://gitlab.example.com
  registration_token: CHANGE_ME_PLACEHOLDER_TOKEN
  executor: docker
  docker_image: alpine:latest
  concurrent: 4
  tags:
    - docker
    - linux
  run_untagged: false

docker:
  package_name: docker-ce
  repo_baseurl: https://download.docker.com/linux/centos/7/$basearch/stable
  repo_gpgkey: https://download.docker.com/linux/centos/gpg
  storage_driver: overlay2
