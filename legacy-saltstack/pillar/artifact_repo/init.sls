# Pillar data for the artifact repository (Nexus Repository Manager) state.
# All values below are illustrative placeholders.

nexus:
  version: '3.14.0-04'
  download_url: https://download.sonatype.com/nexus/3/nexus-3.14.0-04-unix.tar.gz
  install_dir: /opt/nexus
  data_dir: /srv/nexus-data
  service_user: nexus
  service_group: nexus
  min_heap: 1200m
  max_heap: 1200m
  external_url: https://nexus.example.com

  repos:
    - name: yum-internal
      type: yum-hosted
    - name: docker-internal
      type: docker-hosted
    - name: maven-releases
      type: maven2-hosted
