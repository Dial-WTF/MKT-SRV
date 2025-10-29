#!/bin/bash
set -e

# Rainbow colors
COLORS=(31 33 32 36 34 35)

rainbow_line() {
    local line="$1"
    local i=0
    local output=""
    for (( j=0; j<${#line}; j++ )); do
        char="${line:$j:1}"
        color=${COLORS[$i]}
        output+="\033[1;${color}m${char}\033[0m"
        ((i=(i+1)%${#COLORS[@]}))
    done
    echo -e "$output"
}

# Get script dir and project root
SCRIPT_DIR="$( cd "$( dirname "${BASH_SOURCE[0]}" )" && pwd )"
PROJECT_ROOT="$SCRIPT_DIR/.."
INVENTORY_FILE="$PROJECT_ROOT/inventories/production/hosts.yml"

# Check fzf
if ! command -v fzf >/dev/null 2>&1; then
  echo "ERROR: 'fzf' required (brew install fzf or apt install fzf)."
  exit 1
fi

# Check yq
if ! command -v yq >/dev/null 2>&1; then
  echo "ERROR: 'yq' required (brew install yq or apt install yq)."
  exit 1
fi

# Colors
GREEN='\033[0;32m'
BANNER_COLOR='\033[1;33m' # Bold Yellow (gold)
TAGLINE_COLOR='\033[1;37m' # Bold White
NC='\033[0m'

# Print banner
echo ""
echo -e "${BANNER_COLOR}   .dMMMb  dMP dMP dMMMMMP dMP     dMP       .aMMMb  .aMMMb  dMMMMb  dMMMMb ${NC}"
echo -e "${BANNER_COLOR}  dMP\" VP dMP dMP dMP     dMP     dMP       dMP\"VMP dMP\"dMP dMP.dMP dMP.dMP ${NC}"
echo -e "${BANNER_COLOR}  VMMMb  dMMMMMP dMMMP   dMP     dMP       dMP     dMP dMP dMMMMK\" dMMMMP\"  ${NC}"
echo -e "${BANNER_COLOR}dP .dMP dMP dMP dMP     dMP     dMP       dMP.aMP dMP.aMP dMP\"AMF dMP       ${NC}"
echo -e "${BANNER_COLOR}VMMMP\" dMP dMP dMMMMMP dMMMMMP dMMMMMP    VMMMP\"  VMMMP\" dMP dMP dMP        ${NC}"
echo ""
echo -e "${TAGLINE_COLOR}                         Super SSH Selector                           ${NC}"
echo "----------------------------------------------------------------------"
echo ""


# Extract IPs
IPS=$(yq '.all.children.superagi_servers.hosts | keys | .[]' "$INVENTORY_FILE")
if [ -z "$IPS" ]; then
  echo "No servers found!"
  exit 1
fi

# Prepare menu
MENU_ITEMS=()
CURRENT_TIME=$(date +%s)

for SERVER_IP in $IPS; do
    KEY_PATH=$(yq -r ".all.children.superagi_servers.hosts.\"$SERVER_IP\".ansible_ssh_private_key_file" "$INVENTORY_FILE" | xargs)
    BASENAME=$(basename "$KEY_PATH")
    if [[ "$BASENAME" =~ superagi-auto-([0-9]+) ]]; then
        TIMESTAMP="${BASENAME#superagi-auto-}"
        AGE_SECONDS=$((CURRENT_TIME - TIMESTAMP))
        if [ "$AGE_SECONDS" -lt 60 ]; then
            AGE_STR="1 minute ago"
        elif [ "$AGE_SECONDS" -lt 3600 ]; then
            MINUTES=$((AGE_SECONDS / 60))
            AGE_STR="$MINUTES minutes ago"
        elif [ "$AGE_SECONDS" -lt 86400 ]; then
            HOURS=$((AGE_SECONDS / 3600))
            AGE_STR="$HOURS hours ago"
        else
            DAYS=$((AGE_SECONDS / 86400))
            if [ "$DAYS" -eq 1 ]; then
                AGE_STR="1 day ago"
            else
                AGE_STR="$DAYS days ago"
            fi
        fi
    else
        AGE_STR="unknown age"
    fi
    MENU_ITEMS+=("$SERVER_IP (${GREEN}$AGE_STR${NC})")
done

# Show menu
SELECTED_LINE=$(printf "%b\n" "${MENU_ITEMS[@]}" | fzf --ansi --prompt="Select server: " --height=10 --border)
if [ -z "$SELECTED_LINE" ]; then
  echo "No server selected, exiting."
  exit 0
fi

# Connect
SELECTED_IP=$(echo "$SELECTED_LINE" | awk '{print $1}')
KEY_PATH=$(yq -r ".all.children.superagi_servers.hosts.\"$SELECTED_IP\".ansible_ssh_private_key_file" "$INVENTORY_FILE" | xargs)


companyos_loader() {
    local duration=5  # total duration
    local interval=1  # one line per second
    local steps=4     # number of progress lines

    # Get terminal width dynamically
    local term_width=$(tput cols)
    local inner_width=$((term_width - 2))
    local bar_size=$((inner_width - 20))  # progress bar size inside Loading line
    local filled_size=0

    # Lines to show one by one
    local -a progress_lines=(
        "Initializing system components..."
        "Loading drivers..."
        "Checking hardware..."
        "Starting services..."
    )

    # Colors
    BOLD='\033[1m'
    GREEN='\033[0;32m'
    CYAN='\033[0;36m'
    NC='\033[0m' # No Color

    printf "\033[2J\033[H"  # Clear screen

    for ((i=0; i<steps; i++)); do
        filled_size=$(( ((i+1) * bar_size) / steps ))
        empty_size=$(( bar_size - filled_size ))

        printf "\033[H"  # Move cursor to top

        # Top border
        printf "${CYAN}+%${inner_width}s+${NC}\n" | tr ' ' '-'

        # Empty line (full width)
        printf "| %-${inner_width}s |\n" ""

        # Title line → print color outside padding
        printf "|  "
        printf "${BOLD}${GREEN}Company0S Boot Loader${NC}"
        printf "%$((inner_width - 2 - 2 - 24))s |\n" ""

        # Empty line (aligned with content lines — THIS IS THE FIX)
        printf "|  %-$((inner_width - 2))s |\n" ""

        # Progress lines so far
        for ((j=0; j<=i; j++)); do
            printf "|  %-$((inner_width - 2))s |\n" "${progress_lines[$j]}"
        done

        # Remaining empty lines (aligned)
        for ((j=i+1; j<steps; j++)); do
            printf "|  %-$((inner_width - 2))s |\n" ""
        done

        # Empty line (aligned)
        printf "|  %-$((inner_width - 2))s |\n" ""

        # Progress bar
        printf "|  Loading: ["
        printf "%0.s=" $(seq 1 $filled_size)
        printf "%0.s " $(seq 1 $empty_size)
        printf "]%$((inner_width - bar_size - 12))s |\n" ""

        # Empty line (aligned)
        printf "|  %-$((inner_width - 2))s |\n" ""

        # Bottom border
        printf "${CYAN}+%${inner_width}s+${NC}\n" | tr ' ' '-'

        sleep $interval
    done

    printf "\033[2J\033[H"  # Clear screen after done
}








# After selection
echo ""
companyos_loader 5


echo "==> Connecting to $SELECTED_IP with key $KEY_PATH ..."
ssh -t -i "$PROJECT_ROOT/$KEY_PATH" root@"$SELECTED_IP" " \
GREEN='\033[0;32m'; CYAN='\033[0;36m'; BOLD='\033[1m'; NC='\033[0m'; \
clear; \
printf \"\${CYAN}==============================================================================================\${NC}\n\"; \
printf \" \${GREEN}🚀 Company0S Server Terminal\${NC}                      \${BOLD}📛 Hostname:\${NC} \$(hostname)\n\"; \
printf \"\${CYAN}==============================================================================================\${NC}\n\"; \
printf \" 🕑 Uptime: $AGE_STR                      📊 Load: \$(awk '{print \$1, \$2, \$3}' /proc/loadavg)\n\"; \
printf \" 💾 Memory: \$(free -h | grep Mem | awk '{print \$3 \"/\" \$2}')                              🗄️ Disk: \$(df -h / | awk 'NR==2{print \$3 \"/\" \$2}')\n\"; \
printf \" 🌐 IP: \$(hostname -I | awk '{print \$1}')\n\"; \
printf \"==============================================================================================\n\"; \
echo; \
exec bash"


