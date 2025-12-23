#!/bin/bash
# upload_with_check.sh

SERVER="your-insecure-server.com"
FILE_PATH="yourfile.txt"
FILENAME=$(basename "$FILE_PATH")

# Generate hash for the file
FILE_HASH=$(md5sum "$FILE_PATH" | awk '{print $1}')
FILE_SIZE=$(stat -c%s "$FILE_PATH")

echo "Checking if $FILENAME already exists on server..."

# Method 1: Check by filename
echo "Method 1: Checking by filename..."
if curl -k -s -f -I "$SERVER/uploads/$FILENAME" >/dev/null 2>&1; then
    echo "❌ File with same name already exists!"
    exit 1
fi

# Method 2: Check by hash (if API supports it)
echo "Method 2: Checking by hash..."
RESPONSE=$(curl -k -s "$SERVER/api/check?hash=$FILE_HASH")
if echo "$RESPONSE" | grep -q '"exists":true'; then
    EXISTING_URL=$(echo "$RESPONSE" | grep -o '"url":"[^"]*"' | cut -d'"' -f4)
    echo "✅ File already exists at: $EXISTING_URL"
    echo "Skipping upload..."
    exit 0
fi

# Method 3: Upload with conditional headers
echo "Method 3: Uploading with duplicate check..."
curl -k -v -F "file=@$FILE_PATH" \
     -H "X-File-Hash: $FILE_HASH" \
     -H "X-File-Size: $FILE_SIZE" \
     "$SERVER/upload" > response.json

echo "Upload completed!"
