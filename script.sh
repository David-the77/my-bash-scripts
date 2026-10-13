#!/bin/bash

# ==========================================
# 1. SETUP & CONFIGURATION
# ==========================================
# Define colors for the report output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color



# Print Report Header
 echo "  LINUX BASELINE SECURITY COMPLIANCE REPORT"
echo " Date: $(date)"


# 2. SERVICE CHECKS

echo -e "\n${YELLOW}[+] Checking Critical Services...${NC}"

check_service() {
  local service=$1
  if systemctl is-active --quiet "$service"; then
    echo -e "  ${GREEN}[PASS]${NC} $service is active and running."
  else
    echo -e "  ${RED}[FAIL]${NC} $service is inactive or not installed."
  fi
}

check_service ssh
check_service ufw


# FILE PERMISSION CHECKS

echo -e "\n${YELLOW}[+] Checking for World-Writable Files...${NC}"

check_writable() {
  local dir=$1

  # Find files writable by 'others', ignoring permission denied errors
  local bad_files=$(find "$dir" -type f -perm -o+w 2>/dev/null)
  
  if [ -z "$bad_files" ]; then
    echo -e "  ${GREEN}[PASS]${NC} No world-writable files found in $dir."
  else
    echo -e "  ${RED}[FAIL]${NC} World-writable files found in $dir:"
    echo "$bad_files" | while read -r file; do echo "         -> $file"; done
  fi
}

check_writable /etc
check_writable /var


#user Privilage checks

echo -e "\n${YELLOW}[+] Checking for Rogue Root Users (UID 0)...${NC}"

# Extract usernames where the 3rd column (UID) is exactly 0
uid_zero_users=$(awk -F: '($3 == 0) {print $1}' /etc/passwd)

if [ "$uid_zero_users" == "root" ]; then
  echo -e "  ${GREEN}[PASS]${NC} Only the 'root' user has UID 0."
else
  echo -e "  ${RED}[FAIL]${NC} Non-root users found with UID 0:"
  echo "$uid_zero_users" | while read -r user; do echo "         -> $user"; done
fi


#SSH confirmation checks
echo -e "\n${YELLOW}[+] Checking SSH Hardening...${NC}"

# Look for the exact setting at the start of a line (ignoring comments)
ssh_pass_auth=$(grep -i "^PasswordAuthentication" /etc/ssh/sshd_config | tail -n 1)

if echo "$ssh_pass_auth" | grep -qi "no"; then
  echo -e "  ${GREEN}[PASS]${NC} SSH Password Authentication is disabled."
else
  echo -e "  ${RED}[FAIL]${NC} SSH Password Authentication is enabled or misconfigured."
  echo "         Current setting: $ssh_pass_auth"
fi

echo "  REPORT COMPLETE"
