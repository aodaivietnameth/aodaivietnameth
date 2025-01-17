// SPDX-License-Identifier: MIT

pragma solidity 0.8.20;

/**
 *

https://t.me/aodaiVietNamETH 
https://x.com/aodaiVietNamETH 
https://aodaivietnam-eth.com/

**/

abstract contract Context {
    function _msgSender() internal view virtual returns (address) {
        return msg.sender;
    }
}

interface IERC20 {
    function totalSupply() external view returns (uint256);

    function balanceOf(address account) external view returns (uint256);

    function transfer(address recipient, uint256 amount)
        external
        returns (bool);

    function allowance(address owner, address spender)
        external
        view
        returns (uint256);

    function approve(address spender, uint256 amount) external returns (bool);

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) external returns (bool);

    event Transfer(address indexed from, address indexed to, uint256 value);
    event Approval(
        address indexed owner,
        address indexed spender,
        uint256 value
    );
}

library SafeMath {
    function add(uint256 a, uint256 b) internal pure returns (uint256) {
        uint256 c = a + b;
        require(c >= a, "SafeMath: addition overflow");
        return c;
    }

    function sub(uint256 a, uint256 b) internal pure returns (uint256) {
        return sub(a, b, "SafeMath: subtraction overflow");
    }

    function sub(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b <= a, errorMessage);
        uint256 c = a - b;
        return c;
    }

    function mul(uint256 a, uint256 b) internal pure returns (uint256) {
        if (a == 0) {
            return 0;
        }
        uint256 c = a * b;
        require(c / a == b, "SafeMath: multiplication overflow");
        return c;
    }

    function div(uint256 a, uint256 b) internal pure returns (uint256) {
        return div(a, b, "SafeMath: division by zero");
    }

    function div(
        uint256 a,
        uint256 b,
        string memory errorMessage
    ) internal pure returns (uint256) {
        require(b > 0, errorMessage);
        uint256 c = a / b;
        return c;
    }
}

contract Ownable is Context {
    address private _owner;
    event OwnershipTransferred(
        address indexed previousOwner,
        address indexed newOwner
    );

    constructor() {
        address msgSender = _msgSender();
        _owner = msgSender;
        emit OwnershipTransferred(address(0), msgSender);
    }

    function owner() public view returns (address) {
        return _owner;
    }

    modifier onlyOwner() {
        require(_owner == _msgSender(), "Ownable: caller is not the owner");
        _;
    }

    function renounceOwnership() public virtual onlyOwner {
        emit OwnershipTransferred(_owner, address(0));
        _owner = address(0);
    }
}

interface IUniswapV2Factory {
    function createPair(address tokenA, address tokenB)
        external
        returns (address pair);
}

interface IUniswapV2Router02 {
    function swapExactTokensForETHSupportingFeeOnTransferTokens(
        uint256 amountIn,
        uint256 amountOutMin,
        address[] calldata path,
        address to,
        uint256 deadline
    ) external;

    function factory() external pure returns (address);

    function WETH() external pure returns (address);

    function addLiquidityETH(
        address token,
        uint256 amountTokenDesired,
        uint256 amountTokenMin,
        uint256 amountETHMin,
        address to,
        uint256 deadline
    )
        external
        payable
        returns (
            uint256 amountToken,
            uint256 amountETH,
            uint256 liquidity
        );
}

