# Vulnerability Scanning: Docker Scout and Trivy

Use both to cover advisory sources and gating in CI.

## Docker Scout (quick CVE view)
```bash
docker login
docker scout cves $DOCKERHUB_USERNAME/app:latest
```

## Trivy (gate builds)
```bash
trivy image $DOCKERHUB_USERNAME/app:latest --exit-code 1 --severity HIGH,CRITICAL
```

## Policy Gates (Scout)
```bash
docker scout quickview --policy default $DOCKERHUB_USERNAME/app:latest
```

## CI Recommendation
- Run Trivy to fail builds on HIGH/CRITICAL
- Run Scout for insights + remediation suggestions
- Re-scan daily or on schedule for new CVEs
