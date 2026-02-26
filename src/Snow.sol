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
    // note snowEarned and FeeCollected are never used, missing events in earnSnow() and collectFee()
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
    function buySnow(uint256 amount) external payable canFarmSnow {
        //bug probably some error here, fees are calculated in a weird way, it acts as a multiplier
        if (msg.value == (s_buyFee * amount)) {
            _mint(msg.sender, amount);
        } else {
            i_weth.safeTransferFrom(msg.sender, address(this), (s_buyFee * amount));
            _mint(msg.sender, amount);
        }

        //note what is s_earnTimer doing??
        s_earnTimer = block.timestamp;

        emit SnowBought(msg.sender, amount);
    }

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

        // bug possible reentrancy
        _mint(msg.sender, 1);

        s_earnTimer = block.timestamp;
    }

    function collectFee() external onlyCollector {
        // note check if there are funds to collect first
        uint256 collection = i_weth.balanceOf(address(this));
        // note use safetransfer
        i_weth.transfer(s_collector, collection);

        // note check if there are funds to collect first
        (bool collected,) = payable(s_collector).call{value: address(this).balance}("");
        require(collected, "Fee collection failed!!!");
    }

    //note it's better to use a 2 step approach here where the new collector has to accept the role, suggest using a Role based extension
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
