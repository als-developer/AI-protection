#!/bin/bash
set -euo pipefail

MESSAGE=${1:-"BioShield Alert"}
SEVERITY=${2:-warning}

SLACK_WEBHOOK="${SLACK_WEBHOOK_URL:-}"
PAGERDUTY_KEY="${PAGERDUTY_INTEGRATION_KEY:-}"

# Send to Slack
if [ -n "$SLACK_WEBHOOK" ]; then
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"text\":\"[$SEVERITY] $MESSAGE\"}" \
        "$SLACK_WEBHOOK" > /dev/null
fi

# Send to PagerDuty for critical alerts
if [ "$SEVERITY" = "critical" ] && [ -n "$PAGERDUTY_KEY" ]; then
    curl -s -X POST -H "Content-Type: application/json" \
        -d "{\"routing_key\":\"$PAGERDUTY_KEY\",\"event_action\":\"trigger\",\"payload\":{\"summary\":\"$MESSAGE\",\"severity\":\"critical\"}}" \
        "https://events.pagerduty.com/v2/enqueue" > /dev/null
fi

echo "Alert sent: [$SEVERITY] $MESSAGE"
