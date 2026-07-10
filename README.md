# Platform Config Evolution

![SaltStack](https://img.shields.io/badge/SaltStack-2D4A6E?style=flat&logo=saltproject&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![License: MIT](https://img.shields.io/badge/License-MIT-green?style=flat)

A portfolio repository documenting the evolution of platform configuration
management and orchestration across two distinct eras of tooling — from
SaltStack-based configuration management of native services on EC2 instances
in the mid-2010s, to a modern containerized rebuild on Kubernetes.

This repo is a companion to
[`ec2-provisioning-evolution`](https://github.com/christianvv/ec2-provisioning-evolution)
(same DevOps tooling environment, focused on *how instances got provisioned*).
This repo picks up where provisioning leaves off: *how those instances were
configured and kept in the desired state* once they existed.

---

## Repository structure

```
platform-config-evolution/
├── LICENSE
├── legacy-saltstack/               ← Part 1
│   ├── README.md
│   ├── top.sls
│   ├── pillar/
│   │   ├── top.sls
│   │   ├── source_control/
│   │   ├── artifact_repo/
│   │   ├── directory_services/
│   │   ├── cicd_runner/
│   │   └── monitoring/
│   ├── source_control/             # GitLab (native)
│   ├── artifact_repo/              # Nexus Repository Manager (native)
│   ├── directory_services/         # LDAP (native)
│   ├── cicd_runner/                # Docker + GitLab Runner (Docker executor)
│   └── monitoring/                 # Nagios Core (native)
└── modern-kubernetes/               ← Part 2 (coming soon)
```

---

## Skills Demonstrated

### Legacy (SaltStack era)

- Standard Salt state tree + pillar structure, with `top.sls` and
  `pillar/top.sls` mirroring each other to scope each minion to exactly the
  state module and pillar data its own role needs
- Native (non-containerized) service management driven by pillar-parameterized
  Jinja templates, with `watch`/`onchanges` restarts instead of unconditional
  service bounces
- Idempotent one-time operations (LDAP DIT loading, CI/CD runner
  registration) guarded by `unless`/`creates` rather than re-run on every
  apply
- A deliberate architecture boundary between Salt-managed infrastructure
  (the Docker daemon, GitLab Runner itself) and runner-managed, ephemeral
  per-job containers — using containerization for job isolation without
  making the whole fleet container-native

### Modern (Kubernetes era) — coming soon

---

## Part 1 — Legacy: SaltStack (circa 2016–2018)

Located in [`legacy-saltstack/`](legacy-saltstack/).

A recreation of the SaltStack configuration management system originally
architected and built for a small DevOps tooling fleet — source control,
artifact repository, directory services, monitoring, and a dedicated GitLab
Runner host for CI/CD — running as native services on CentOS 7 EC2 instances.

See [`legacy-saltstack/README.md`](legacy-saltstack/README.md) for the full
design walkthrough.

---

## Part 2 — Modern: Kubernetes (coming soon)

A future rebuild of the same tool suite as containerized Kubernetes
workloads — first as raw manifests, then refactored into a Helm chart.
Not started yet.

---

## Repository notes

All configuration values in this repository are illustrative. No real
hostnames, IP addresses, credentials, or internal program identifiers are
included. This is a demonstration of architecture and design, rebuilt
generically from memory and design knowledge — not a copy of production code.

---

## License

Licensed under MIT — see [LICENSE](LICENSE).
