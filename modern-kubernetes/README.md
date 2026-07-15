# Modern: Kubernetes (containerized rebuild)

A rebuild of the same DevOps tooling fleet from `legacy-saltstack/` as
containerized Kubernetes workloads — first as raw manifests (Phase A), then
refactored into a parameterized Helm chart (Phase B).

---

## Skills Demonstrated

- Namespace-based logical isolation (`devops-tools`) for the whole fleet
- Deployment + Service pairing with correct label selector matching
  (`matchLabels` / `template.labels`) on every workload
- NodePort Services for local-cluster external access, including a
  deliberate port remap (source-control: `servicePort` 80 → `containerPort`
  3000) alongside workloads where the two intentionally match
- Kubernetes Secrets for sensitive values (the LDAP admin password, the
  GitLab Runner registration token), created imperatively and never
  committed — referenced via `secretKeyRef`, distinct from plain `env`
  values
- Explicit `resources.requests`/`resources.limits` on every container to
  avoid noisy-neighbor resource contention
- Pinned, verified image tags throughout (no `latest`) — including catching
  a real-world case where `prom/prometheus:latest` does not resolve to the
  current major version
- Two-phase IaC-style evolution within this piece itself: raw manifests
  first, then refactored into a parameterized Helm chart — mirroring the
  module refactor pattern from the companion Terraform repo's
  bootstrap → networking → compute → modules progression
- Helm chart design: centralized `values.yaml`, Go templating (`.Values`
  references, string concatenation for image repository+tag, the `quote`
  function), verified via `helm template` before any cluster interaction
- Honest architectural scoping: an intentionally non-functional placeholder
  (`cicd-runner`) documented as such rather than hidden or faked

---

## Background and architecture

