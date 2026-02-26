// SPDX-License-Identifier: MIT
pragma solidity ^0.8.24;

/**
 *  ░▒▓███████▓▒░▒▓███████▓▒░ ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓█▓▒░      ░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 *  ░▒▓██████▓▒░░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 *        ░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░▒▓█▓▒░░▒▓█▓▒░░▒▓█▓▒░
 * ░▒▓███████▓▒░░▒▓█▓▒░░▒▓█▓▒░░▒▓██████▓▒░ ░▒▓█████████████▓▒░
 */
import {ERC20} from "@openzeppelin/contracts/token/ERC20/ERC20.sol";
import {IERC20} from "@openzeppelin/contracts/token/ERC20/IERC20.sol";
import {SafeERC20} from "@openzeppelin/contracts/token/ERC20/utils/SafeERC20.sol";
import {Ownable} from "@openzeppelin/contracts/access/Ownable.sol";

// note 021: Ownable inherited but no onlyOwner functions
contract Snow is ERC20, Ownable {
    using SafeERC20 for IERC20;

    // >>> ERROR
    error S__NotAllowed();
    error S__ZeroAddress();
    error S__ZeroValue();
    error S__Timer();
    error S__SnowFarmingOver();

    // >>> VARIABLES
    address private s_collector;
    uint256 private s_earnTimer;
    uint256 public s_buyFee;
    uint256 private immutable i_farmingOver;

    IERC20 i_weth;

    uint256 constant PRECISION = 10 ** 18;
    uint256 constant FARMING_DURATION = 12 weeks;

    // >>> EVENTS
    event SnowBought(address indexed buyer, uint256 indexed amount);
    // note 019: SnowEarned and FeeCollected never emitted
    event SnowEarned(address indexed earner, uint256 indexed amount);
    event FeeCollected();
    event NewCollector(address indexed newCollector);

    // >>> MODIFIERS
    modifier onlyCollector() {
        if (msg.sender != s_collector) {
            revert S__NotAllowed();
        }
        _;
    }

    modifier canFarmSnow() {
        if (block.timestamp >= i_farmingOver) {
            revert S__SnowFarmingOver();
        }
        _;
    }

    // >>> CONSTRUCTOR
    constructor(address _weth, uint256 _buyFee, address _collector) ERC20("Snow", "S") Ownable(msg.sender) {
        if (_weth == address(0)) {
            revert S__ZeroAddress();
        }
        if (_buyFee == 0) {
            revert S__ZeroValue();
        }
        if (_collector == address(0)) {
            revert S__ZeroAddress();
        }

        i_weth = IERC20(_weth);
        s_buyFee = _buyFee * PRECISION; //todo _buy fee in deploy script is 5, so it would be 5e18
        s_collector = _collector;
        i_farmingOver = block.timestamp + FARMING_DURATION; // Snow farming eands 12 weeks after deployment
    }

    // >>> EXTERNAL FUNCTIONS
    // note why are we using canFarmSnow here (its just buying here)
    // hack 014: canFarmSnow should not apply to buySnow; users should be allowed to buy anytime
    function buySnow(uint256 amount) external payable canFarmSnow {
        // note 020: amount can be 0, no-op
        //bug probably some error here, fees are calculated in a weird way, it acts as a multiplier
        if (msg.value == (s_buyFee * amount)) {
            _mint(msg.sender, amount);
        } else {
            // note 018: require msg.value == 0 when using WETH path
            i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
            _mint(msg.sender, amount);
        }

        //note what is s_earnTimer doing??
        s_earnTimer = block.timestamp;

        emit SnowBought(msg.sender, amount);
    }

    // can this be subject to flash loans attack? not really because this would mint jjust 1 token 
    function earnSnow() external canFarmSnow {
        // note why are we using this check??
        // note in what cases the user can earn snow?
        // The `Snow` token can either be earned for free onece a week, 
        // or bought at anytime, up until during the `::FARMING_DURATION` is over.
        // there should be a mapping user -> lastTimeEarned and check it, this way it doesnt work
        // and we should remove `  s_earnTimer = block.timestamp;` at line 91
        // bug intended “each user can earn once per week” behavior is broken.
        // The fix would be per-user tracking (e.g. a mapping from user to last earn time) instead of a single global timer.
        if (s_earnTimer != 0 && block.timestamp < (s_earnTimer + 1 weeks)) {
            revert S__Timer();
        }

        // note: no reentrancy risk; _mint has no external calls
        _mint(msg.sender, 1);
        // note 019: SnowEarned not emitted
        s_earnTimer = block.timestamp;
    }

    function collectFee() external onlyCollector {
        // note 016: check if there are funds to collect first
        uint256 collection = i_weth.balanceOf(address(this));
        // note 016: use safeTransfer
        i_weth.transfer(s_collector, collection);

        // note 016: check if there are funds to collect first
        (bool collected,) = payable(s_collector).call{value: address(this).balance}("");
        require(collected, "Fee collection failed!!!");
        // note 019: FeeCollected not emitted
    }

    // note 017: use 2-step transfer or AccessControl for privilege transfer
    function changeCollector(address _newCollector) external onlyCollector {
        if (_newCollector == address(0)) {
            revert S__ZeroAddress();
        }

        s_collector = _newCollector;

        emit NewCollector(_newCollector);
    }

    // >>> GETTER FUNCTIONS
    function getCollector() external view returns (address) {
        return s_collector;
    }
}
