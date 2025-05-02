#!/bin/bash

# Exit on error
set -e

# Default values
AUTO_APPROVE=true
SHOW_LOGS=true

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        --auto-approve)
            AUTO_APPROVE=true
            shift
            ;;
        --show-logs)
            SHOW_LOGS=true
            shift
            ;;
        *)
            echo "Unknown option: $1"
            echo "Usage: $0 [--auto-approve] [--show-logs]"
            exit 1
            ;;
    esac
done

# Function to show latest logs
show_latest_logs() {
    echo "📜 Showing latest logs..."
    aws logs get-log-events \
        --profile personal \
        --log-group-name "/aws/lambda/fastapi-hello-${STAGE:-dev}" \
        --log-stream-name $(aws logs describe-log-streams \
            --profile personal \
            --log-group-name "/aws/lambda/fastapi-hello-${STAGE:-dev}" \
            --order-by LastEventTime \
            --descending \
            --limit 1 \
            --query 'logStreams[0].logStreamName' \
            --output text) \
        --limit 20 \
        --output text
}

echo "🚀 Starting deployment process..."

# Check if temp_build directory exists, if not create it
if [ ! -d "./temp_build" ]; then
    echo "📁 Creating temp_build directory..."
    mkdir -p ./temp_build
fi

# Clean temp_build directory
echo "🧹 Cleaning temp_build directory..."
rm -rf ./temp_build/*

# Copy FastAPI app files
echo "📋 Copying FastAPI application files..."
cp -r ./fastapi_app/* ./temp_build/

# Install dependencies
echo "📦 Installing Python dependencies..."
pip install -r ./fastapi_app/requirements.txt -t ./temp_build/

# Check if the installation was successful
if [ $? -eq 0 ]; then
    echo "✅ Dependencies installed successfully"
else
    echo "❌ Failed to install dependencies"
    exit 1
fi

# Apply Terraform changes
echo "🔄 Applying Terraform changes..."
cd terraform
if [ "$AUTO_APPROVE" = true ]; then
    terraform apply -auto-approve
else
    terraform apply
fi

# Check if terraform apply was successful
if [ $? -eq 0 ]; then
    echo "✅ Deployment completed successfully!"
    echo "🌐 API URL: $(terraform output -raw api_url)"
    
    # Show logs if requested
    if [ "$SHOW_LOGS" = true ]; then
        show_latest_logs
    else
        echo -e "\nTo view logs, run: $0 --show-logs"
    fi
else
    echo "❌ Terraform apply failed"
    exit 1
fi 