pragma solidity >=0.5.0;

import '@uniswap/v2-core/contracts/interfaces/IUniswapV2Pair.sol';

import "./SafeMath.sol";

library UniswapV2Library {
    using SafeMath for uint;

    /**
     * @notice Sorts two tokens to ensure consistency in pair addresses.
     * @dev This function ensures that the token addresses are ordered to prevent duplication of pairs.
     * It returns the tokens in ascending order based on their addresses.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return token0 The address of the first sorted token.
     * @return token1 The address of the second sorted token.
     */
    function sortTokens(address tokenA, address tokenB) internal pure returns (address token0, address token1) {
        // Ensure that the two tokens are not identical
        require(tokenA != tokenB, 'UniswapV2Library: IDENTICAL_ADDRESSES');
        // Sort the tokens in ascending order based on their addresses
        (token0, token1) = tokenA < tokenB ? (tokenA, tokenB) : (tokenB, tokenA);
        // Ensure that the first token is not the zero address
        require(token0 != address(0), 'UniswapV2Library: ZERO_ADDRESS');
    }

    /**
     * @notice Computes the address of the pair contract without making any external calls.
     * @dev Utilizes the CREATE2 opcode formula to deterministically generate the pair address.
     * This allows anyone to predict pair addresses given the factory and token addresses.
     * @param factory The address of the UniswapV2 factory contract.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return pair The deterministic address of the pair contract.
     */
    function pairFor(address factory, address tokenA, address tokenB) internal pure returns (address pair) {
        // Sort the tokens to maintain consistency
        (address token0, address token1) = sortTokens(tokenA, tokenB);
        // Calculate the pair address using the CREATE2 opcode formula
        pair = address(uint(keccak256(abi.encodePacked(
                hex'ff', // Prefix for CREATE2
                factory, // Factory address
                keccak256(abi.encodePacked(token0, token1)), // Salt: hash of sorted tokens
                hex'96e8ac4277198ff8b6f785478aa9a39f403cb768dd02cbee326c3e7da348845f' // Init code hash
            ))));
    }

    /**
     * @notice Retrieves and sorts the reserves for a given token pair.
     * @dev Fetches the reserves from the pair contract and orders them based on the token sorting.
     * This ensures that reserveA corresponds to tokenA and reserveB corresponds to tokenB regardless of their order in the pair.
     * @param factory The address of the UniswapV2 factory contract.
     * @param tokenA The address of the first token.
     * @param tokenB The address of the second token.
     * @return reserveA The reserve amount of tokenA.
     * @return reserveB The reserve amount of tokenB.
     */
    function getReserves(address factory, address tokenA, address tokenB) internal view returns (uint reserveA, uint reserveB) {
        // Sort the tokens to match the pair's token order
        (address token0,) = sortTokens(tokenA, tokenB);
        // Retrieve the reserves from the pair contract
        (uint reserve0, uint reserve1,) = IUniswapV2Pair(pairFor(factory, tokenA, tokenB)).getReserves();
        // Assign reserves to the correct token based on sorting
        (reserveA, reserveB) = tokenA == token0 ? (reserve0, reserve1) : (reserve1, reserve0);
    }

    /**
     * @notice Calculates an equivalent amount of the other asset given some amount and pair reserves.
     * @dev This function provides a direct proportional calculation based on the reserves of both tokens in the pair.
     * It is used to determine how much of tokenB is equivalent to a specified amount of tokenA.
     * @param amountA The amount of tokenA.
     * @param reserveA The reserve of tokenA in the pair.
     * @param reserveB The reserve of tokenB in the pair.
     * @return amountB The equivalent amount of tokenB.
     */
    function quote(uint amountA, uint reserveA, uint reserveB) internal pure returns (uint amountB) {
        // Ensure the input amount is greater than zero
        require(amountA > 0, 'UniswapV2Library: INSUFFICIENT_AMOUNT');
        // Ensure reserves are greater than zero to avoid division by zero
        require(reserveA > 0 && reserveB > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        // Calculate the equivalent amount of tokenB
        amountB = amountA.mul(reserveB) / reserveA;
    }

    /**
     * @notice Determines the maximum output amount of the other asset given an input amount and pair reserves.
     * @dev Calculates the output amount factoring in the Uniswap fee. It ensures that the input amount is sufficient and liquidity is adequate.
     * @param amountIn The input amount of the asset.
     * @param reserveIn The reserve of the input asset.
     * @param reserveOut The reserve of the output asset.
     * @return amountOut The maximum possible output amount of the other asset.
     */
    function getAmountOut(uint amountIn, uint reserveIn, uint reserveOut) internal pure returns (uint amountOut) {
        // Ensure the input amount is greater than zero
        require(amountIn > 0, 'UniswapV2Library: INSUFFICIENT_INPUT_AMOUNT');
        // Ensure reserves are sufficient to perform the calculation
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        // Apply Uniswap fee to the input amount

        // this is the formula we are pertaining to
        // Same dy= dx(1-f)/x+ dx(1-f)




        // uniswap fees are 0.3%
        // x= reserveIn
        // y= reserveOut
        // dx= amountIn
        // dy = amountOut
   
        // dy= dx*997*x/1000(x+dx(997))



        // dy=amountin*997*reserveout / 1000(reserveIn+amountInwithcutfees))


        uint amountInWithFee = amountIn.mul(997);
        // Calculate the numerator for the output amount formula
        uint numerator = amountInWithFee.mul(reserveOut);
        // Calculate the denominator for the output amount formula
        uint denominator = reserveIn.mul(1000).add(amountInWithFee);
        // Determine the output amount by dividing numerator by denominator
        amountOut = numerator / denominator;
    }

    /**
     * @notice Calculates the required input amount of the other asset to achieve a specific output amount.
     * @dev Computes the necessary input amount considering the pair's reserves and Uniswap's fee structure.
     * It ensures that the output amount requested is feasible given the reserves.
     * @param amountOut The desired output amount of the asset.
     * @param reserveIn The reserve of the input asset.
     * @param reserveOut The reserve of the output asset.
     * @return amountIn The required input amount of the other asset.
     */
    function getAmountIn(uint amountOut, uint reserveIn, uint reserveOut) internal pure returns (uint amountIn) {
        // Ensure the desired output amount is greater than zero
        require(amountOut > 0, 'UniswapV2Library: INSUFFICIENT_OUTPUT_AMOUNT');
        // Ensure reserves are sufficient to perform the calculation
        require(reserveIn > 0 && reserveOut > 0, 'UniswapV2Library: INSUFFICIENT_LIQUIDITY');
        // Calculate the numerator for the input amount formula
        uint numerator = reserveIn.mul(amountOut).mul(1000);
        // Calculate the denominator for the input amount formula
        uint denominator = reserveOut.sub(amountOut).mul(997);
        // Determine the input amount by dividing numerator by denominator and adding 1 to account for rounding
        amountIn = (numerator / denominator).add(1);
    }

    /**
     * @notice Executes chained getAmountOut calculations across multiple pairs.
     * @dev Iterates through the provided path of token addresses to determine the final output amounts.
     * This is useful for multi-hop trades where the output of one pair is the input to the next.
     * @param factory The address of the UniswapV2 factory contract.
     * @param amountIn The initial input amount.
     * @param path An array of token addresses representing the swap path.
     * @return amounts An array of output amounts for each step in the path.
     */
    
    function getAmountsOut(address factory, uint amountIn, address[] memory path) internal view returns (uint[] memory amounts) {

        // @note : This is the function that is called when we want to swap tokens
        // Ensure the path has at least two tokens
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        // Initialize the amounts array with the length of the path

        // in between the various paths, each entry will have what amount to swap to get the next token
        amounts = new uint[](path.length);
        // Set the first element of amounts to the input amount, no matter what
        amounts[0] = amountIn;
        // Iterate through each pair of tokens in the path
        for (uint i; i < path.length - 1; i++) {
            // Retrieve reserves for the current pair
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i], path[i + 1]);
            // Calculate the output amount for the current pair and assign it to the next index
            amounts[i + 1] = getAmountOut(amounts[i] // the amount of token to swap
            , reserveIn, // the reserve of the token to swap
             reserveOut); // the reserve of the token to get
        }
    }

    /**
     * @notice Executes chained getAmountIn calculations across multiple pairs.
     * @dev Works in reverse of getAmountsOut by determining the necessary input amount to achieve a specific output across multiple pairs.
     * This is essential for reverse calculations in complex swap routes.
     * @param factory The address of the UniswapV2 factory contract.
     * @param amountOut The desired final output amount.
     * @param path An array of token addresses representing the swap path.
     * @return amounts An array of required input amounts for each step in the path.
     */
    function getAmountsIn(address factory, uint amountOut, address[] memory path) internal view returns (uint[] memory amounts) {
        // Ensure the path has at least two tokens
        require(path.length >= 2, 'UniswapV2Library: INVALID_PATH');
        // Initialize the amounts array with the length of the path
        amounts = new uint[](path.length);
        // Set the last element of amounts to the desired output amount
        amounts[amounts.length - 1] = amountOut;
        // Iterate through each pair of tokens in the path in reverse order

        // 
        for (uint i = path.length - 1; i > 0; i--) {
            // Retrieve reserves for the current pair
            (uint reserveIn, uint reserveOut) = getReserves(factory, path[i - 1], path[i]);
            // Calculate the required input amount for the current pair and assign it to the previous index, sets the amount to swap to get the next token
            amounts[i - 1] = getAmountIn(amounts[i], reserveIn, reserveOut);
        }
    }
}
