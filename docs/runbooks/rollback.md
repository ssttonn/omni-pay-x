# Playbook: Kubernetes Rollback

**Objective:** Safely revert a deployment in the EKS cluster if the new version causes issues.

## 1. Identify the Failing Deployment
If alarms go off or the health checks start failing shortly after a deployment to Production, first identify the current state of the application.

```bash
# Check the deployment status
kubectl get pods -n production
kubectl get events -n production --sort-by='.metadata.creationTimestamp' | tail -20
```

## 2. Review Helm History
Helm tracks every release and its revisions. We need to find the previously stable revision number.

```bash
# Example for payment-api
helm history payment-api -n production

# Output might look like:
# REVISION  UPDATED                   STATUS      CHART               APP VERSION  DESCRIPTION
# 1         Tue Jan 21 14:00:00 2025  superseded  payment-api-0.1.0   v1.0.0       Install complete
# 2         Thu Jan 23 20:00:00 2025  deployed    payment-api-0.1.0   v1.1.0       Upgrade complete
```

## 3. Execute the Rollback
Revert to the last known good state (e.g., Revision 1).

```bash
helm rollback payment-api 1 -n production
```

## 4. Verify Recovery
Ensure the pods return to a `Running` state and the API responds to health checks.

```bash
kubectl rollout status deployment/payment-api -n production
```
