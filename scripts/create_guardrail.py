#!/usr/bin/env python3
"""
Utility to create a Bedrock Guardrail with sensible defaults for the PoC.

Usage:
    python scripts/create_guardrail.py --name poc-mc-vision-guardrail --region ap-northeast-1
"""

import argparse
import json
import sys
import time
from typing import List

import boto3
from botocore.exceptions import BotoCoreError, ClientError


def build_topic_config() -> List[dict]:
    base_topics = [
        ("Violence", "Requests that glorify or encourage violence against people or property."),
        ("HateSpeech", "Prompts that insult or attack individuals or groups."),
        ("AdultContent", "Sexually explicit or adult themed descriptions."),
    ]
    topics = []
    for name, definition in base_topics:
        topics.append(
            {
                "name": name,
                "definition": definition,
                "type": "DENY",
                "examples": [f"Example of {name} content"],
                "inputAction": "BLOCK",
                "outputAction": "BLOCK",
                "inputEnabled": True,
                "outputEnabled": True,
            }
        )
    return topics


def main():
    parser = argparse.ArgumentParser(description="Create a Bedrock guardrail with default policies.")
    parser.add_argument("--name", required=True, help="Guardrail name")
    parser.add_argument("--description", default="MC Vision default guardrail", help="Guardrail description")
    parser.add_argument("--region", default="ap-northeast-1", help="AWS region for Bedrock control plane")
    parser.add_argument("--pii-action", default="BLOCK", choices=["BLOCK", "ANONYMIZE"], help="PII detection action")
    args = parser.parse_args()

    client = boto3.client("bedrock", region_name=args.region)

    payload = {
        "name": args.name,
        "description": args.description,
        "topicPolicyConfig": {"topicsConfig": build_topic_config()},
        "contentPolicyConfig": {
            "filtersConfig": [
                {"type": "HATE", "inputStrength": "MEDIUM", "outputStrength": "MEDIUM"},
                {"type": "VIOLENCE", "inputStrength": "MEDIUM", "outputStrength": "MEDIUM"},
                {"type": "SEXUAL", "inputStrength": "MEDIUM", "outputStrength": "MEDIUM"},
                {"type": "INSULTS", "inputStrength": "MEDIUM", "outputStrength": "MEDIUM"},
            ]
        },
        "sensitiveInformationPolicyConfig": {
            "piiEntitiesConfig": [
                {
                    "type": pii,
                    "action": args.pii_action,
                    "inputAction": args.pii_action,
                    "outputAction": args.pii_action,
                    "inputEnabled": True,
                    "outputEnabled": True,
                }
                for pii in ["NAME", "EMAIL", "PHONE", "US_SOCIAL_SECURITY_NUMBER"]
            ]
        },
        "wordPolicyConfig": {
            "managedWordListsConfig": [
                {
                    "type": "PROFANITY",
                    "inputAction": "BLOCK",
                    "outputAction": "BLOCK",
                    "inputEnabled": True,
                    "outputEnabled": True,
                }
            ]
        },
        "blockedInputMessaging": "ポリシー違反の入力が検出されました。",
        "blockedOutputsMessaging": "コンテンツがポリシーに抵触したため応答を省略しました。",
        "clientRequestToken": f"mc-vision-{int(time.time())}",
    }

    try:
        response = client.create_guardrail(**payload)
    except (BotoCoreError, ClientError) as exc:
        print(f"[ERROR] Failed to create guardrail: {exc}", file=sys.stderr)
        sys.exit(1)

    print("Guardrail created successfully.")
    print(f"Guardrail ARN: {response.get('guardrailArn')}")
    print(f"\nCopy the following values into configs/.env and Terraform variables:")
    print(f"  BEDROCK_GUARDRAIL_ID={response.get('guardrailId')}")
    print(f"  BEDROCK_GUARDRAIL_VERSION={response.get('version')}")


if __name__ == "__main__":
    main()
