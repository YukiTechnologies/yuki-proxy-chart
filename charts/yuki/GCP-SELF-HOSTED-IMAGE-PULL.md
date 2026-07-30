# GCP self-hosted image pull (runbook)

Manual, per-customer `gcloud` grant for a self-hosted proxy on GCP to pull
`yuki-proxy` from our GAR. No app code, no Terraform (see YU-2385).

**Image:** `us-east1-docker.pkg.dev/yuki-infra-project/yuki-proxy-release/yuki-proxy`
(project `yuki-infra-project`, location `us-east1`, repo `yuki-proxy-release`).

`yuki-proxy-release` carries **semver tags only**. The `yuki-proxy` repo holds
every CI build (`pr-*`, `main-*`, bare SHAs) and is internal — never grant a
customer on it. Artifact Registry IAM is repo-level, so a grant there would
expose every unreleased build.

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
gcloud artifacts repositories add-iam-policy-binding yuki-proxy-release \
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
--set app.container.image=us-east1-docker.pkg.dev/yuki-infra-project/yuki-proxy-release/yuki-proxy:<tag>
```

or in their values file, `app.container.image: ...`.

Pin a **semver release tag** (e.g. `0.0.417`) — never `latest`. The release
repo carries nothing else, so any tag in it is safe to pin.

Non-GKE only: wire the customer's `dockerconfigjson` secret via the chart's
`imagePullSecrets` value (YU-2387). This is the fallback path — every cluster
we control pulls by node identity and sets no pull secret at all, so prefer
granting the node SA whenever the customer is on GKE.

## 4. Verify

Either the customer pulls/deploys successfully, or the operator confirms the
binding:

```
gcloud artifacts repositories get-iam-policy yuki-proxy-release \
  --location=us-east1 --project=yuki-infra-project
```

This IAM policy is the source of truth — no separate list is kept in app or Terraform.

## 5. Offboard

Same command with `remove-iam-policy-binding` instead of `add-iam-policy-binding`.

## Notes / known limits

- **Grant the right repo.** `roles/artifactregistry.reader` is repo-level —
  there is no per-tag ACL. Granting on `yuki-proxy` instead of
  `yuki-proxy-release` hands the customer every `pr-*` and unreleased `main-*`
  build, and lets them pin an unreviewed PR image in production. The two repo
  names differ by one suffix; check the command before running it.
- **Single-region (accepted):** GAR here is `us-east1` only (no cross-region
  replication like ECR). Cross-region pulls just take longer; pulls happen
  once per deploy. Open item, no work planned.
