# cross-chain rebase token

1. A protocol that allows users to deposit into a vault and receive a rebase token in return that 
   represents the underlying deposit balance.

2. Rebase token with the balanceOf function being dynamic, to show changing balance with time.
   - Balance increases linerly with time.
   - mint tokens to our users every time they perform an action (minting, burning, bridging, transferring etc..)

3. interest rate:
   - individually set an interest rate for each user based on some global interest rate of the protocol at the time the user deposits into the valult.
   - this global interest rate can only decrease to incentivise early adopters.  
