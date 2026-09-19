# harness-store-app — Release History

| Version | Branch       | Highlights |
|---------|--------------|------------|
| v1.0.0 | release/1.0.0 | ML recommendations feature flag|ConfigMap: DB_HOST -> db-pro... |
| v1.1.0 | release/1.1.0 | ML recommendations feature flag|ConfigMap: DB_HOST -> db-pro... |
| v1.2.0 | release/1.2.0 | ML recommendations feature flag|ConfigMap: DB_HOST -> db-pro... |

Rollback policy: every release is an atomic bundle (image tag + ConfigMap +
Secret at the same git tag). Roll back by applying the previous git tag.