This directory represents the same five-tool fleet as the companion
[`ec2-provisioning-evolution`](https://github.com/christianvv/ec2-provisioning-evolution)
and `legacy-saltstack` pieces — source control, artifact repository,
directory services, CI/CD, and monitoring — now rebuilt as containerized
Kubernetes workloads instead of native services on long-lived EC2 instances.

The image mapping below is a deliberate choice, not a shortcut: every
workload runs a real, lightweight, genuinely representative equivalent of
its legacy counterpart, rather than a generic placeholder container. That's
the same "honest recreation" discipline used throughout this portfolio —
architecture and design decisions that hold up, not stand-ins that only
look right in a diagram.

This directory's two phases mirror each other the same way the companion
Terraform repo's bootstrap → networking → compute → modules progression
does: Phase A (`manifests/`) proves each workload functions as a flat set
of Kubernetes objects; Phase B (`helm/devops-tools/`) refactors those same
workloads into a reusable, parameterized chart, without changing what gets
deployed.

### Image mapping

| Original tool (legacy-saltstack) | Kubernetes workload | Image | Why this equivalent |
|---|---|---|---|
| GitLab (source control) | `source-control` | `gitea/gitea` | Real, lightweight Git server |
| Nexus (artifact repo) | `artifact-repo` | `registry` (Docker Registry) | Real, official, lightweight artifact registry |
| OpenLDAP (directory services) | `directory-services` | `osixia/openldap` | Real, widely-used lightweight OpenLDAP image |
| GitLab Runner (CI/CD) | `cicd-runner` | `gitlab/gitlab-runner` | The actual real GitLab Runner image |
| Nagios Core (monitoring) | `monitoring` | `prom/prometheus` | Deliberate architectural evolution, not just a smaller image — see below |

### Monitoring: why Prometheus, not a containerized Nagios

This one isn't a like-for-like swap. Nagios's model — a long-lived host
inventory, each host running an NRPE agent that a central poller reaches
out to individually — doesn't map cleanly onto ephemeral,
container-orchestrated workloads, where Pods are recreated, rescheduled,
and IP-reassigned routinely. Prometheus's pull-based,
service-discovery-driven model (scrape targets discovered dynamically
rather than a static host list) is the Kubernetes-native equivalent of
what Nagios was doing for the legacy fleet. This is a legitimate
architectural evolution point being made deliberately here, not a lazy
substitution because "it's the popular option."

### `cicd-runner`: a documented placeholder

The `cicd-runner` Deployment runs the real `gitlab/gitlab-runner` image,
with the environment variables and Secret wired up the way a real
registration would need (`CI_SERVER_URL`, `REGISTRATION_TOKEN` via
`secretKeyRef`). It does **not** actually register against `source-control`:

- Gitea doesn't speak GitLab's runner registration protocol.
- More fundamentally, the `gitlab-runner` image's default `run` command
  expects a `config.toml` that already exists — that file is only ever
  created by a separate, one-time `gitlab-runner register` command. This
  container only ever runs `run`, so it starts and stays up, but has no
  runner configuration to act on.

No Service exists for this workload, by design, in either phase — GitLab
Runner only makes outbound connections to the GitLab server it's
registered against; nothing needs to connect to it.

**How this would extend to a real GitLab instance** (conceptual, not
implemented here): a real deployment would add an `initContainer` that runs
`gitlab-runner register --non-interactive ...` once, writing the resulting
`config.toml` to a shared `emptyDir` volume mounted at
`/etc/gitlab-runner` in both the init container and the main container.
The main container's `run` command would then find a valid config already
in place when it starts. That's a natural next step for this piece, not
something this repo currently does.

---

## Kubernetes Secrets used

| Secret name | Key | Consumed by |
|---|---|---|
| `ldap-admin-secret` | `admin-password` | `directory-services` (`LDAP_ADMIN_PASSWORD`) |
| `gitlab-runner-secret` | `registration-token` | `cicd-runner` (`REGISTRATION_TOKEN`) |

Both Secrets are created imperatively via
`kubectl create secret generic ... --from-literal=...` and are never
committed to any file in this repo — not in `manifests/`, not in
`helm/devops-tools/`. `secrets.example.yaml` exists in both directories
purely as documentation of the expected structure, using `stringData` with
`REPLACE_ME` placeholder values. Neither file is meant to be applied
directly.

---

## Prerequisites

- Minikube (or another local Kubernetes cluster)
- kubectl
- Helm 3.x (for Phase B)

---

## Phase A: Raw manifests

```bash
minikube start

kubectl apply -f modern-kubernetes/manifests/namespace.yaml

kubectl create secret generic ldap-admin-secret \
  --namespace devops-tools \
  --from-literal=admin-password='your-password-here'

kubectl create secret generic gitlab-runner-secret \
  --namespace devops-tools \
  --from-literal=registration-token='your-token-here'

kubectl apply -f modern-kubernetes/manifests/

kubectl get pods,svc -n devops-tools
```

> **Note:** to actually reach a NodePort service from a browser on Minikube
> with the Docker driver on Windows, use
> `minikube service <name> -n devops-tools --url` — this creates a tunnel,
> and the terminal running it must stay open.

---

## Phase B: Helm chart

```bash
kubectl delete namespace devops-tools   # if Phase A resources still exist

cd modern-kubernetes/helm/devops-tools

helm template .    # verify rendering before installing

helm install devops-tools . -n devops-tools --create-namespace

kubectl create secret generic ldap-admin-secret \
  --namespace devops-tools \
  --from-literal=admin-password='your-password-here'

kubectl create secret generic gitlab-runner-secret \
  --namespace devops-tools \
  --from-literal=registration-token='your-token-here'

kubectl get pods,svc -n devops-tools

helm list -n devops-tools
```

---

## Project structure

```
modern-kubernetes/
├── README.md
├── manifests/                              ← Phase A
│   ├── namespace.yaml
│   ├── source-control-deployment.yaml      # Gitea
│   ├── source-control-service.yaml
│   ├── artifact-repo-deployment.yaml       # Docker Registry
│   ├── artifact-repo-service.yaml
│   ├── directory-services-deployment.yaml  # OpenLDAP
│   ├── directory-services-service.yaml
│   ├── cicd-runner-deployment.yaml         # GitLab Runner (no Service)
│   ├── monitoring-deployment.yaml          # Prometheus
│   ├── monitoring-service.yaml
│   └── secrets.example.yaml                # documentation only
└── helm/
    └── devops-tools/                       ← Phase B
        ├── Chart.yaml
        ├── values.yaml
        ├── .helmignore
        ├── secrets.example.yaml            # documentation only
        └── templates/
            ├── _helpers.tpl                # retained from helm-create scaffold
            ├── namespace.yaml
            ├── source-control-deployment.yaml
            ├── source-control-service.yaml
            ├── artifact-repo-deployment.yaml
            ├── artifact-repo-service.yaml
            ├── directory-services-deployment.yaml
            ├── directory-services-service.yaml
            ├── cicd-runner-deployment.yaml
            ├── monitoring-deployment.yaml
            └── monitoring-service.yaml
```

---

## Notes on sensitive data

No real credentials appear anywhere in the committed files. Both Secrets
are created imperatively and referenced by name only — `values.yaml` holds
`ldapAdminSecretName` and `gitlabRunnerSecretName`, the manifests reference
the same Secret names directly, and neither the Secret values nor any
token ever appear in a file that gets committed. The two
`secrets.example.yaml` files use obvious placeholder values (`REPLACE_ME`)
and exist solely to document the expected Secret shape for anyone cloning
this repo.
