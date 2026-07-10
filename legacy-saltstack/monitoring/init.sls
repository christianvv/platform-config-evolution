# Monitoring server — Nagios Core, native install.
# srv/salt/monitoring/init.sls

epel_repo:
  pkg.installed:
    - name: epel-release

nagios_pkgs:
  pkg.installed:
    - pkgs:
      - nagios
      - nagios-plugins-all
      - nrpe
      - httpd
      - php
    - require:
      - pkg: epel_repo

nagios_web_password_file:
  file.managed:
    - name: /etc/nagios/passwd
    - contents: '{{ pillar["monitoring"]["web_admin_user"] }}:{{ pillar["monitoring"]["web_admin_pw_hash"] }}'
    - user: root
    - group: apache
    - mode: '0640'
    - require:
      - pkg: nagios_pkgs

nagios_contact_email:
  file.replace:
    - name: /etc/nagios/objects/contacts.cfg
    - pattern: 'nagios@localhost'
    - repl: '{{ pillar["monitoring"]["admin_email"] }}'
    - require:
      - pkg: nagios_pkgs

devops_hosts_cfg:
  file.managed:
    - name: /etc/nagios/objects/devops_hosts.cfg
    - source: salt://monitoring/templates/devops_hosts.cfg.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0644'
    - require:
      - pkg: nagios_pkgs

devops_hosts_cfg_include:
  file.replace:
    - name: /etc/nagios/nagios.cfg
    - pattern: '^#cfg_dir=/etc/nagios/objects$'
    - repl: 'cfg_dir=/etc/nagios/objects'
    - append_if_not_found: True
    - require:
      - pkg: nagios_pkgs

{% if grains['osmajorrelease'] == '7' %}
httpd_selinux_network_connect:
  selinux.boolean:
    - name: httpd_can_network_connect
    - value: True
    - persist: True
{% endif %}

nagios_running:
  service.running:
    - name: nagios
    - enable: True
    - require:
      - file: nagios_web_password_file
      - file: devops_hosts_cfg
      - file: devops_hosts_cfg_include
    - watch:
      - file: devops_hosts_cfg

httpd_running:
  service.running:
    - name: httpd
    - enable: True
    - require:
      - file: nagios_web_password_file
