#!/bin/bash

# Create required directories
echo "Creating directories..."
mkdir -p ceremonyclient/node
cd ceremonyclient/node

# Download latest node and client
cat > download.sh << 'EOF'
#!/bin/bash

# Determine OS type and architecture
if [[ "$OSTYPE" == "linux-gnu"* ]]; then
    release_os="linux"
    if [[ $(uname -m) == "aarch64" ]]; then
        release_arch="arm64"
    else
        release_arch="amd64"
    fi
else
    release_os="darwin"
    release_arch="arm64"
fi

# Function to download files if not present
download_files() {
    local file_list=$1
    for file in $file_list; do
        version=$(echo "$file" | cut -d '-' -f 2)
        if [[ ! -f "./$file" ]]; then
            echo "Downloading $file..."
            curl -o "$file" "https://releases.quilibrium.com/$file"
        fi
    done
}

# Fetch and process release files
release_files=$(curl -s https://releases.quilibrium.com/release | grep "$release_os-$release_arch")
download_files "$release_files"

# Fetch and process qclient-release files
qclient_files=$(curl -s https://releases.quilibrium.com/qclient-release | grep "$release_os-$release_arch")
download_files "$qclient_files"
EOF

chmod +x download.sh
./download.sh

# Set permissions for node binary
echo "Setting permissions for node binary..."
# Find all node binaries and sort by version
node_binaries=$(ls -v node-*-linux-* 2>/dev/null)
if [ -n "$node_binaries" ]; then
    echo "Found node binaries:"
    echo "$node_binaries"
    
    # Get the latest version
    latest_binary=$(echo "$node_binaries" | tail -n 1)
    echo "Latest version is: $latest_binary"
    
    # Set permissions for all binaries, but highlight the latest
    for binary in $node_binaries; do
        chmod +x "$binary"
        if [ "$binary" = "$latest_binary" ]; then
            echo "Set executable permissions for $binary (latest)"
        else
            echo "Set executable permissions for $binary (previous version)"
        fi
    done
else
    echo "No node binary found!"
fi

# Create .config directory
mkdir -p .config

# Ask about keys.yml creation
read -p "Would you like to create keys.yml? (yes/no): " create_keys

if [[ "${create_keys,,}" == "yes" ]]; then
    echo "Please enter the content for keys.yml (Press Ctrl+D when finished):"
    cat > .config/keys.yml
    echo "keys.yml created successfully."
fi

# Create para.sh
echo "Creating para.sh..."
cat > para.sh << 'EOF'
#!/bin/bash
DIR_PATH=$( cd "$(dirname "${BASH_SOURCE[0]}")" ; pwd -P )

os=$1
architecture=$2
startingCore=$3
maxCores=$4
pid=$$
version=$5
crashed=0

start_process() {
  pkill node-*
  if [ $startingCore == 0 ]
  then
    $DIR_PATH/node-$version-$os-$architecture &
    pid=$!
    if [ $crashed == 0 ]
    then
      maxCores=$(expr $maxCores - 1)
    fi
  fi

  echo Node parent ID: $pid;
  echo Max Cores: $maxCores;
  echo Starting Core: $startingCore;

  for i in $(seq 1 $maxCores)
  do
    echo Deploying: $(expr $startingCore + $i) data worker with params: --core=$(expr $startingCore + $i) --parent-process=$pid;
    $DIR_PATH/node-$version-$os-$architecture --core=$(expr $startingCore + $i) --parent-process=$pid &
  done
}

is_process_running() {
    ps -p $pid > /dev/null 2>&1
    return $?
}

start_process

while true
do
  if ! is_process_running; then
    echo "Process crashed or stopped. restarting..."
    crashed=$(expr $crashed + 1)
    start_process
  fi
  sleep 440
done
EOF

# Set permissions for para.sh
chmod +x para.sh

echo "Setup completed! Please add config file and create para service."
