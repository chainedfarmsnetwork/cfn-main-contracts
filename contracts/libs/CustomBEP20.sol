// SPDX-License-Identifier: MIT

pragma solidity >=0.4.0;

import "@openzeppelin/contracts/access/Ownable.sol";
import "@openzeppelin/contracts/GSN/Context.sol";
import "./IBEP20.sol";
import "@openzeppelin/contracts/math/SafeMath.sol";

/**
 * @dev Implementation of the {IBEP20} interface.
 *
 * This implementation is agnostic to the way tokens are created. This means
 * that a supply mechanism has to be added in a derived contract using {_mint}.
 * For a generic mechanism see {BEP20PresetMinterPauser}.
 *
 * TIP: For a detailed writeup see our guide
 * https://forum.zeppelin.solutions/t/how-to-implement-BEP20-supply-mechanisms/226[How
 * to implement supply mechanisms].
 *
 * We have followed general OpenZeppelin guidelines: functions revert instead
 * of returning `false` on failure. This behavior is nonetheless conventional
 * and does not conflict with the expectations of BEP20 applications.
 *
 * Additionally, an {Approval} event is emitted on calls to {transferFrom}.
 * This allows applications to reconstruct the allowance for all accounts just
 * by listening to said events. Other implementations of the EIP may not emit
 * these events, as it isn't required by the specification.
 *
 * Finally, the non-standard {decreaseAllowance} and {increaseAllowance}
 * functions have been added to mitigate the well-known issues around setting
 * allowances. See {IBEP20-approve}.
 */
