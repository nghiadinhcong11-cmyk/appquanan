#!/bin/bash

# Exit on error
set -e

echo "Building Flutter Web..."
cd restaurant_app
flutter build web --release --dart-define=API_BASE_URL=https://appquanan.onrender.com

echo "Copying Flutter build to backend/public..."
cd ..
rm -rf backend/public
mkdir -p backend/public
cp -r restaurant_app/build/web/* backend/public/

echo "Build complete!"
