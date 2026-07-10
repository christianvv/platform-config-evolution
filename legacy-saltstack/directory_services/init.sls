# Directory services server — OpenLDAP, native install.
# srv/salt/directory_services/init.sls

ldap_pkgs:
  pkg.installed:
    - pkgs:
      - openldap-servers
      - openldap-clients

slapd_service:
  service.running:
    - name: slapd
    - enable: True
    - require:
      - pkg: ldap_pkgs

# Point the default backend database at this fleet's suffix and root DN.
# Applied once via SASL EXTERNAL over the local ldapi:// socket (root's Unix
# peer credentials authenticate to cn=config — no bind password needed here).
# slapd picks up cn=config changes live, so no restart is required.
db_config_file:
  file.managed:
    - name: /etc/openldap/db.ldif
    - source: salt://directory_services/templates/db.ldif.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - service: slapd_service

db_config_apply:
  cmd.run:
    - name: ldapmodify -Y EXTERNAL -H ldapi:/// -f /etc/openldap/db.ldif
    - creates: /etc/openldap/.db_configured
    - require:
      - file: db_config_file

db_config_marker:
  file.managed:
    - name: /etc/openldap/.db_configured
    - contents: 'suffix and rootDN configured by Salt'
    - require:
      - cmd: db_config_apply

# Load the base DIT (top entry, OUs, admin group) idempotently — skipped
# once the base entry already exists.
base_ldif_file:
  file.managed:
    - name: /etc/openldap/base.ldif
    - source: salt://directory_services/templates/base.ldif.jinja
    - template: jinja
    - user: root
    - group: root
    - mode: '0600'
    - require:
      - cmd: db_config_apply

base_ldif_apply:
  cmd.run:
    - name: ldapadd -Y EXTERNAL -H ldapi:/// -f /etc/openldap/base.ldif
    - unless: ldapsearch -Y EXTERNAL -H ldapi:/// -b "{{ pillar['directory_services']['base_dn'] }}" -s base dn 2>/dev/null | grep -q '^dn:'
    - require:
      - file: base_ldif_file
