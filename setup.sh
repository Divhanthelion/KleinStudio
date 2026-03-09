#!/bin/bash

# Exit on any error
set -e

echo "Setting up KleinStudio Backend..."

# Move into the backend directory
cd backend

# Check for Python 3
if ! command -v python3 &> /dev/null
then
    echo "Python 3 could not be found. Please install Python 3 and try again."
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
