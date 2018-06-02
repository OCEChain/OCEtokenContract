pragma solidity ^0.4.21;

contract Owned {
    
    /// 'owner' is the only address that can call a function with 
    /// this modifier
    address public owner;

    
    ///@notice The constructor assigns the message sender to be 'owner'
    function Owned() public {
        owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(msg.sender == owner);
        _;
    }
    
}

// Safe maths, inherrit from OpenZeppelin
library SafeMath {

    function mul(uint a, uint b) internal pure returns (uint) {
        uint c = a * b;
        assert(a == 0 || c / a == b);
        return c;
    }
    
    function div(uint a, uint b) internal pure returns (uint) {
        // assert(b > 0); // Solidity automatically throws when dividing by 0
        uint c = a / b;
        return c;
    }
    
    function sub(uint a, uint b) internal pure returns (uint) {
        assert(b <= a);
        return a - b;
    }
    
    function add(uint a, uint b) internal pure returns (uint) {
        uint c = a + b;
        assert(c >= a);
        return c;
    }
}

contract ERC20Token {

    /// total amount of tokens
    uint256  totalSupply_;
    
    /// user tokens
    mapping (address => uint256) public balances;
    
    /// @return The total supply
    function totalSupply() constant public returns (uint256 supply);
    
    /// @param _owner The address from which the balance will be retrieved
    /// @return The balance
    function balanceOf(address _owner) constant public returns (uint256 balance);

    /// @notice send `_value` token to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transfer(address _to, uint256 _value) public returns (bool success);
    
    /// @notice send `_value` token to `_to` from `_from` on the condition it is approved by `_from`
    /// @param _from The address of the sender
    /// @param _to The address of the recipient
    /// @param _value The amount of token to be transferred
    /// @return Whether the transfer was successful or not
    function transferFrom(address _from, address _to, uint256 _value) public returns (bool success);

    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return Whether the approval was successful or not
    function approve(address _spender, uint256 _value) public returns (bool success);

    /// @param _owner The address of the account owning tokens
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens allowed to spent
    function allowance(address _owner, address _spender) constant public returns (uint256 remaining);
   
    event Transfer(address indexed _from, address indexed _to, uint256 _value);
    event Approval(address indexed _owner, address indexed _spender, uint256 _value);
}

contract Controlled is Owned {
    using SafeMath for uint;
    uint256 oneMonth = 3600 * 24 * 30;
    
    uint256 releaseStartTime = 1527910441;  //20180602 11:35 default
    
    // Flag that determines if the token is transferable or not
    bool  public emergencyStop = false;
    
    struct userToken {
        uint256 OCE;
        uint256 addrLockType;
    }
    mapping (address => userToken) userReleaseToken;
    
    modifier canTransfer {
        require(emergencyStop == false);
        _;
    }
    
    function canTransferOCE(bool _bool) public onlyOwner{
        emergencyStop = _bool;
    }
    
        /// @dev Owner can change the releaseStartTime when needs
    /// @param _time The releaseStartTime, UTC timezone
    function setRealseTime(uint256 _time) public onlyOwner {
        releaseStartTime = _time;
    }
    
   modifier releaseTokenValid(address _user, uint256 _time, uint256 _value) {
		uint256 _lockTypeIndex = userReleaseToken[_user].addrLockType;
		if(_lockTypeIndex != 0) {			
			require (_value >= userReleaseToken[_user].OCE.sub(calcReleaseToken(_user, _time, _lockTypeIndex)));
      }
		 _;
   }
        
    /// @notice get `_user` transferable token amount 
    /// @param _user The user's address
    /// @param _time The present time
    /// @param _lockTypeIndex The user's investment lock type
    /// @return Return the amount of user's transferable token
    function calcReleaseToken(address _user, uint256 _time, uint256 _lockTypeIndex) internal view returns (uint256) {
        uint256 _timeDifference = _time.sub(releaseStartTime);
        uint256 _whichPeriod = getPeriod(_lockTypeIndex, _timeDifference);
        // lock type 1, 75% lock 3 years
        // lock type 2, 75% lock 3 months
        // lock type 3, 90% lock 6 months
        if(_lockTypeIndex == 1) {
            
            return (percent(userReleaseToken[_user].OCE, 25) + percent(userReleaseToken[_user].OCE, _whichPeriod.mul(25)));
        }
        
        if(_lockTypeIndex == 2) {
            return (percent(userReleaseToken[_user].OCE, 25) + percent(userReleaseToken[_user].OCE, _whichPeriod.mul(25)));
        }
        
        if(_lockTypeIndex == 3) {
            return (percent(userReleaseToken[_user].OCE, 10) + percent(userReleaseToken[_user].OCE, _whichPeriod.mul(15)));
        }
		
		revert();
    
    }
    
    /// @notice get time period for the given '_lockTypeIndex'
    /// @param _lockTypeIndex The user's investment locktype index
    /// @param _timeDifference The passed time since releaseStartTime to now
    /// @return Return the time period
    function getPeriod(uint256 _lockTypeIndex, uint256 _timeDifference) internal view returns (uint256) {
        if(_lockTypeIndex == 1) {           //The lock for the usechain coreTeamSupply
            uint256 _period1 = (_timeDifference.div(oneMonth)).div(12);
            if(_period1 >= 3){
                _period1 = 3;
            }
            return _period1;
        }
        if(_lockTypeIndex == 2) {           //The lock for medium investment
            uint256 _period2 = _timeDifference.div(oneMonth);
            if(_period2 >= 3){
                _period2 = 3;
            }
            return _period2;
        }
        if(_lockTypeIndex == 3) {           //The lock for massive investment
            uint256 _period3 = _timeDifference.div(oneMonth);
            if(_period3 >= 6){
                _period3 = 6;
            }
            return _period3;
        }
		
		revert();
    }
    
    function percent(uint _token, uint _percentage) internal pure returns (uint) {
        return _percentage.mul(_token).div(100);
    }
    
}

