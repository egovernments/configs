#!/bin/bash

# Reindex TL Collection Data via Kafka Topic
# This triggers dashboard-ingest to re-enrich collection records with domain objects

set -e

# Configuration
ES_HOST="${ES_HOST:-localhost:9200}"
KAFKA_BROKER="${KAFKA_BROKER:-kafka:9092}"
REINDEX_TOPIC="dss-collection-reindex"
BATCH_SIZE=100

echo "======================================"
echo "TL Collection Reindexing via Kafka"
echo "======================================"
echo "Elasticsearch: $ES_HOST"
echo "Kafka Broker: $KAFKA_BROKER"
echo "Reindex Topic: $REINDEX_TOPIC"
echo "Batch Size: $BATCH_SIZE"
echo ""

# Function to fetch and republish TL collection records
reindex_tl_collections() {
    local index=$1

    echo "Processing index: $index"
    echo "----------------------------------------"

    # Check if index exists
    if ! curl -s -o /dev/null -w "%{http_code}" "http://${ES_HOST}/${index}" | grep -q "200"; then
        echo "⚠ Index $index does not exist, skipping..."
        return
    fi

    # Get total TL documents
    local total=$(curl -s -X GET "http://${ES_HOST}/${index}/_count" -H 'Content-Type: application/json' -d'
    {
      "query": {
        "term": {
          "dataObject.paymentDetails.businessService.keyword": "TL"
        }
      }
    }' | jq -r '.count')

    echo "Total TL documents: $total"

    if [ "$total" -eq "0" ]; then
        echo "⚠ No TL documents found"
        return
    fi

    # Scroll through all TL documents and republish to Kafka
    local scroll_id=""
    local processed=0

    # Initial scroll request
    local response=$(curl -s -X GET "http://${ES_HOST}/${index}/_search?scroll=5m" -H 'Content-Type: application/json' -d"{
      \"size\": ${BATCH_SIZE},
      \"query\": {
        \"term\": {
          \"dataObject.paymentDetails.businessService.keyword\": \"TL\"
        }
      }
    }")

    scroll_id=$(echo "$response" | jq -r '._scroll_id')
    local hits=$(echo "$response" | jq -r '.hits.hits | length')

    while [ "$hits" -gt 0 ]; do
        # Process current batch
        echo "$response" | jq -c '.hits.hits[]._source' | while read -r doc; do
            # Extract payment ID for Kafka key
            local payment_id=$(echo "$doc" | jq -r '.dataObject.id // .identifier')

            # Publish to Kafka reindex topic
            echo "$doc" | kafka-console-producer.sh \
                --broker-list "$KAFKA_BROKER" \
                --topic "$REINDEX_TOPIC" \
                --property "key.separator=|" \
                --property "parse.key=true" <<< "${payment_id}|${doc}"

            processed=$((processed + 1))

            if [ $((processed % 10)) -eq 0 ]; then
                echo -ne "\rProcessed: $processed / $total"
            fi
        done

        # Get next batch
        response=$(curl -s -X GET "http://${ES_HOST}/_search/scroll" -H 'Content-Type: application/json' -d"{
          \"scroll\": \"5m\",
          \"scroll_id\": \"${scroll_id}\"
        }")

        hits=$(echo "$response" | jq -r '.hits.hits | length')
    done

    # Clear scroll
    curl -s -X DELETE "http://${ES_HOST}/_search/scroll" -H 'Content-Type: application/json' -d"{
      \"scroll_id\": \"${scroll_id}\"
    }" > /dev/null

    echo -e "\n✓ Completed: $processed documents republished"
    echo ""
}

# Check dependencies
if ! command -v jq &> /dev/null; then
    echo "Error: jq is not installed. Please install jq first."
    exit 1
fi

if ! command -v kafka-console-producer.sh &> /dev/null; then
    echo "Error: kafka-console-producer.sh not found. Please ensure Kafka tools are in PATH."
    exit 1
fi

# Main execution
echo "Starting reindex process..."
echo ""

reindex_tl_collections "pg-egov-dss-ingest-enriched"
reindex_tl_collections "pg-dss-collection_v2"

echo ""
echo "======================================"
echo "Reindex complete!"
echo "======================================"
echo ""
echo "All TL collection records have been republished to Kafka topic: $REINDEX_TOPIC"
echo "The dashboard-ingest service will process them and re-enrich with domain objects."
echo ""
echo "Monitor the dashboard-ingest logs to see the progress."
echo ""
