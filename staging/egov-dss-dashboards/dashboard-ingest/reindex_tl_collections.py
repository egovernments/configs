#!/usr/bin/env python3

"""
TL Collection Reindexing Script
Fetches TL payment records from collection service and republishes them to trigger DSS enrichment
"""

import requests
import json
import time
from datetime import datetime

# Configuration
CONFIG = {
    "es_host": "localhost:9200",
    "collection_service_url": "http://collection-services:8080/collection-services",
    "kafka_connect_url": "http://kafka-connect:8083",
    "tenant_id": "pg.citya",  # Update with your tenant
    "batch_size": 50
}

def get_es_tl_payment_ids(es_host, index_name):
    """Fetch all TL payment IDs from Elasticsearch"""
    print(f"\n📊 Fetching TL payment IDs from {index_name}...")

    url = f"http://{es_host}/{index_name}/_search"
    query = {
        "size": 10000,  # Max size for single request
        "_source": ["dataObject.id", "dataObject.paymentDetails.receiptNumber"],
        "query": {
            "term": {
                "dataObject.paymentDetails.businessService.keyword": "TL"
            }
        }
    }

    try:
        response = requests.post(url, json=query, timeout=30)
        response.raise_for_status()
        data = response.json()

        payment_ids = []
        for hit in data.get("hits", {}).get("hits", []):
            source = hit.get("_source", {})
            payment_id = source.get("dataObject", {}).get("id")
            receipt_number = source.get("dataObject", {}).get("paymentDetails", {}).get("receiptNumber")
            if payment_id:
                payment_ids.append({
                    "id": payment_id,
                    "receiptNumber": receipt_number
                })

        print(f"✓ Found {len(payment_ids)} TL payments")
        return payment_ids

    except Exception as e:
        print(f"✗ Error fetching from ES: {e}")
        return []

def fetch_and_republish_payment(collection_service_url, payment_id, receipt_number, tenant_id):
    """Fetch payment details from collection service"""
    url = f"{collection_service_url}/payments/_search"
    params = {
        "tenantId": tenant_id,
        "receiptNumbers": receipt_number
    }

    try:
        response = requests.post(url, json={"RequestInfo": {}}, params=params, timeout=10)
        response.raise_for_status()
        data = response.json()

        payments = data.get("Payments", [])
        if payments:
            return payments[0]
        else:
            return None

    except Exception as e:
        print(f"  ✗ Error fetching payment {receipt_number}: {e}")
        return None

def publish_to_kafka_topic(kafka_url, topic, payment_data):
    """Publish payment data to Kafka topic via Kafka Connect REST Proxy"""
    # Note: This is a placeholder - actual implementation depends on your Kafka setup
    # You may need to use kafka-python library or POST to a reindex API endpoint
    pass

def trigger_reindex_via_api(payment_data):
    """
    Trigger reindex by calling dashboard-ingest reindex API
    This is the recommended approach if dashboard-ingest exposes a reindex endpoint
    """
    # TODO: Update with actual dashboard-ingest reindex endpoint
    # reindex_url = "http://dashboard-ingest:8080/dashboard-ingest/v1/_reindex"
    # response = requests.post(reindex_url, json=payment_data)
    pass

def main():
    print("=" * 60)
    print("TL Collection Reindexing Script")
    print("=" * 60)
    print(f"Elasticsearch: {CONFIG['es_host']}")
    print(f"Tenant: {CONFIG['tenant_id']}")
    print(f"Batch Size: {CONFIG['batch_size']}")
    print()

    # Fetch TL payment IDs from both indices
    all_payment_ids = []

    for index in ["pg-egov-dss-ingest-enriched", "pg-dss-collection_v2"]:
        payment_ids = get_es_tl_payment_ids(CONFIG["es_host"], index)
        all_payment_ids.extend(payment_ids)

    # Remove duplicates
    unique_payments = {p["receiptNumber"]: p for p in all_payment_ids if p.get("receiptNumber")}
    total_payments = len(unique_payments)

    print(f"\n📝 Total unique TL payments to reindex: {total_payments}")
    print()

    if total_payments == 0:
        print("No payments to reindex. Exiting.")
        return

    # Ask for confirmation
    response = input(f"Proceed with reindexing {total_payments} TL payments? (yes/no): ")
    if response.lower() != 'yes':
        print("Reindexing cancelled.")
        return

    print("\n🔄 Starting reindex process...")
    print("-" * 60)

    processed = 0
    failed = 0

    for receipt_number, payment_info in unique_payments.items():
        processed += 1
        print(f"[{processed}/{total_payments}] Processing: {receipt_number}")

        # Fetch full payment data from collection service
        payment_data = fetch_and_republish_payment(
            CONFIG["collection_service_url"],
            payment_info["id"],
            receipt_number,
            CONFIG["tenant_id"]
        )

        if payment_data:
            # TODO: Implement actual republish logic based on your setup
            # Option 1: Publish to Kafka reindex topic
            # Option 2: Call dashboard-ingest reindex API
            # Option 3: Direct POST to collection service webhook

            print(f"  ✓ Payment fetched successfully")
        else:
            failed += 1
            print(f"  ✗ Failed to fetch payment")

        # Rate limiting
        if processed % CONFIG["batch_size"] == 0:
            print(f"\n⏸  Pausing for 2 seconds after batch of {CONFIG['batch_size']}...\n")
            time.sleep(2)

    print()
    print("=" * 60)
    print("Reindex Summary")
    print("=" * 60)
    print(f"Total: {total_payments}")
    print(f"Processed: {processed}")
    print(f"Failed: {failed}")
    print(f"Success: {processed - failed}")
    print()

    print("⚠  NOTE: This script fetches payment data but requires additional")
    print("   configuration to actually trigger reindexing.")
    print()
    print("   Next steps:")
    print("   1. Configure Kafka topic publishing OR")
    print("   2. Implement dashboard-ingest API call OR")
    print("   3. Use the simpler SQL-based reindex approach (see below)")
    print()

if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\n\n⚠ Reindexing interrupted by user")
    except Exception as e:
        print(f"\n\n✗ Unexpected error: {e}")
