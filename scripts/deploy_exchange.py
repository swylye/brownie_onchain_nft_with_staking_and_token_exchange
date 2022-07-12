from brownie import RewardTokenExchange, config, network
from scripts.helpful_scripts import get_account
import time


def main():
    exchange, account = deploy_new_contract(
        "0x3C3D9913bE72f56249Aa87840B5cF9Ba79dDa74a"
    )
    # exchange, account = deploy_contract("0x3C3D9913bE72f56249Aa87840B5cF9Ba79dDa74a")


def deploy_contract(token_contract_address):
    account = get_account()
    if len(RewardTokenExchange) > 0:
        exchange = RewardTokenExchange[-1]
    else:
        exchange = RewardTokenExchange.deploy(
            token_contract_address,
            {"from": account},
            publish_source=True,
        )
    return exchange, account


def deploy_new_contract(token_contract_address):
    account = get_account()
    exchange = RewardTokenExchange.deploy(
        token_contract_address,
        {"from": account},
        publish_source=True,
    )
    return exchange, account
