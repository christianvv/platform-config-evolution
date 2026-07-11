# Legacy: SaltStack Configuration Management (circa 2016–2018)

This directory is a recreation of a SaltStack-based configuration management
system originally architected and implemented for a private-subnet DevOps
tooling environment on AWS — the same environment provisioned by
[`ec2-provisioning-evolution`](https://github.com/christianvv/ec2-provisioning-evolution)'s
`legacy-salt-cloud` piece. The original system was built circa 2016–2018 using
SaltStack's standard state tree and pillar model, targeting CentOS 7 as the
base OS.

This is a demonstration of the architecture and design, rebuilt generically
from memory and design knowledge. It is not a copy of production code, and
all configuration values — URLs, DNs, tokens, hashes — are illustrative
placeholders.

---

## Skills Demonstrated

- Standard Salt state tree + pillar structure with `top.sls` targeting by
  minion ID
- Jinja templating within both state files and rendered config files,
  parameterized entirely from pillar data
- Native (non-containerized) service management: package repos, pinned
  versions, rendered config, and `service.running` with `watch`/`onchanges`
  so restarts happen only when config actually changes
- Idempotent one-time operations (LDAP DIT loading, GitLab Runner
  registration) using `unless`/`creates` guards rather than re-running
  destructive commands on every state apply
- A deliberate architectural exception: the one component that *is*
  container-based — GitLab Runner's Docker executor — with a clear
  boundary between what Salt manages (the daemon, the runner, its
  registration) and what it intentionally does not (ephemeral per-job
  containers)
- Pillar/state separation keeping secrets and environment-specific values
  (URLs, DNs, tokens) out of the state logic itself

---

## Context and era

**Tool:** SaltStack, same era as the companion repo's `salt-cloud` piece
(circa 2016–2018, pre-Broadcom acquisition). The shop was already running a
Salt master for provisioning handoff, so extending it to configuration
management kept the toolchain homogeneous — one master, one minion agent,
one templating language, for both provisioning and ongoing state.

**Target OS:** CentOS 7, matching the AMIs provisioned by `legacy-salt-cloud`.

**Scope:** Configuration management and orchestration of a small DevOps
tooling fleet — five purpose-built servers, each running as native services
managed directly by Salt states:

| Minion ID              | Role                                    | State module        |
|-------------------------|------------------------------------------|----------------------|
| `devops-gitlab-01`      | Source control (GitLab CE)               | `source_control`     |
| `devops-nexus-01`       | Artifact repository (Nexus)              | `artifact_repo`      |
| `devops-ldap-01`        | Directory services (OpenLDAP)            | `directory_services` |
| `devops-gitlabrunner-01`| CI/CD (GitLab Runner, Docker executor)   | `cicd_runner`        |
| `devops-monitor-01`     | Monitoring (Nagios Core)                 | `monitoring`         |

---

## Architecture overview

```
srv/salt (base environment)
├── top.sls                          ← maps minion ID → state module
├── pillar/
│   ├── top.sls                      ← maps minion ID → pillar module
│   ├── source_control/init.sls
│   ├── artifact_repo/init.sls
│   ├── directory_services/init.sls
│   ├── cicd_runner/init.sls
│   └── monitoring/init.sls
├── source_control/
│   ├── init.sls
│   └── templates/gitlab.rb.jinja
├── artifact_repo/
│   ├── init.sls
│   └── templates/nexus.{rc,vmoptions,service}.jinja
├── directory_services/
│   ├── init.sls
│   └── templates/{db,base}.ldif.jinja
├── cicd_runner/
│   └── init.sls
└── monitoring/
    ├── init.sls
    └── templates/devops_hosts.cfg.jinja
```

`top.sls` and `pillar/top.sls` deliberately mirror each other: each minion
gets exactly one state module and the one pillar module that feeds it. There
is no shared "common" pillar bleeding config from one service into another —
GitLab's pillar never crosses into the LDAP minion's context and vice versa.
This one-module-per-minion targeting model was practical because each box in
this fleet does exactly one job.

---

## Native services, except CI/CD — and why

Four of the five servers run their software the way SaltStack was originally
designed to manage things: install a package (or unpack an archive), render
its config from pillar via Jinja, and keep a systemd service running,
restarting only when the rendered config changes. GitLab, Nexus, OpenLDAP,
and Nagios all follow this pattern.

The CI/CD host is the deliberate exception. `devops-gitlabrunner-01` runs
**GitLab Runner registered with the Docker executor** — meaning the runner
itself launches an ephemeral Docker container per CI/CD job rather than
executing jobs directly on the host. This is the standard, realistic GitLab
Runner architecture for isolated, reproducible job environments: each job
gets a clean container from a known base image, with no state leaking
between builds and no risk of one job's toolchain (a specific Node or Java
version, say) colliding with another's.