contract CustomBEP20 is Context, IBEP20, Ownable {
    using SafeMath for uint256;

    mapping(address => uint256) private _balances;

    mapping(address => mapping(address => uint256)) private _allowances;

    uint256 private _totalSupply;

    string private _name;
    string private _symbol;
    uint8 private _decimals;

    uint256 private _maxSupply;
    uint256 private _minSupplyNoBurn;
    uint256 private _maxBurnPercent = 500; // 5% max burn
    uint256 private _currentBurnPercent = _maxBurnPercent / 2; // Start with 2.5% of burn

    address private _deadAddress1 = 0x000000000000000000000000000000000000dEaD;
    address private _deadAddress2 = 0x0000000000000000000000000000000000000000;

    /**
     * @dev Sets the values for {name} and {symbol}, initializes {decimals} with
     * a default value of 18.
     *
     * To select a different value for {decimals}, use {_setupDecimals}.
     *
     * All three of these values are immutable: they can only be set once during
     * construction.
     */
    constructor(
        string memory name,
        string memory symbol,
        uint256 maxSupply
    ) public {
        _name = name;
        _symbol = symbol;
        _maxSupply = maxSupply;
        _minSupplyNoBurn = _maxSupply.div(10); // Under 10% of supply, no more burn
        _decimals = 18;
    }

    function ceil(uint256 a, uint256 m) private pure returns (uint256 r) {
        return ((a + m - 1) / m) * m;
    }

    /**
     * @dev
     * - Base burn code inspired from https://etherscan.io/address/0x1C95b093d6C236d3EF7c796fE33f9CC6b8606714#code
     * - Dynamic burn depending on current supply
     */
    function _updateBurnPercent() private returns (uint256) {
        _currentBurnPercent = _maxBurnPercent.mul(_totalSupply).div(_maxSupply);

        // Cap burn percent to max burn percent possible
        if (_currentBurnPercent > _maxBurnPercent || _totalSupply >= _maxSupply) {
            _currentBurnPercent = _maxBurnPercent;
        }
        // Don't burn if our current supply is below a determined value
        if (_totalSupply <= _minSupplyNoBurn) {
            _currentBurnPercent = 0;
        }
    }

    // Custom transfert, including burn
    function transfer(address to, uint256 value) public override returns (bool) {
        require(value <= _balances[msg.sender]);

        uint256 roundValue = ceil(value, 100);
        uint256 burnPercent = roundValue.mul(_currentBurnPercent).div(10000);
        uint256 tokensToTransfer = value.sub(burnPercent);

        _balances[msg.sender] = _balances[msg.sender].sub(value);
        _balances[to] = _balances[to].add(tokensToTransfer);

        _totalSupply = _totalSupply.sub(burnPercent);

        // If address is 0, token is burned, substract it from total
        if (to == address(_deadAddress1) || to == address(_deadAddress2)) {
            _totalSupply = _totalSupply.sub(tokensToTransfer);
            emit Transfer(msg.sender, address(_deadAddress1), tokensToTransfer);
        } else {
            emit Transfer(msg.sender, to, tokensToTransfer);
        }

        _balances[address(_deadAddress1)] = _balances[address(_deadAddress1)].add(burnPercent);
        emit Transfer(msg.sender, address(_deadAddress1), burnPercent);

        // Once transaction is done, update burn percentage
        _updateBurnPercent();

        return true;
    }

    function transferFrom(
        address from,
        address to,
        uint256 value
    ) public override returns (bool) {
        require(value <= _balances[from]);
        require(value <= _allowances[from][msg.sender]);

        _balances[from] = _balances[from].sub(value);

        uint256 roundValue = ceil(value, 100);
        uint256 burnPercent = roundValue.mul(_currentBurnPercent).div(10000);
        uint256 tokensToTransfer = value.sub(burnPercent);

        _balances[to] = _balances[to].add(tokensToTransfer);
        _totalSupply = _totalSupply.sub(burnPercent);

        _allowances[from][msg.sender] = _allowances[from][msg.sender].sub(value);

        if (to == address(_deadAddress1) || to == address(_deadAddress2)) {
            _totalSupply = _totalSupply.sub(tokensToTransfer);
            emit Transfer(msg.sender, address(_deadAddress1), tokensToTransfer);
        } else {
            emit Transfer(msg.sender, to, tokensToTransfer);
        }

        _balances[address(_deadAddress1)] = _balances[address(_deadAddress1)].add(burnPercent);
        emit Transfer(from, address(_deadAddress1), burnPercent);

        // Once transaction is done, update burn percentage
        _updateBurnPercent();

        return true;
    }

    /**
     * @dev Returns the current burned percent per transfert.
     */
    function getCurrentBurnPercent() external view returns (uint256) {
        return _currentBurnPercent;
    }

    /**
     * @dev Returns the max supply.
     */
    function getMaximumSupply() external view returns (uint256) {
        return _maxSupply;
    }

    /**
     * @dev Returns the min supply to stop burn.
     */
    function getMinimumSupplyToStopBurn() external view returns (uint256) {
        return _minSupplyNoBurn;
    }

    /**
     * @dev Returns the max burned percent.
     */
    function getMaximumBurnPercent() external view returns (uint256) {
        return _maxBurnPercent;
    }

    /**
     * @dev Returns the bep token owner.
     */
    function getOwner() external view override returns (address) {
        return owner();
    }

    /**
     * @dev Returns the name of the token.
     */
    function name() public view override returns (string memory) {
        return _name;
    }

    /**
     * @dev Returns the symbol of the token, usually a shorter version of the
     * name.
     */
    function symbol() public view override returns (string memory) {
        return _symbol;
    }

    /**
     * @dev Returns the number of decimals used to get its user representation.
     */
    function decimals() public view override returns (uint8) {
        return _decimals;
    }

    /**
     * @dev See {BEP20-totalSupply}.
     */
    function totalSupply() public view override returns (uint256) {
        return _totalSupply;
    }

    /**
     * @dev See {BEP20-balanceOf}.
     */
    function balanceOf(address account) public view override returns (uint256) {
        return _balances[account];
    }

    // /**
    //  * @dev See {BEP20-transfer}.
    //  *
    //  * Requirements:
    //  *
    //  * - `recipient` cannot be the zero address.
    //  * - the caller must have a balance of at least `amount`.
    //  */
    // function transfer(address recipient, uint256 amount)
    //     public
    //     virtual
    //     override
    //     returns (bool)
    // {
    //     _transfer(_msgSender(), recipient, amount);
    //     return true;
    // }

    /**
     * @dev See {BEP20-allowance}.
     */
    function allowance(address owner, address spender) public view override returns (uint256) {
        return _allowances[owner][spender];
    }

    /**
     * @dev See {BEP20-approve}.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function approve(address spender, uint256 amount) public override returns (bool) {
        _approve(_msgSender(), spender, amount);
        return true;
    }

    // /**
    //  * @dev See {BEP20-transferFrom}.
    //  *
    //  * Emits an {Approval} event indicating the updated allowance. This is not
    //  * required by the EIP. See the note at the beginning of {BEP20};
    //  *
    //  * Requirements:
    //  * - `sender` and `recipient` cannot be the zero address.
    //  * - `sender` must have a balance of at least `amount`.
    //  * - the caller must have allowance for `sender`'s tokens of at least
    //  * `amount`.
    //  */
    // function transferFrom(
    //     address sender,
    //     address recipient,
    //     uint256 amount
    // ) public virtual override returns (bool) {
    //     _transfer(sender, recipient, amount);
    //     _approve(
    //         sender,
    //         _msgSender(),
    //         _allowances[sender][_msgSender()].sub(
    //             amount,
    //             "BEP20: transfer amount exceeds allowance"
    //         )
    //     );
    //     return true;
    // }

    /**
     * @dev Atomically increases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     */
    function increaseAllowance(address spender, uint256 addedValue) public returns (bool) {
        _approve(_msgSender(), spender, _allowances[_msgSender()][spender].add(addedValue));
        return true;
    }

    /**
     * @dev Atomically decreases the allowance granted to `spender` by the caller.
     *
     * This is an alternative to {approve} that can be used as a mitigation for
     * problems described in {BEP20-approve}.
     *
     * Emits an {Approval} event indicating the updated allowance.
     *
     * Requirements:
     *
     * - `spender` cannot be the zero address.
     * - `spender` must have allowance for the caller of at least
     * `subtractedValue`.
     */
    function decreaseAllowance(address spender, uint256 subtractedValue) public returns (bool) {
        _approve(
            _msgSender(),
            spender,
            _allowances[_msgSender()][spender].sub(subtractedValue, "BEP20: decreased allowance below zero")
        );
        return true;
    }

    /**
     * @dev Creates `amount` tokens and assigns them to `msg.sender`, increasing
     * the total supply.
     *
     * Requirements
     *
     * - `msg.sender` must be the token owner
     */
    function mint(uint256 amount) public onlyOwner returns (bool) {
        _mint(_msgSender(), amount);
        return true;
    }

    /**
     * @dev Moves tokens `amount` from `sender` to `recipient`.
     *
     * This is internal function is equivalent to {transfer}, and can be used to
     * e.g. implement automatic token fees, slashing mechanisms, etc.
     *
     * Emits a {Transfer} event.
     *
     * Requirements:
     *
     * - `sender` cannot be the zero address.
     * - `recipient` cannot be the zero address.
     * - `sender` must have a balance of at least `amount`.
     */
    function _transfer(
        address sender,
        address recipient,
        uint256 amount
    ) internal {
        require(sender != address(0), "BEP20: transfer from the zero address");

        _balances[sender] = _balances[sender].sub(amount, "BEP20: transfer amount exceeds balance");
        _balances[recipient] = _balances[recipient].add(amount);

        if (recipient == address(_deadAddress1)) {
            emit Transfer(sender, address(_deadAddress1), amount);
        } else {
            emit Transfer(sender, recipient, amount);
        }
    }

    /** @dev Creates `amount` tokens and assigns them to `account`, increasing
     * the total supply.
     *
     * Emits a {Transfer} event with `from` set to the zero address.
     *
     * Requirements
     *
     * - `to` cannot be the zero address.
     */
    function _mint(address account, uint256 amount) internal {
        // require(account != address(0), "BEP20: mint to the zero address");

        _totalSupply = _totalSupply.add(amount);
        _balances[account] = _balances[account].add(amount);
        emit Transfer(address(0), account, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`, reducing the
     * total supply.
     *
     * Emits a {Transfer} event with `to` set to the zero address.
     *
     * Requirements
     *
     * - `account` cannot be the zero address.
     * - `account` must have at least `amount` tokens.
     */
    function _burn(address account, uint256 amount) internal {
        require(account != address(0), "BEP20: burn from the zero address");

        _balances[account] = _balances[account].sub(amount, "BEP20: burn amount exceeds balance");

        _totalSupply = _totalSupply.sub(amount);

        _balances[address(_deadAddress1)] = _balances[address(_deadAddress1)].add(amount);
        emit Transfer(account, address(_deadAddress1), amount);
    }

    /**
     * @dev Sets `amount` as the allowance of `spender` over the `owner`s tokens.
     *
     * This is internal function is equivalent to `approve`, and can be used to
     * e.g. set automatic allowances for certain subsystems, etc.
     *
     * Emits an {Approval} event.
     *
     * Requirements:
     *
     * - `owner` cannot be the zero address.
     * - `spender` cannot be the zero address.
     */
    function _approve(
        address owner,
        address spender,
        uint256 amount
    ) internal {
        require(owner != address(0), "BEP20: approve from the zero address");
        require(spender != address(0), "BEP20: approve to the zero address");

        _allowances[owner][spender] = amount;
        emit Approval(owner, spender, amount);
    }

    /**
     * @dev Destroys `amount` tokens from `account`.`amount` is then deducted
     * from the caller's allowance.
     *
     * See {_burn} and {_approve}.
     */
    function _burnFrom(address account, uint256 amount) internal {
        _burn(account, amount);
        _approve(
            account,
            _msgSender(),
            _allowances[account][_msgSender()].sub(amount, "BEP20: burn amount exceeds allowance")
        );
    }
}
