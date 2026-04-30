import os
from dotenv import load_dotenv

load_dotenv()


def load_network_addresses(network_name):
    if "ethereum" in network_name or "sepolia" in network_name or "goerli" in network_name:
        return os.getenv("8004_ETH"), os.getenv("USDC_ETH")
    elif "avalanche" in network_name:
        return os.getenv("8004_AVAX"), os.getenv("USDC_AVAX")
    else:
        raise ValueError(f"Unsupported network: {network_name}")


FACTORY = os.getenv("FACTORY")
AGENCY = os.getenv("AGENCY")
DEPLOYER = os.getenv("DEPLOYER_ACCOUNT")
PASS = os.getenv("DEPLOYER_PASSPHRASE")