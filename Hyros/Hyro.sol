//SPDX-License-Identifier: UNLICENSED
pragma solidity =0.8.15;

import './libraries/Math.sol';
import './hyroERC20.sol';
import './libraries/UQ112x112.sol';
import './interfaces/IERC20.sol';
import './interfaces/IHyroFactory.sol';
import './interfaces/IHyroCallee.sol';
import './interfaces/IRouterV2.sol';

contract Hyro is HyroERC20 {
    using SafeMath  for uint;
    using UQ112x112 for uint224;
    address private constant ZERO_ADDRESS = 0x0000000000000000000000000000000000000000;
    uint public constant MINIMUM_LIQUIDITY = 10**3;
    bytes4 private constant SELECTOR = bytes4(keccak256(bytes('transfer(address,uint256)')));
    bytes4 private constant FROMSELECTOR = bytes4(keccak256(bytes('transferFrom(address,address,uint256)')));
    uint256 private constant MAX_UINT = 0xffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffffff;
    address private UNISWAP_ROUTER = 0x6ae0B2c523183C8490dd18A4E05696119a2fE99d;
 
    address public factory;
    address public hyro;
    address[] private tokens;
    mapping(address => uint256) private reserves;

    uint32  private blockTimestampLast;

    uint private unlocked = 1;
    modifier lock() {
        require(unlocked == 1, 'Hyro: LOCKED');
        unlocked = 0;
        _;
        unlocked = 1;
    }

    

    function updateTokens() public {
        tokens = IHyroFactory(factory).getWhitelistedTokens();
    }

    function _safeTransfer(address token, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(SELECTOR, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Hyro: TRANSFER_FAILED');
    }

    function _safeTransferFrom(address token, address from, address to, uint value) private {
        (bool success, bytes memory data) = token.call(abi.encodeWithSelector(FROMSELECTOR, from, to, value));
        require(success && (data.length == 0 || abi.decode(data, (bool))), 'Hyro: TRANSFER_FROM_FAILED');
    }

    event Mint(address indexed sender, uint liquidity, uint amountDeposit);
    event Burn(address indexed sender, uint amountWithdraw);
    event Swap(
        uint amountIn,
        uint amountOut,
        address tokenIn,
        address tokenOut
        
    );
    event Sync(uint256 reserve0, uint256 reserve1);

    constructor() {
        factory = msg.sender;
    }

    function initialize(address _hyro) external {
        require(msg.sender == factory, 'Hyro: FORBIDDEN');
        hyro = _hyro;
        updateTokens();
    }

    function whitelisted(address _token) public view returns (bool) {
        for (uint256 i; i < tokens.length; i++) {
            if (tokens[i] == _token)
                return true;
        }
        return false;
    }

    function getReserves(address token) public view returns (uint256 _reserve, uint32 _blockTimestampLast) {
        _reserve = reserves[token];
        _blockTimestampLast = blockTimestampLast;
    }

    function getTokens() public view returns (address[] memory _tokens) {
        _tokens = tokens;
    }

    function _update(uint _balance0, uint _balance1, address _token0, address _token1) private {
        uint32 blockTimestamp = uint32(block.timestamp % 2**32);
        reserves[_token0] = uint112(_balance0);
        reserves[_token1] = uint112(_balance1);
        blockTimestampLast = blockTimestamp;
        emit Sync(reserves[_token0], reserves[_token1]);
    }

    function mint(address to, uint256 _amount, address[][] memory paths) external lock returns (uint liquidity) {
        uint256 totAmounts = 0;
        
        IERC20(tokens[0]).transferFrom(msg.sender, address(this), _amount);
        
        for (uint i = 0; i < tokens.length; i++) {
            if (IERC20(tokens[i]).balanceOf(address(this)) != 0) {
                if (tokens[i] != tokens[0]) {
                    uint[] memory amountsOut = IRouterV2(UNISWAP_ROUTER).getAmountsOut(IERC20(tokens[i]).balanceOf(address(this)), paths[i]);
                    totAmounts += amountsOut[1];
                } else {
                    totAmounts = IERC20(tokens[i]).balanceOf(address(this));
                }
            }
        }
        uint256 amount = _amount;
        
        uint _totalSupply = totalSupply;
        if (_totalSupply == 0) {
            
            liquidity = Math.sqrt(amount) - MINIMUM_LIQUIDITY;
           _mint(address(0), MINIMUM_LIQUIDITY);
        } else {
            liquidity = amount.mul(_totalSupply) / (totAmounts - amount);
        }
        require(liquidity > 0, 'Hyro: INSUFFICIENT_LIQUIDITY_MINTED');
        _mint(to, liquidity);
        _update(IERC20(tokens[0]).balanceOf(address(this)), 0, tokens[0], ZERO_ADDRESS);
        emit Mint(msg.sender, liquidity, _amount);
    }

    function burn(address to, uint256 _amount, address[][] memory paths) external lock {
        
        uint256 totAmounts;
        for (uint i; i < tokens.length; i++) {
            if (IERC20(tokens[i]).balanceOf(address(this)) != 0) {
                if (tokens[i] != tokens[0]) {
                    uint[] memory amountsOut = IRouterV2(UNISWAP_ROUTER).getAmountsOut(IERC20(tokens[i]).balanceOf(address(this)), paths[i]);
                    totAmounts += amountsOut[1];
                } else {
                    totAmounts = IERC20(tokens[i]).balanceOf(address(this));
                }
            }
        }
        IERC20(address(this)).transferFrom(msg.sender, address(this), _amount);
        uint liquidity = balanceOf[address(this)];
    
        uint _totalSupply = totalSupply; 
        uint percent = liquidity.mul(1000000000000000000) / _totalSupply;
        uint256 amount = percent.mul(totAmounts) / (1000000000000000000); 
        require(amount > 0, 'Hyro: INSUFFICIENT_LIQUIDITY_BURNED');
        _burn(address(this), liquidity);
        for (uint256 i; i < tokens.length; i++) { 
            if (reserves[tokens[i]] > 0) {
                uint256 withdrawAmount = percent.mul(IERC20(tokens[i]).balanceOf(address(this))) / (1000000000000000000);
                if (tokens[i] != tokens[0]) {
                    if (IERC20(tokens[i]).allowance(UNISWAP_ROUTER, address(this)) < withdrawAmount) {
                        IERC20(tokens[i]).approve(UNISWAP_ROUTER, withdrawAmount);
                    }
                    IRouterV2(UNISWAP_ROUTER).swapExactTokensForTokens(withdrawAmount, 0, paths[i], address(this), block.timestamp + 1000);
                }
                reserves[tokens[i]] = IERC20(tokens[i]).balanceOf(address(this));
            }
        }
        _safeTransfer(tokens[0], to, amount);
        _update(IERC20(tokens[0]).balanceOf(address(this)), 0, tokens[0], ZERO_ADDRESS);
        emit Burn(msg.sender, amount);
    }

    function swap(uint amountIn, uint minAmountOut, address tokenIn, address tokenOut, address[] memory path) external lock {
        updateTokens();
        require (whitelisted(tokenIn) == true && whitelisted(tokenOut) == true, "Hyro: Only use Withlisted Token");
        if (IERC20(tokenIn).allowance(UNISWAP_ROUTER, address(this)) < amountIn)
            approveToken(tokenIn, UNISWAP_ROUTER);
        IRouterV2(UNISWAP_ROUTER).swapExactTokensForTokens(amountIn, minAmountOut , path, address(this), block.timestamp + 10000);
        _update(IERC20(tokenIn).balanceOf(address(this)), IERC20(tokenOut).balanceOf(address(this)), tokenIn, tokenOut);
    }

    function approveToken(address _token, address _dex) private returns (bool) {
        require(whitelisted(_token), "Hyro: Token need to be on the whitelist");
        IERC20(_token).approve(_dex, MAX_UINT);
        return true;
    }

    function skim(address to) external lock {
        updateTokens();
        for(uint256 i; i < tokens.length; i++) {
            _safeTransfer(tokens[i], to, IERC20(tokens[i]).balanceOf(address(this)).sub(reserves[tokens[i]]));
        }
        
    }

    // force reserves to match balances
    function sync() external lock {
        updateTokens();
        for(uint256 i; i < tokens.length; i++) {
            _update(IERC20(tokens[i]).balanceOf(address(this)), 0, tokens[i], ZERO_ADDRESS);
        }
    }
}
