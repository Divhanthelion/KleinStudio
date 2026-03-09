#!/bin/bash

# Exit on any error
set -e

echo "Setting up KleinStudio Backend..."

# Move into the backend directory
cd backend

# Check for Python 3
if ! command -v python3 &> /dev/null
then
    echo "Python 3 could not be found. Please install Python 3.10 or higher and try again."
    exit 1
fi

# Check Python version >= 3.10 (mflux 0.4.1 requires Python 3.10+)
if ! python3 -c 'import sys; sys.exit(0 if sys.version_info >= (3, 10) else 1)'; then
    echo "====================================================================="
    echo "❌ ERROR: Python 3.10 or higher is required!"
    echo "You are currently running an older version of Python 3."
    echo "Apple's MLX and mflux require Python 3.10+ to work correctly."
    echo "Please install a newer Python version (e.g., using Homebrew: 'brew install python@3.11')"
    echo "====================================================================="
    exit 1
fi

echo "Creating virtual environment (.venv)..."
python3 -m venv .venv

echo "Activating virtual environment..."
source .venv/bin/activate

echo "Installing requirements..."
pip install --upgrade pip
pip install -r requirements.txt

echo "Quantizing and caching FLUX.2 Klein 9B model (This will download ~49GB of weights initially)..."
echo "Make sure you have enough disk space and a stable internet connection!"
python quantize.py

echo "Setup complete! You can now run the app from the root directory using:"
echo "swift run"
