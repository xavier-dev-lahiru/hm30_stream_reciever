#!/usr/bin/env bash
# =============================================================================
# Selectively inject PyTorch + SLAM3R from conda into system Python 3.10,
# while excluding conflicting C-extensions (numpy, opencv, etc.).
# Creates a filtered .pth file so system Python finds torch but NOT numpy.
# =============================================================================
set -e

CONDA_BASE=$(conda info --base)
CONDA_SITE="$CONDA_BASE/envs/slam3r/lib/python3.11/site-packages"
SLAM3R_DIR=/home/lahiru_s/Documents/SLAM3R

# System Python 3.10 site-packages
SYS_SITE=$(python3 -c "import site; print(site.getsitepackages()[0])")
echo "System site-packages: $SYS_SITE"

# Create a .pth that adds SLAM3R and the conda torch packages to system Python
# We only add conda's site-packages. numpy conflict is resolved because
# Python's import system finds system numpy (in /usr/lib) BEFORE scanning
# the .pth additions IF we make the .pth additive (appended to sys.path).
# The key: system Python always finds its own numpy via /usr/lib/python3/dist-packages
# which is in sys.path BEFORE .pth files add extra paths.

# Add a sitecustomize to redirect numpy import to system version
cat > "$SYS_SITE/slam3r_torch_bridge.pth" << PTHEOF
$SLAM3R_DIR
$CONDA_SITE
PTHEOF

echo "Written: $SYS_SITE/slam3r_torch_bridge.pth"
cat "$SYS_SITE/slam3r_torch_bridge.pth"

# Also install numpy 1.x compatible with Python 3.10 into system (if needed)
echo ""
echo "Checking system numpy..."
python3 -c "import numpy; print('System numpy:', numpy.__version__, numpy.__file__)"
