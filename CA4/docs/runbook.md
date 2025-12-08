# 🚨 CA4 Incident Runbook

## Failure Scenario: Kafka Broker Outage

> **Goal:** Simulate Kafka going down, see how the system fails, then bring it back using your existing Make targets.

---

## 1. Normal Baseline (Before Failure)

1. **Check core services:**

   ```bash
   make verify-kafka
   make verify-mongo
   ```
2. **Check end-to-end workflow:**

   ```bash
   make verify-workflow
   ```
3. **If using the local Processor path (Colab → ngrok → local → Kafka):**

   ```bash
   make run-local-processor
   ```

    * This:

        * Starts Kafka port-forward into the cluster
        * Starts ngrok
        * Runs the local FastAPI Processor

You should see everything “green” here before you inject failure.

---

## 2. Inject the Failure (Kafka Down)

> This is the “chaos” step you’ll show in the video.

Bring down the Kafka broker in the **platform** namespace:

```bash
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n platform delete pod kafka-0
```

(Your `make` already assumes `KUBECONFIGL = .kube/kubeconfig.yaml`, so this matches that.)

---

## 3. Detection Using Make Targets

Right after deleting the pod, re-run your checks.

### 3.1 Kafka health

```bash
make verify-kafka
```

Expected:

* `kafka-0` missing or in `ContainerCreating` / `CrashLoopBackOff`
* Recent logs may show connection/startup errors

### 3.2 Preflight and workflow

```bash
make verify-preflight
make verify-workflow
```

Expected:

* `verify-preflight` may hang or fail on `sts/kafka`
* `verify-workflow` will not reach “✅ Workflow verified end-to-end”

### 3.3 Processor/Worker symptoms

Use these as supporting signals:

```bash
make verify-processor
make verify-mongo
```

And from Colab or curl, try sending a request through the Processor.
Expected: 500s / timeouts because it can’t talk to Kafka.

These **Make commands are your “monitoring dashboard”** for the incident.

---

## 4. Recovery

### 4.1 Let the StatefulSet recreate Kafka

In most cases, the StatefulSet will auto-heal. To force a clean restart:

```bash
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n platform rollout restart statefulset/kafka
KUBECONFIG=.kube/kubeconfig.yaml kubectl -n platform rollout status statefulset/kafka --timeout=180s
```

> If you want a pure-Make wrapper later, we can add `restart-kafka:` as a thin shell over this, but this step is fine as raw `kubectl` in your runbook.

### 4.2 If you’re using local Processor + tunnel

Sometimes your local port-forward is stale after a disruption.

1. Stop anything old:

   ```bash
   make stop-local-processor
   ```
2. Start fresh:

   ```bash
   make run-local-processor
   ```

This re-establishes:

* Kafka port-forward to the cluster
* ngrok tunnel
* Local FastAPI Processor

---

## 5. Post-Recovery Verification (Using Make Commands)

Once Kafka has restarted:

1. **Verify Kafka itself:**

   ```bash
   make verify-kafka
   ```

2. **Check that all core pieces are healthy and rolled out:**

   ```bash
   make verify-preflight
   ```

3. **Verify end-to-end workflow:**

   ```bash
   make verify-workflow
   ```

4. **Optionally drill into specifics:**

   ```bash
   make verify-mongo
   make verify-processor
   make verify-producers
   ```

Then:

* Send a new request from Colab.
* Confirm:

    * Processor responds 2xx.
    * Worker consumes.
    * New document appears in `ca4.gpu_metadata` in DocumentDB (you may have a shell or script for this).



### Incident: Kafka Broker Outage

* **Detection (Make commands):**
    * `make verify-kafka`
    * `make verify-preflight`
    * `make verify-workflow`


* **Failure Injection:**
    * `kubectl -n platform delete pod kafka-0` (with `KUBECONFIG=.kube/kubeconfig.yaml`)


* **Impact Observed:**
    * `verify-kafka` shows missing/unready pod
    * `verify-preflight`/`verify-workflow` fail
    * Colab → Processor calls fail
  

* **Recovery:**
    * `kubectl -n platform rollout restart statefulset/kafka`
    * `kubectl -n platform rollout status statefulset/kafka`
    * `make stop-local-processor && make run-local-processor` (if using local path)
  

* **Post-Recovery Verification (Make):**
    * `make verify-kafka`
    * `make verify-preflight`
    * `make verify-workflow`
