from brownie import SVGNFT, accounts, config, network, exceptions, convert
from web3 import Web3
from scripts.deploy_nft import deploy_contract
from scripts.helpful_scripts import LOCAL_BLOCKCHAIN_ENVIRONMENTS, get_account
import pytest
import eth_abi
import time


def test_can_mint():
    svg_nft, account = deploy_contract()
    token_counter = svg_nft.tokenCounter()
    tx = svg_nft.create({"from": account})
    tx.wait(3)
    time.sleep(60)
    tx2 = svg_nft.completeMint(token_counter, {"from": account})
    tx2.wait(1)
    new_token_counter = svg_nft.tokenCounter()
    assert new_token_counter > token_counter
    assert svg_nft.ownerOf(token_counter) == account
    assert len(svg_nft.tokenURI) > 0
