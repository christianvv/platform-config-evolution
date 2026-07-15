# Platform Config Evolution

![SaltStack](https://img.shields.io/badge/SaltStack-2D4A6E?style=flat&logo=saltproject&logoColor=white)
![Kubernetes](https://img.shields.io/badge/Kubernetes-326CE5?style=flat&logo=kubernetes&logoColor=white)
![Helm](https://img.shields.io/badge/Helm-0F1689?style=flat&logo=helm&logoColor=white)
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
└── modern-kubernetes/               ← Part 2
    ├── README.md
    ├── manifests/                   # Phase A — raw manifests
    │   ├── namespace.yaml
    │   ├── source-control-{deployment,service}.yaml     # Gitea
    │   ├── artifact-repo-{deployment,service}.yaml       # Docker Registry
    │   ├── directory-services-{deployment,service}.yaml  # OpenLDAP
    │   ├── cicd-runner-deployment.yaml                   # GitLab Runner
    │   ├── monitoring-{deployment,service}.yaml          # Prometheus
    │   └── secrets.example.yaml
    └── helm/devops-tools/            # Phase B — Helm chart
        ├── Chart.yaml
        ├── values.yaml
        ├── secrets.example.yaml
        └── templates/
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

### Modern (Kubernetes era)

- Namespace-based logical isolation for the fleet, with Deployment + Service
  pairing and correct label selector matching (`matchLabels` /
  `template.labels`) on every workload
- NodePort Services for local-cluster access, including a deliberate port
  remap (source-control: `servicePort` 80 → `containerPort` 3000) alongside
  workloads where the two intentionally match
- Kubernetes Secrets for sensitive values (LDAP admin password, GitLab
  Runner registration token), created imperatively and never committed —
  referenced via `secretKeyRef`, distinct from plain `env` values
- Explicit `resources.requests`/`resources.limits` on every container, and
  pinned, verified image tags throughout (no `latest`)
- The same two-phase evolutionary pattern as the companion Terraform repo's
  module refactor: raw manifests first, then a parameterized Helm chart
  with centralized `values.yaml`, verified via `helm template` before any
  cluster interaction
- Honest architectural scoping — a deliberate Nagios-to-Prometheus
  evolution (not a like-for-like swap) and an intentionally non-functional
  CI/CD runner placeholder, documented as such rather than hidden or faked

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

## Part 2 — Modern: Kubernetes

Located in [`modern-kubernetes/`](modern-kubernetes/).

A rebuild of the same five-tool fleet as containerized Kubernetes
workloads, built in two phases: raw manifests first (`manifests/`), proving
each workload functions as a flat set of Kubernetes objects, then a
refactor into a parameterized Helm chart (`helm/devops-tools/`) — the same
evolutionary pattern as the companion Terraform repo's module refactor.
Each legacy tool maps to a real, lightweight, genuinely representative
Kubernetes-native equivalent (GitLab → Gitea, Nexus → Docker Registry,
OpenLDAP retained as OpenLDAP, GitLab Runner retained as GitLab Runner,
and Nagios → Prometheus as a deliberate architectural evolution rather
than a like-for-like swap). The CI/CD runner workload is an intentionally
non-functional placeholder — it runs the real GitLab Runner image but
doesn't register, and that scope boundary is documented rather than
hidden.

See [`modern-kubernetes/README.md`](modern-kubernetes/README.md) for the
full architecture walkthrough and usage guide for both phases.

---

## Repository notes

Both parts are now complete. `legacy-saltstack/` is a recreation of an
architecture originally designed and built circa 2016–2018, rebuilt
generically from memory and design knowledge — not a copy of production
code, and all configuration values (URLs, DNs, tokens, hashes) are
illustrative placeholders. `modern-kubernetes/` is an original
implementation built and tested end-to-end against a local cluster
(`helm template`, `helm install`, verified Pod/Service status). No real
hostnames, IP addresses, credentials, or internal program identifiers
appear anywhere in either part, and the two Kubernetes Secrets it depends
on are created imperatively and never committed to any file.

---

## License

Licensed under MIT — see [LICENSE](LICENSE).
