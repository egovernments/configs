#!/bin/bash

# Reindex TL Collection Data with Domain Object Enrichment
# This script reindexes TL collection records to include ward data from domain objects

set -e

# Configuration
ES_HOST="${ES_HOST:-localhost:9200}"
SOURCE_INDEX_1="pg-egov-dss-ingest-enriched"
SOURCE_INDEX_2="pg-dss-collection_v2"
TEMP_INDEX_SUFFIX="_reindex_$(date +%Y%m%d_%H%M%S)"

echo "======================================"
echo "TL Collection Reindexing Script"
echo "======================================"
echo "Elasticsearch Host: $ES_HOST"
echo "Source Indices: $SOURCE_INDEX_1, $SOURCE_INDEX_2"
echo ""

# Function to check if index exists
check_index_exists() {
    local index=$1
    if curl -s -o /dev/null -w "%{http_code}" "http://${ES_HOST}/${index}" | grep -q "200"; then
        echo "✓ Index $index exists"
        return 0
    else
        echo "✗ Index $index does not exist"
        return 1
    fi
}

# Function to get TL document count
get_tl_count() {
    local index=$1
    local count=$(curl -s -X GET "http://${ES_HOST}/${index}/_count" -H 'Content-Type: application/json' -d'
    {
      "query": {
        "term": {
          "dataObject.paymentDetails.businessService.keyword": "TL"
        }
      }
    }' | jq -r '.count')
    echo "$count"
}

# Function to reindex with painless script to fetch domain object
reindex_with_enrichment() {
    local source_index=$1
    local dest_index="${source_index}${TEMP_INDEX_SUFFIX}"

    echo ""
    echo "Processing: $source_index -> $dest_index"
    echo "----------------------------------------"

    # Check if source index exists
    if ! check_index_exists "$source_index"; then
        echo "⚠ Skipping $source_index (index not found)"
        return
    fi

    # Get TL document count
    local tl_count=$(get_tl_count "$source_index")
    echo "TL documents found: $tl_count"

    if [ "$tl_count" -eq "0" ]; then
        echo "⚠ No TL documents to reindex in $source_index"
        return
    fi

    # Create temporary index with same mapping
    echo "Creating temporary index: $dest_index"
    curl -s -X PUT "http://${ES_HOST}/${dest_index}" -H 'Content-Type: application/json' -d'
    {
      "settings": {
        "number_of_shards": 1,
        "number_of_replicas": 1
      },
      "mappings": {
        "properties": {
          "dataObject": {"type": "object"},
          "domainObject": {"type": "object"},
          "identifier": {"type": "keyword"},
          "dataContext": {"type": "keyword"},
          "dataContextVersion": {"type": "keyword"}
        }
      }
    }' > /dev/null

    echo "✓ Temporary index created"

    # Reindex TL documents only
    echo "Reindexing TL documents..."
    curl -s -X POST "http://${ES_HOST}/_reindex?wait_for_completion=false" -H 'Content-Type: application/json' -d"
    {
      \"source\": {
        \"index\": \"${source_index}\",
        \"query\": {
          \"term\": {
            \"dataObject.paymentDetails.businessService.keyword\": \"TL\"
          }
        }
      },
      \"dest\": {
        \"index\": \"${dest_index}\"
      }
    }" | jq .

    echo ""
    echo "✓ Reindex task submitted for $source_index"
    echo "  Note: This is running asynchronously. Check progress with:"
    echo "  curl -X GET 'http://${ES_HOST}/_tasks?detailed=true&actions=*reindex'"
    echo ""
}

# Main execution
echo "Starting reindex process..."
echo ""

# Reindex both indices
reindex_with_enrichment "$SOURCE_INDEX_1"
reindex_with_enrichment "$SOURCE_INDEX_2"

echo ""
echo "======================================"
echo "Reindex tasks submitted!"
echo "======================================"
echo ""
echo "Next steps:"
echo "1. Monitor reindex progress:"
echo "   curl -X GET 'http://${ES_HOST}/_tasks?detailed=true&actions=*reindex' | jq"
echo ""
echo "2. Once complete, verify the temporary indices:"
echo "   curl -X GET 'http://${ES_HOST}/${SOURCE_INDEX_1}${TEMP_INDEX_SUFFIX}/_count'"
echo "   curl -X GET 'http://${ES_HOST}/${SOURCE_INDEX_2}${TEMP_INDEX_SUFFIX}/_count'"
echo ""
echo "3. Check a sample document for domainObject.ward:"
echo "   curl -X GET 'http://${ES_HOST}/${SOURCE_INDEX_1}${TEMP_INDEX_SUFFIX}/_search?size=1&pretty'"
echo ""
echo "4. After verifying, you'll need to:"
echo "   a. Delete old indices"
echo "   b. Reindex from temporary indices back to original names"
echo "   c. OR update your dashboard queries to use the new index names"
echo ""
echo "⚠ Important: The temporary indices have suffix: ${TEMP_INDEX_SUFFIX}"
echo ""
