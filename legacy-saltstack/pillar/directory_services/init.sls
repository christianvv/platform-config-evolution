# Pillar data for the directory services (OpenLDAP) state.
# All values below are illustrative placeholders. Bind credentials in a real
# deployment would come from an encrypted pillar (GPG) rather than plaintext.

directory_services:
  base_dn: dc=example,dc=com
  organization: Example Org
  domain: example.com

  root_dn: cn=admin,dc=example,dc=com
  root_pw_hash: '{SSHA}placeholderHashValueNotReal=='

  suffix_ous:
    - people
    - groups
    - services

  admin_group: ldapadmins
  tls:
    cert_file: /etc/openldap/certs/ldap-server.crt
    key_file: /etc/openldap/certs/ldap-server.key
    ca_file: /etc/openldap/certs/ca.crt
