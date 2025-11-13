# CRITICAL: Scanner Duplicate PR Bug

**Date**: 2025-11-13
**Severity**: CRITICAL
**Component**: burzmali-self-mod-auto-scan
**Impact**: 122+ duplicate PRs created, repo spam

## Problem

The autonomous scanner's deduplication logic is completely broken, causing it to create identical PRs every 5 minutes for the same file.

## Root Cause

`auto_scan.rs:198` - `check_duplicate_proposal()` function compares:
- **Trigger path**: Absolute path (e.g., `/home/burzmali/burzmali/rust-core/burzmali-circuit-breaker/src/lib.rs`)
- **Database `files_changed`**: Relative path (e.g., `rust-core/burzmali-circuit-breaker/src/lib.rs`)

The SQL query:
```sql
WHERE $1 = ANY(files_changed)
```

This NEVER matches because absolute != relative, so deduplication fails every time.

## Evidence

```bash
$ gh pr list --state open --limit 20
122 [Burzmali] Replace .unwrap()... 2025-11-13T09:00:55Z
121 [Burzmali] Replace .unwrap()... 2025-11-13T08:58:40Z
120 [Burzmali] Replace .unwrap()... 2025-11-13T08:53:39Z
...
```

All PRs:
- Same title: "Replace .unwrap() with proper error handling in lib.rs"
- Same file: `rust-core/burzmali-circuit-breaker/src/lib.rs`
- Created every 5 minutes (systemd timer interval)
- Started at proposal #777, currently at #796+

## Fix Required

In `auto_scan.rs:198`, normalize the trigger path before comparison:

```rust
async fn check_duplicate_proposal(&self, trigger: &crate::ImprovementTrigger) -> Result<Option<i32>> {
    // ADD THIS: Normalize path to relative format
    let relative_path = crate::templates::to_relative_path(&trigger.file_path);

    let client = self.db.get_client().await?;

    let rows = client
        .query(
            "SELECT id, status, created_at
             FROM proposals
             WHERE $1 = ANY(files_changed)  -- Now compares relative to relative
             AND status IN ('pending', 'awaiting_approval', 'revised', 'rejected')
             ORDER BY created_at DESC
             LIMIT 1",
            &[&relative_path],  // CHANGE: Use normalized path
        )
        .await?;
    // ... rest unchanged
}
```

## Remediation Steps

1. ✅ Stop scanner timer (`systemctl stop burzmali-self-mod-scanner.timer`)
2. ⏳ Close all 122 duplicate PRs
3. ⏳ Fix `auto_scan.rs` deduplication logic
4. ⏳ Rebuild and deploy fixed binary
5. ⏳ Restart scanner with fixed code

## Lessons Learned

- Path normalization is critical for deduplication
- Need integration tests that verify deduplication works
- Should log when deduplication triggers to catch this earlier
- Consider rate limiting (max 1 PR per hour per file as failsafe)
