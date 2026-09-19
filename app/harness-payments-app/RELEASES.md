# harness-payments-app — Release History

| Version | Branch       | Highlights |
|---------|--------------|------------|
| v1.0.0 | release/1.0.0 | Async payment mode|ConfigMap: MODE async, SETTLEMENT_BATCH 5... |
| v1.1.0 | release/1.1.0 | Async payment mode|ConfigMap: MODE async, SETTLEMENT_BATCH 5... |
| v1.2.0 | release/1.2.0 | Async payment mode|ConfigMap: MODE async, SETTLEMENT_BATCH 5... |

Rollback policy: every release is an atomic bundle (image tag + ConfigMap +
Secret at the same git tag). Roll back by applying the previous git tag.
