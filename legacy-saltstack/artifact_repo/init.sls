# Artifact repository server — Nexus Repository Manager, native install.
# srv/salt/artifact_repo/init.sls

nexus_java:
  pkg.installed:
    - name: java-1.8.0-openjdk

nexus_group:
  group.present:
    - name: {{ pillar['nexus']['service_group'] }}
    - system: True

nexus_user:
  user.present:
    - name: {{ pillar['nexus']['service_user'] }}
    - system: True
    - gid: {{ pillar['nexus']['service_group'] }}
    - home: {{ pillar['nexus']['install_dir'] }}
    - createhome: False
    - require:
      - group: nexus_group

nexus_data_dir:
  file.directory:
    - name: {{ pillar['nexus']['data_dir'] }}
    - user: {{ pillar['nexus']['service_user'] }}
    - group: {{ pillar['nexus']['service_group'] }}
    - makedirs: True
    - require:
      - user: nexus_user

nexus_archive:
  archive.extracted:
    - name: /opt
    - source: {{ pillar['nexus']['download_url'] }}
    - archive_format: tar
    - if_missing: {{ pillar['nexus']['install_dir'] }}-{{ pillar['nexus']['version'] }}
    - enforce_toplevel: False
    - require:
      - pkg: nexus_java

nexus_symlink:
  file.symlink:
    - name: {{ pillar['nexus']['install_dir'] }}
    - target: {{ pillar['nexus']['install_dir'] }}-{{ pillar['nexus']['version'] }}
    - require:
      - archive: nexus_archive

nexus_ownership:
  file.directory:
    - name: {{ pillar['nexus']['install_dir'] }}-{{ pillar['nexus']['version'] }}
    - user: {{ pillar['nexus']['service_user'] }}
    - group: {{ pillar['nexus']['service_group'] }}
    - recurse:
      - user
      - group
    - require:
      - file: nexus_symlink

nexus_rc_file:
  file.managed:
    - name: {{ pillar['nexus']['install_dir'] }}/bin/nexus.rc
    - source: salt://artifact_repo/templates/nexus.rc.jinja
    - template: jinja
    - require:
      - file: nexus_ownership

nexus_vmoptions_file:
  file.managed:
    - name: {{ pillar['nexus']['install_dir'] }}/bin/nexus.vmoptions
    - source: salt://artifact_repo/templates/nexus.vmoptions.jinja
    - template: jinja
    - user: {{ pillar['nexus']['service_user'] }}
    - group: {{ pillar['nexus']['service_group'] }}
    - require:
      - file: nexus_ownership

nexus_systemd_unit:
  file.managed:
    - name: /etc/systemd/system/nexus.service
    - source: salt://artifact_repo/templates/nexus.service.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'

nexus_systemd_reload:
  cmd.run:
    - name: systemctl daemon-reload
    - onchanges:
      - file: nexus_systemd_unit

nexus_running:
  service.running:
    - name: nexus
    - enable: True
    - require:
      - cmd: nexus_systemd_reload
      - file: nexus_rc_file
      - file: nexus_vmoptions_file
      - file: nexus_data_dir