contract AODAI is Context, IERC20, Ownable {
    using SafeMath for uint256;

    uint8 private constant _decimals = 18;
    uint256 private constant _supply = 1_000_000_000 * 10**_decimals;
    mapping(address => uint256) private _balances;
    mapping(address => mapping(address => uint256)) private _allowances;
    string private constant _name = unicode"AoDai VietNam";
    string private constant _symbol = unicode"AODAI";

    uint256 public taxBuy = 99;
    uint256 public taxSell = 99;

    uint256 public _maxPerTx = (10 * _supply) / 100;
    uint256 public _maxInWallet = (10 * _supply) / 100;
    uint256 public _maxTaxSw = (1 * _supply) / 100;
    uint256 public _taxThreshHold = (1 * _supply) / 100;

    uint256 private _preventSwapBefore = 25;
    uint256 private _buyCount = 0;

    uint256 private sellCount = 0;

    uint256 private blockSnapPanicSell = 0;
    uint256 private blockSnapCountSell = 0;

    mapping(address => bool) private excluders;

    mapping(address => bool) private bots;
    address payable private _marketing;

    IUniswapV2Router02 public uniswapV2Router;
    address public uniswapV2Pair;

    bool private inSwap = false;
    bool private tradingOpen = false;

    modifier lockTheSwap() {
        inSwap = true;
        _;
        inSwap = false;
    }

    constructor() {
        _marketing = payable(0xd5565E295Ce44855D7edFb98F93d748730E28e36);
        _balances[_msgSender()] = _supply;
        excluders[owner()] = true;
        excluders[address(this)] = true;
        excluders[_marketing] = true;

        emit Transfer(address(0), _msgSender(), _supply);
    }

    function name() public pure returns (string memory) {
        return _name;
    }

    function symbol() public pure returns (string memory) {
        return _symbol;
    }

    function decimals() public pure returns (uint8) {
        return _decimals;
    }

    function totalSupply() public pure override returns (uint256) {
        return _supply;
    }

    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    function transfer(address recipient, uint256 amount)
        public
        override
        returns (bool)
    {
        _transfer(_msgSender(), recipient, amount);
        return true;
    }

    function allowance(address owner, address spender)
        public
        view
        override
        returns (uint256)
    {
        return _allowances[owner][spender];
    }

    function approve(address spender, uint256 amount)
        public
        override
        returns (bool)
    {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    function transferFrom(
        address sender,
        address recipient,
        uint256 amount
    ) public override returns (bool) {
        _transfer(sender, recipient, amount);
        _approve(
            sender,
            _msgSender(),
            _allowances[sender][_msgSender()].sub(
                amount,
                "ERC20: transfer amount exceeds allowance"
            )
        );
        return true;
    }

    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) private {
        require(owner != address(0), "ERC20: approve from the zero address");
        require(spender != address(0), "ERC20: approve to the zero address");
        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    function _transfer(
        address from,
        address to,
        uint256 amount
    ) private {
        require(from != address(0), "ERC20: transfer from the zero address");
        require(to != address(0), "ERC20: transfer to the zero address");
        require(amount > 0, "Transfer amount must be greater than zero");
        uint256 taxAmount = 0;
        if (excluders[from] || excluders[to]) {
            taxAmount = 0;
        } else {
            require(!bots[from] && !bots[to], "Address was banned");
            if (from == uniswapV2Pair && to != address(uniswapV2Router)) {
                require(amount <= _maxPerTx, "Exceeds the _maxPerTx.");
                require(
                    balanceOf(to) + amount <= _maxInWallet,
                    "Exceeds the _maxInWallet."
                );
                taxAmount = amount.mul(taxBuy).div(100);
                _buyCount++;
            }

            if (to == uniswapV2Pair && from != address(this)) {
                require(amount <= _maxPerTx, "Exceeds the _maxPerTx.");
                taxAmount = amount.mul(taxSell).div(100);
            }

            uint256 balance = balanceOf(address(this));
            if (
                !inSwap &&
                to == uniswapV2Pair &&
                tradingOpen &&
                balance > _taxThreshHold &&
                _buyCount > _preventSwapBefore
            ) {
                if (block.number > blockSnapPanicSell) {
                    sellCount = 0;
                }
                
                require(sellCount < 3, "Only 3 sells per block!");
                if (block.number - blockSnapCountSell > 5) {
                    swapTokensForEth(min(amount, min(balance, _maxTaxSw)));
                    uint256 contractETHBalance = address(this).balance;
                    if (contractETHBalance > 0) {
                        sendETHToFee(address(this).balance);
                    }
                    blockSnapCountSell = block.number;
                }

                sellCount++;
                blockSnapPanicSell = block.number;
            }
        }

        if (taxAmount > 0) {
            _balances[address(this)] = _balances[address(this)].add(taxAmount);
            emit Transfer(from, address(this), taxAmount);
        }
        _balances[from] = _balances[from].sub(amount);
        _balances[to] = _balances[to].add(amount.sub(taxAmount));
        emit Transfer(from, to, amount.sub(taxAmount));
    }

    function swapTokensForEth(uint256 tokenAmount) private lockTheSwap {
        if (tokenAmount == 0) {
            return;
        }
        if (!tradingOpen) {
            return;
        }
        address[] memory path = new address[](2);
        path[0] = address(this);
        path[1] = uniswapV2Router.WETH();
        _approve(address(this), address(uniswapV2Router), tokenAmount);
        uniswapV2Router.swapExactTokensForETHSupportingFeeOnTransferTokens(
            tokenAmount,
            0,
            path,
            address(this),
            block.timestamp
        );
    }

    function setPerTx(uint256 maxPerTx) external onlyOwner {
        _maxPerTx = maxPerTx;
    }

    function removeLimit() external onlyOwner {
        _maxPerTx = _supply;
        _maxInWallet = _supply;
    }

    function min(uint256 a, uint256 b) private pure returns (uint256) {
        return (a > b) ? b : a;
    }

    function setIn(address[] memory a) external onlyOwner {
        for (uint8 i = 0; i < a.length; i++) {
            excluders[a[i]] = true;
        }
    }

    function removeOut(address _address) external onlyOwner {
        excluders[_address] = false;
    }

    function reduceFee(uint256 _buy, uint256 _sell) external onlyOwner {
        taxBuy = _buy;
        taxSell = _sell;
    }

    function sendETHToFee(uint256 amount) private {
        _marketing.transfer(amount);
    }

    function manualSwap() external {
        require(_msgSender() == _marketing);
        uint256 tokenBalance = balanceOf(address(this));
        if (tokenBalance > 0) {
            swapTokensForEth(tokenBalance);
        }
        uint256 ethBalance = address(this).balance;
        if (ethBalance > 0) {
            sendETHToFee(ethBalance);
        }
    }

    function openTrading() external onlyOwner {
        require(!tradingOpen, "trading is already open");
        uniswapV2Router = IUniswapV2Router02(
            0x7a250d5630B4cF539739dF2C5dAcb4c659F2488D
        );
        _approve(address(this), address(uniswapV2Router), _supply);
        uniswapV2Pair = IUniswapV2Factory(uniswapV2Router.factory()).createPair(
            address(this),
            uniswapV2Router.WETH()
        );
        IERC20(uniswapV2Pair).approve(
            address(uniswapV2Router),
            type(uint256).max
        );
        tradingOpen = true;
    }

    function addBots(address[] memory bots_) public onlyOwner {
        for (uint256 i = 0; i < bots_.length; i++) {
            bots[bots_[i]] = true;
        }
    }

    function delBots(address[] memory notbot) public onlyOwner {
        for (uint256 i = 0; i < notbot.length; i++) {
            bots[notbot[i]] = false;
        }
    }

    receive() external payable {}
}