contract standardToken is ERC20Token, Controlled {
    
    mapping (address => mapping (address => uint256)) public allowed;
    
    function totalSupply() constant public returns (uint256 ){
        return totalSupply_;
    }
    /// @param _owner The address that's balance is being requested
    /// @return The balance of `_owner` at the current block
    function balanceOf(address _owner) constant public returns (uint256) {
        return balances[_owner];
    }

    /// @notice Send `_value` tokens to `_to` from `msg.sender`
    /// @param _to The address of the recipient
    /// @param _value The amount of tokens to be transferred
    /// @return Whether the transfer was successful or not
    
	function transfer(
        address _to,
        uint256 _value) 
        public 
        canTransfer
        releaseTokenValid(msg.sender, now, balances[msg.sender].sub(_value))
        returns (bool) 
    {
        require (balances[msg.sender] >= _value);           // Throw if sender has insufficient balance
        require(_to != address(0));
        balances[msg.sender] = balances[msg.sender].sub(_value);                     // Deduct senders balance
        balances[_to] = balances[_to].add(_value);                            // Add recivers balance
        emit Transfer(msg.sender, _to, _value);             // Raise Transfer event
        return true;
    }
    
    /// @notice `msg.sender` approves `_spender` to spend `_value` tokens on
    ///  its behalf. This is a modified version of the ERC20 approve function
    ///  to be a little bit safer
    /// @param _spender The address of the account able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return True if the approval was successful
    function approve(address _spender, uint256 _value) public returns (bool success) {
        allowed[msg.sender][_spender] = _value;          // Set allowance
        emit Approval(msg.sender, _spender, _value);             // Raise Approval event
        return true;
    }

 /**
   * @dev Increase the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To increment
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _addedValue The amount of tokens to increase the allowance by.
   */
  function increaseApproval(address _spender, uint _addedValue) public returns (bool) {
    allowed[msg.sender][_spender] = allowed[msg.sender][_spender].add(_addedValue);
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }

  /**
   * @dev Decrease the amount of tokens that an owner allowed to a spender.
   *
   * approve should be called when allowed[_spender] == 0. To decrement
   * allowed value is better to use this function to avoid 2 calls (and wait until
   * the first transaction is mined)
   * From MonolithDAO Token.sol
   * @param _spender The address which will spend the funds.
   * @param _subtractedValue The amount of tokens to decrease the allowance by.
   */
  function decreaseApproval(address _spender, uint _subtractedValue) public returns (bool) {
    uint oldValue = allowed[msg.sender][_spender];
    if (_subtractedValue > oldValue) {
      allowed[msg.sender][_spender] = 0;
    } else {
      allowed[msg.sender][_spender] = oldValue.sub(_subtractedValue);
    }
    emit Approval(msg.sender, _spender, allowed[msg.sender][_spender]);
    return true;
  }
  
    /// @notice `msg.sender` approves `_spender` to send `_value` tokens on
    ///  its behalf, and then a function is triggered in the contract that is
    ///  being approved, `_spender`. This allows users to use their tokens to
    ///  interact with contracts in one function call instead of two
    /// @param _spender The address of the contract able to transfer the tokens
    /// @param _value The amount of tokens to be approved for transfer
    /// @return True if the function call was successful
    function approveAndCall(address _spender, uint256 _value, bytes _extraData) public returns (bool success) {
        approve(_spender, _value);                          // Set approval to contract for _value
        //receiveApproval(address _from, uint256 _value, address _tokenContract, bytes _extraData)
        //it is assumed that when does this that the call *should* succeed, otherwise one would use vanilla approve instead.
        if(!_spender.call(bytes4(bytes32(keccak256("receiveApproval(address,uint256,address,bytes)"))), msg.sender, _value, this, _extraData)) { 
            revert(); 
        }
        return true;
    }

    /// @notice Send `_value` tokens to `_to` from `_from` on the condition it
    ///  is approved by `_from`
    /// @param _from The address holding the tokens being transferred
    /// @param _to The address of the recipient
    /// @param _value The amount of tokens to be transferred
    /// @return True if the transfer was successful
    function transferFrom(address _from, address _to, uint256 _value) 
		    public 
		    canTransfer 
		    releaseTokenValid(msg.sender, now, balances[msg.sender].sub(_value)) 
		    returns (bool success) 
   {
		    require(_to != address(0));
        require (_value <= balances[_from]);                // Throw if sender does not have enough balance
        require (_value <= allowed[_from][msg.sender]);  // Throw if you do not have allowance
        balances[_from] = balances[_from].sub(_value);
        balances[_to] = balances[_to].add(_value);
        allowed[_from][msg.sender] = allowed[_from][msg.sender].sub(_value);        
        emit Transfer(_from, _to, _value);                       // Raise Transfer event
        return true;
    }

    /// @dev This function makes it easy to read the `allowed[]` map
    /// @param _owner The address of the account that owns the token
    /// @param _spender The address of the account able to transfer the tokens
    /// @return Amount of remaining tokens of _owner that _spender is allowed to spend
    function allowance(address _owner, address _spender) constant public returns (uint256) {
        return allowed[_owner][_spender];
    }

}

