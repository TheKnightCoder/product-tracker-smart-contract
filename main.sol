pragma solidity ^0.6.0;

contract Ownable {
    address payable _owner;
    
    constructor() public {
        _owner = msg.sender;
    }
    
    modifier onlyOwner() {
        require(isOwner(), "You are not the owner");
        _;
    }
    
    function isOwner() public view returns(bool) {
        return(msg.sender == _owner);
    }
}

contract Item {
    uint public priceInWei;
    uint public pricePaid;
    uint public index;
    ItemManager parentContract;
    
    constructor(ItemManager _parentContract, uint _priceInWei, uint _index) public {
        priceInWei = _priceInWei;
        index = _index;
        parentContract = _parentContract;
    }
    
    receive() external payable {
        require(pricePaid == 0, "Item is paid already");
        require(priceInWei == msg.value, "Only full payments allowed");
        pricePaid += msg.value;
        (bool success, ) = address(parentContract).call.value(msg.value)(abi.encodeWithSignature("triggerPayment(uint256)", index));
        require(success, "The transaction wasn't successful, canceling");
    }
    
    fallback() external {}
}

contract ItemManager is Ownable {
    
    enum SupplyChainState{Created, Paid, Delivered}
    
    struct S_Item {
        Item _item;
        string _name;
        string _address;
        string _hscode;
        uint _itemPrice;
        uint _itemShippingCost;
        uint _totalCost;
        bool _customCleared;
        ItemManager.SupplyChainState _state;
    }
    mapping(uint => S_Item) public items;
    uint itemIndex;
    
    event SupplyChainStep(uint _itemIndex, uint _step, address _itemAddress);
    event CustomCleared(address _itemAddress);
    
    function calcTaxAndCustoms(
        string memory _address,
        string memory _hscode,
        uint _itemPrice, 
        uint _itemShippingCost
    ) private returns(uint) {
        // Get tax and duty fees from some Oracle/API
        return ((_itemPrice + _itemShippingCost) / 100) * 26;
    }
    
    function createItem(
        string memory _name, 
        string memory _address,
        string memory _hscode,
        uint _itemPrice, 
        uint _itemShippingCost
    ) public onlyOwner {
        
        Item item = new Item(
            this, 
            calcTaxAndCustoms(_address, _hscode, _itemPrice, _itemShippingCost), 
            itemIndex
        );
        items[itemIndex]._item = item;
        items[itemIndex]._totalCost = _itemShippingCost + calcTaxAndCustoms(_address, _hscode, _itemPrice, _itemShippingCost);
        items[itemIndex]._name = _name;
        items[itemIndex]._address = _address;
        items[itemIndex]._hscode = _hscode;
        items[itemIndex]._itemPrice = _itemPrice;
        items[itemIndex]._itemShippingCost = _itemShippingCost;
        items[itemIndex]._customCleared = false;
        items[itemIndex]._state = SupplyChainState.Created;
        emit SupplyChainStep(itemIndex, uint(items[itemIndex]._state), address(item));
        itemIndex++;
    }
    
    function triggerCustomCleared(uint _itemIndex) public onlyOwner {
        S_Item storage _sitem = items[_itemIndex];
        _sitem._customCleared = true;
        emit CustomCleared(address(_sitem._item));
    }
    
    function triggerPayment(uint _itemIndex) public payable{
        // require(items[_itemIndex]._totalCost == msg.value, "Only full payments accepted");
        require(items[_itemIndex]._state == SupplyChainState.Created, "Item is further in the chain");
        items[_itemIndex]._state = SupplyChainState.Paid;
        
        emit SupplyChainStep(itemIndex, uint(items[itemIndex]._state), address(items[_itemIndex]._item));
    }
    
    function triggerDelivery(uint _itemIndex) public onlyOwner {
        require(items[_itemIndex]._state == SupplyChainState.Paid, "Item shipping, tax and duty has not been paid for");
        require(items[_itemIndex]._customCleared == true, "Customs has not been cleared");
        items[_itemIndex]._state = SupplyChainState.Delivered;
        
        emit SupplyChainStep(itemIndex, uint(items[itemIndex]._state), address(items[_itemIndex]._item));
    }
}

//"iphone", "some address, US", "HS85171200", 1000, 100
