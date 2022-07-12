from brownie import SVGNFT, config, network
from scripts.helpful_scripts import get_account
import time


def main():
    svg_nft, account = deploy_new_contract()
    # svg_nft, account = deploy_contract()
    # account2 = get_account(name="DEV02")
    # account3 = get_account(name="DEV03")
    # mint_nft(svg_nft, account)
    # mint_nft(svg_nft, account2)
    # mint_nft(svg_nft, account3)


def deploy_contract():
    account = get_account()
    if len(SVGNFT) > 0:
        svg_nft = SVGNFT[-1]
    else:
        svg_nft = SVGNFT.deploy(
            config["networks"][network.show_active()]["coordinator_sub_id"],
            config["networks"][network.show_active()]["vrf_coordinator"],
            {"from": account},
            publish_source=True,
        )
    return svg_nft, account


def deploy_new_contract():
    account = get_account()
    svg_nft = SVGNFT.deploy(
        config["networks"][network.show_active()]["coordinator_sub_id"],
        config["networks"][network.show_active()]["vrf_coordinator"],
        {"from": account},
        publish_source=True,
    )
    return svg_nft, account


def mint_nft(nft_contract, account):
    token_counter = nft_contract.tokenCounter()
    tx = nft_contract.create({"from": account})
    tx.wait(2)
    time.sleep(90)
    tx2 = nft_contract.completeMint(token_counter, {"from": account})
    tx2.wait(1)
