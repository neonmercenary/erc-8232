import argparse
from ape import accounts, project, networks
from . import load_network_addresses, DEPLOYER, PASS

current_price = networks.provider.gas_price
priority_price = int(current_price * 1.2)


def main():
    # Load the deployer account with your account set up in your Ape configurations
    deployer = accounts.load(DEPLOYER)  
    deployer.set_autosign(True, passphrase=PASS)  # Enable auto-signing for transactions from this account
    print(f"Using deployer account: {deployer.address}")
     
    active_network = networks.active_provider.network.name

    _8004, usdc_address = load_network_addresses(active_network)   
    print(f"Deploying to {active_network}...")

    # Deploy the Agency contract
    agency = project.Proxy.deploy(
        sender=deployer 
        # N:B: Agency owner is the deployer for this test, but in production this could be a multisig, DAO address or
        # whatever XDR for cold storage you want to use
    )
    
    # Log the deployed addresses and deploy the 8232Factory 
    # contract with the Agency's address and other parameters
    print(f"Agency deployed at: {agency.address}")
    factory = project.Factory.deploy(
        agency.address,
        _8004,
        usdc_address,
        sender=deployer,
    )
    print(f"8232Factory deployed at: {factory.address}")



    

if __name__ == "__main__":
    main()