#!/usr/bin/env python3
"""
Scans all S3 buckets in the account, reports which lack lifecycle policies,
and optionally applies a default tiering policy. Designed for DSSE compliance
audits where every bucket must have documented retention rules.
"""
import argparse
import json
import sys
from datetime import datetime

import boto3
from botocore.exceptions import ClientError


DEFAULT_LIFECYCLE_POLICY = {
    "Rules": [
        {
            "ID": "default-tiering",
            "Status": "Enabled",
            "Filter": {"Prefix": ""},
            "Transitions": [
                {"Days": 30,  "StorageClass": "STANDARD_IA"},
                {"Days": 90,  "StorageClass": "GLACIER"},
                {"Days": 365, "StorageClass": "DEEP_ARCHIVE"},
            ],
            "Expiration": {"Days": 2555},
            "NoncurrentVersionExpiration": {"NoncurrentDays": 90},
        }
    ]
}


def get_s3_client(endpoint_url: str | None = None) -> boto3.client:
    kwargs = {}
    if endpoint_url:
        kwargs["endpoint_url"] = endpoint_url
    return boto3.client("s3", **kwargs)


def list_buckets(s3) -> list[str]:
    return [b["Name"] for b in s3.list_buckets().get("Buckets", [])]


def get_lifecycle(s3, bucket: str) -> dict | None:
    try:
        return s3.get_bucket_lifecycle_configuration(Bucket=bucket)
    except ClientError as e:
        if e.response["Error"]["Code"] == "NoSuchLifecycleConfiguration":
            return None
        raise


def get_bucket_size_gb(s3, bucket: str) -> float:
    """Approximate bucket size from object listing — not exact but avoids CloudWatch dependency."""
    total = 0
    paginator = s3.get_paginator("list_objects_v2")
    for page in paginator.paginate(Bucket=bucket):
        for obj in page.get("Contents", []):
            total += obj.get("Size", 0)
    return round(total / (1024 ** 3), 2)


def apply_default_policy(s3, bucket: str, dry_run: bool) -> None:
    if dry_run:
        print(f"  [DRY RUN] Would apply default lifecycle policy to {bucket}")
        return
    s3.put_bucket_lifecycle_configuration(
        Bucket=bucket,
        LifecycleConfiguration=DEFAULT_LIFECYCLE_POLICY,
    )
    print(f"  Applied default lifecycle policy to {bucket}")


def audit(endpoint_url: str | None, apply: bool, dry_run: bool, output_json: bool) -> None:
    s3 = get_s3_client(endpoint_url)
    buckets = list_buckets(s3)
    results = []
    no_policy = []

    print(f"Scanning {len(buckets)} buckets...\n")

    for bucket in buckets:
        lifecycle = get_lifecycle(s3, bucket)
        has_policy = lifecycle is not None and len(lifecycle.get("Rules", [])) > 0

        entry = {
            "bucket": bucket,
            "has_lifecycle_policy": has_policy,
            "rule_count": len(lifecycle.get("Rules", [])) if lifecycle else 0,
            "scanned_at": datetime.utcnow().isoformat(),
        }

        if not has_policy:
            no_policy.append(bucket)
            if apply or dry_run:
                apply_default_policy(s3, bucket, dry_run)

        results.append(entry)

    if output_json:
        print(json.dumps(results, indent=2))
    else:
        print(f"{'Bucket':<50} {'Has Policy':<12} {'Rules'}")
        print("-" * 70)
        for r in results:
            status = "YES" if r["has_lifecycle_policy"] else "NO  <-- MISSING"
            print(f"{r['bucket']:<50} {status:<12} {r['rule_count']}")

        print(f"\nSummary: {len(no_policy)}/{len(buckets)} buckets missing lifecycle policies")
        if no_policy:
            print("\nBuckets without policies:")
            for b in no_policy:
                print(f"  - {b}")


def main() -> None:
    parser = argparse.ArgumentParser(description="S3 lifecycle policy audit and remediation")
    parser.add_argument("--endpoint-url", help="Override AWS endpoint (e.g. http://localhost:4566 for LocalStack)")
    parser.add_argument("--apply", action="store_true", help="Apply default lifecycle policy to non-compliant buckets")
    parser.add_argument("--dry-run", action="store_true", help="Show what would be applied without making changes")
    parser.add_argument("--json", dest="output_json", action="store_true", help="Output results as JSON")
    args = parser.parse_args()

    if args.apply and args.dry_run:
        print("ERROR: --apply and --dry-run are mutually exclusive", file=sys.stderr)
        sys.exit(1)

    audit(args.endpoint_url, args.apply, args.dry_run, args.output_json)


if __name__ == "__main__":
    main()
