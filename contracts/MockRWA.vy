# pragma version ^0.4.0
"""
@title MockRWA
@notice Minimal contract to simulate RWA token execution in tests
"""
@external
def transfer(_to: address, _value: uint256) -> bool:
    return True