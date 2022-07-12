from brownie import SVGStaking, config, network
from scripts.helpful_scripts import get_account
import time


def main():
    svg_staking, account = deploy_new_contract(
        "0xb8EE7aC73B420c8894a2294B20eE4421B2529E27"
    )
    # svg_staking, account = deploy_contract("0xb8EE7aC73B420c8894a2294B20eE4421B2529E27")


def deploy_contract(nft_contract_address):
    account = get_account()
    if len(SVGStaking) > 0:
        svg_staking = SVGStaking[-1]
    else:
        svg_staking = SVGStaking.deploy(
            nft_contract_address,
            {"from": account},
            publish_source=True,
        )
    return svg_staking, account


def deploy_new_contract(nft_contract_address):
    account = get_account()
    svg_staking = SVGStaking.deploy(
        nft_contract_address,
        {"from": account},
        publish_source=True,
    )
    return svg_staking, account