Salt's job here stops at the boundary of *what makes the Docker executor
possible*: it installs and enables the Docker daemon, installs GitLab Runner,
and performs the one-time non-interactive registration against the GitLab
instance (`cicd_runner/init.sls`). The ephemeral, per-job containers
themselves are created and destroyed by the runner at job execution time —
they are not, and should not be, Salt-managed resources. That boundary is
exactly what the Docker executor is for.

---

## File structure and design decisions

### `source_control/init.sls` — GitLab CE

Adds the GitLab Omnibus package repo, pins the package version from pillar,
renders `/etc/gitlab/gitlab.rb` from a Jinja template, and runs
`gitlab-ctl reconfigure` only `onchanges` to that file. Omnibus supervises
its own service stack (nginx, unicorn/puma, PostgreSQL, Redis, Sidekiq)
under runit, exposed to systemd as a single `gitlab-runsvdir` unit — Salt
only needs to manage that one unit, not each internal service.

### `artifact_repo/init.sls` — Nexus Repository Manager

Nexus 3.x ships as a tarball with no native systemd unit, so this state does
more manual assembly: a dedicated system user/group, tarball extraction to a
versioned directory under `/opt` with a stable symlink (so upgrades are a
version-string change, not a path change), heap and data-directory settings
rendered into `nexus.vmoptions`, and a Salt-authored systemd unit.

### `directory_services/init.sls` — OpenLDAP

Configures the default backend database's suffix and root DN via
`ldapmodify -Y EXTERNAL` over the local `ldapi://` socket — SASL EXTERNAL
authenticates using the connecting Unix user's peer credentials, so root can
administer `cn=config` without a bind password ever appearing in a state
file. A `creates` guard prevents re-running that one-time config change. The
base DIT (top entry, organizational units, admin group) is then loaded via
`ldapadd`, guarded by an `unless: ldapsearch` check so it only runs once.

### `monitoring/init.sls` — Nagios Core

Installs Nagios and its plugins from EPEL alongside the `httpd`/`php` web UI
stack, then generates one host definition and one NRPE-backed service
definition per check for every other minion in the fleet — driven entirely
by the `monitored_hosts` list in pillar, with hosts referenced by hostname
(resolved via internal DNS) rather than a hardcoded IP. The Nagios service
`watch`es the generated config file, so it only restarts when the fleet
topology or check list actually changes.

### `cicd_runner/init.sls` — Docker + GitLab Runner

See [Native services, except CI/CD](#native-services-except-cicd--and-why)
above. Installs Docker from its official repo, installs GitLab Runner from
its official repo, adds the runner's service user to the `docker` group
(via `optional_groups`, so it doesn't clobber other group membership the
package may have set), and registers the runner non-interactively with
`--executor docker`, driven entirely by pillar (GitLab URL, registration
token, default image, tags). Because GitLab Runner's own registration
command isn't idempotent on its own, this state's registration step is
guarded by checking whether the GitLab URL is already present in
`config.toml` — a workaround for a known gap rather than a built-in
GitLab Runner feature.

---

## How this took over from salt-cloud

Once `legacy-salt-cloud`'s bootstrap script installed the Salt minion,
injected its pre-generated key pair, and the minion checked in against the
master, provisioning's job was done. From that point forward, this state
tree took over: the master saw a newly-checked-in minion matching one of the
IDs in `top.sls`, applied the matching state module, and the box converged
from a bare CentOS 7 instance into a running GitLab server, Nexus instance,
LDAP directory, monitoring stack, or CI/CD runner — entirely driven by the
minion ID assigned at provisioning time. No manual configuration step
existed between "instance exists" and "service is running and configured."

---

## Common operational commands

```bash
# Apply state to a single minion
salt 'devops-gitlab-01' state.apply

# Apply state to the whole fleet
salt '*' state.apply

# Dry run — show what would change without applying it
salt 'devops-nexus-01' state.apply test=True

# Show which minions match which top.sls entries
salt-run state.show_top

# Refresh pillar data after an edit, before the next apply
salt '*' saltutil.refresh_pillar

# Target by role instead of minion ID (if grains were set accordingly)
salt -G 'role:monitoring' state.apply
```

---

## What this system did not manage

By design, this state tree only manages the software running on top of
already-provisioned instances. The following are out of scope and covered
elsewhere (or not covered in this portfolio at all):

- EC2 instance provisioning, networking, and IAM — `legacy-salt-cloud`
- The Salt master's own configuration. This same master doubled as both
  the salt-cloud provisioning master (see `legacy-salt-cloud` in the
  companion repo) and the configuration management master for this
  five-server fleet. A separate, independent Salt master ran in a
  different VPC managing a larger application environment entirely —
  out of scope for this repo. A second master for this specific
  environment was discussed as the fleet grew, but was never
  implemented; it wasn't warranted at this scale.
- TLS certificate issuance (states reference certificate paths but do not
  generate or rotate certificates)
- The ephemeral, per-job Docker containers GitLab Runner creates at CI/CD
  execution time