contract OCE is Owned, standardToken {
        
    string constant public name   = "OCEChainToken";
    string constant public symbol = "OCE";
    uint constant public decimals = 18;

    //uint256 public totalSupply = 0;
    uint256 constant public topTotalSupply = 2 * 10**10 * 10**decimals;
    //uint256 public forSaleTotalSupply        = percent(topTotalSupply, 45);
    //uint256 public marketingPartnerTotalSupply = percent(topTotalSupply, 5);
    //uint256 public coreTeamTotalSupply   = percent(topTotalSupply, 15);
    //uint256 public technicalCommunityTotalSupply       = percent(topTotalSupply, 15);
    //uint256 public communityTotalSupply          = percent(topTotalSupply, 20);
    
    //uint256 public forSaleSupply        = 0;
    //uint256 public marketingPartnerSupply = 0;
    //uint256 public coreTeamSupply   = 0;
    //uint256 public technicalCommunitySupply       = 0;
    //uint256 public communitySupply          = 0;
    
    function () public {
        revert();
    }
    

    /// @dev This owner allocate token for private sale
    /// @param _owners The address of the account that owns the token
    /// @param _values The amount of tokens
    /// @param _addrLockType The locktype for different investment type
    function allocateToken(address[] _owners, uint256[] _values, uint256[] _addrLockType) public onlyOwner {
        require ((_owners.length == _values.length) && ( _values.length == _addrLockType.length));
        require (totalSupply_<=topTotalSupply);
        for(uint i = 0; i < _owners.length ; i++){
            uint256 value = _values[i] * 10 ** decimals;
            
            totalSupply_ = totalSupply_.add(value);
            balances[_owners[i]] = balances[_owners[i]].add(value);             // Set minted coins to target
            emit Transfer(0x0, _owners[i], value);    
            
            userReleaseToken[_owners[i]].OCE = userReleaseToken[_owners[i]].OCE.add(value);
            userReleaseToken[_owners[i]].addrLockType = _addrLockType[i];
        }
    }
    
    /// @dev This owner allocate token for candy airdrop
    /// @param _owners The address of the account that owns the token
    /// @param _values The amount of tokens
	function allocateCandyToken(address[] _owners, uint256[] _values) public onlyOwner {
	   require (totalSupply_<=topTotalSupply);
       for(uint i = 0; i < _owners.length ; i++){
           uint256 value = _values[i] * 10 ** decimals;
           totalSupply_ = totalSupply_.add(value);
		       balances[_owners[i]] = balances[_owners[i]].add(value); 
		       emit Transfer(0x0, _owners[i], value);
       }
    }
}