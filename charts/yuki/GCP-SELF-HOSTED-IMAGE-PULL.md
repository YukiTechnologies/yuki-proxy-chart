# GCP self-hosted image pull (runbook)

Manual, per-customer `gcloud` grant for a self-hosted proxy on GCP to pull
`yuki-proxy` from our GAR. This is the operator fallback — YU-2385 moves the
same grant into the app so onboarding does it from the UI.

**Image:** `us-east1-docker.pkg.dev/yuki-infra-project/yuki-proxy/yuki-proxy`
(project `yuki-infra-project`, location `us-east1`, repo `yuki-proxy`).

## 1. Ask the customer

- Are their nodes GKE? If so, which **node service account** does the node
  pool use? (Default: `<project-number>-compute@developer.gserviceaccount.com`,
  unless they've set a custom one.)
- If not GKE (or their nodes can't be granted directly): they create their own
  service account + key in **their** project, and a `kubernetes.io/dockerconfigjson`
  imagePullSecret from it. We never generate or hold their key — we only grant
  that service account read access.

Note: **image pulls are done by the kubelet using the node's credentials**,
not the pod's `serviceAccountName` / Workload Identity. Grant the node SA (or
the customer's own SA for the imagePullSecret case), not a Kubernetes-side
identity.

## 2. Grant

```
gcloud artifacts repositories add-iam-policy-binding yuki-proxy \
  --location=us-east1 \
  --project=yuki-infra-project \
  --member=serviceAccount:<PRINCIPAL> \
  --role=roles/artifactregistry.reader
```

`<PRINCIPAL>` = the node SA (GKE) or the customer's own SA (non-GKE), from step 1.

## 3. Configure the chart

Set the full image reference (repo + tag together — there's no separate
`image.repository`/`image.tag` split):

```
--set app.container.image=us-east1-docker.pkg.dev/yuki-infra-project/yuki-proxy/yuki-proxy:<tag>
```

or in their values file, `app.container.image: ...`.

Pin a **semver release tag** (e.g. `0.0.417`) — never `latest`. Other tags
exist (`<short-sha>`, `main-<short-sha>`, `pr-<n>-<sha>`) but aren't for
customer use.

Non-GKE case: wire the customer's `dockerconfigjson` secret via the chart's
`imagePullSecrets` value (see `values.yaml` — landing in YU-2387).

## 4. Verify

Either the customer pulls/deploys successfully, or the operator confirms the
binding:

```
gcloud artifacts repositories get-iam-policy yuki-proxy \
  --location=us-east1 --project=yuki-infra-project
```

This IAM policy is the source of truth — no separate list is kept in app or Terraform.

## 5. Offboard

Same command with `remove-iam-policy-binding` instead of `add-iam-policy-binding`.

## Notes / known limits

- **Risk (accepted):** `roles/artifactregistry.reader` on the repo grants read
  of every tag in it, including `pr-*` and unreleased `main-*` builds — all
  branches push to this one prod GAR repo. No fix planned; operator should be
  aware.
- **Single-region (accepted):** GAR here is `us-east1` only (no cross-region
  replication like ECR). Cross-region pulls just take longer; pulls happen
  once per deploy. Open item, no work planned.
