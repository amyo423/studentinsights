# Deploy to all sites in parallel
# See https://github.com/studentinsights/studentinsights/pull/1856.
echo "🚢  Fetching from GitHub..."
git fetch origin

echo "🚢  Deploying..."
yarn concurrently \
  --names "demo,somerville,new-bedford" \
  -c "yellow.bold,blue.bold,magenta.bold" \
  'scripts/deploy/deploy.sh demo' \
  'scripts/deploy/deploy.sh somerville' \
  'scripts/deploy/deploy.sh new-bedford'

echo "🚢  Done."