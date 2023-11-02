import json
import boto3
import os
import urllib3


def lambda_handler(event, context):
    client = boto3.client("ec2")
    response = client.describe_vpn_connections(Filters=[{"Name": "state", "Values": ["pending", "available"]}])

    account_alias = (boto3.client("iam").list_account_aliases()).get("AccountAliases","NoEnvInfo")
    if len(account_alias) > 0:
        account_alias = account_alias[0]
        account_alias_formatter = account_alias.split("-")
        if account_alias_formatter[0] == "lifemote":
            del account_alias_formatter[0]
            account_alias = "-".join(account_alias_formatter)
    else:
        account_alias = " "

    if len(response["VpnConnections"]) < 1:
        vpn_info = "Could not retrieve Vpn connection info."
        send_slack_notification(account_alias, vpn_info)
        return

    s2s_vpn_states = response["VpnConnections"][0]["VgwTelemetry"]
    tunnel_1 = s2s_vpn_states[0].get("Status", "NotFound")
    tunnel_2 = s2s_vpn_states[1].get("Status", "NotFound")

    if tunnel_1 == "UP" and tunnel_2 == "UP":
        vpn_info = "Both VPN tunnels are UP"
    elif (tunnel_1 == "DOWN" and tunnel_2 == "UP") or (tunnel_1 == "UP" and tunnel_2 == "DOWN"):
        vpn_info = "One of VPN tunnels is down."
    elif tunnel_1 == "DOWN" and tunnel_2 == "DOWN":
        vpn_info = "Both VPN tunnels are down. Tunnels will be replaced."

        try:
            VpnConnId = response["VpnConnections"][0]["VpnConnectionId"]
            OutsideIpAddress_1 = s2s_vpn_states[0].get("OutsideIpAddress", "NotFound")
            OutsideIpAddress_2 = s2s_vpn_states[1].get("OutsideIpAddress", "NotFound")

            replace_vpn_1 = client.replace_vpn_tunnel(
                VpnConnectionId=VpnConnId,
                VpnTunnelOutsideIpAddress=OutsideIpAddress_1
            )
            print(f"Response for replacing tunnel 1: {replace_vpn_1}")

            replace_vpn_2 = client.replace_vpn_tunnel(
                VpnConnectionId=VpnConnId,
                VpnTunnelOutsideIpAddress=OutsideIpAddress_2
            )
            print(f"Response for replacing tunnel 2: {replace_vpn_2}")
        except Exception as e:
            vpn_info = "Could not replace tunnels. Check logs for exception."
            send_slack_notification(account_alias, vpn_info)
            raise e
    else:
        vpn_info = "Could not retrieve tunnel state info. Check logs for exception."

    send_slack_notification(account_alias, vpn_info)


def send_slack_notification(account_alias, vpn_info):
    data = {
        "blocks": [
            {
                "type": "header",
                "text": {
                    "type": "plain_text",
                    "text": f"{account_alias}",
                },
            },
            {
                "type": "section",
                "text": {
                    "type": "mrkdwn",
                    "text": f"{vpn_info}",
                },
            },
        ]
    }

    http = urllib3.PoolManager()
    r = http.request(
        "POST",
        os.getenv("SLACK_WEBHOOK_URL"),
        body=json.dumps(data),
        headers={"Content-Type": "application/json"},
        retries=False,
    )

    print(r.read())
